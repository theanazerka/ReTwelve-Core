#import "TGClient.h"
#import "TGTextParser.h"
#import "TGTL.h"
#import "TGSRP.h"
#import "TGAccountsController.h"
#import "TGAccountStorage.h"
#import "TGDeviceKeychain.h"
#import "TGCallCrypto.h"
#import "LocalConfig.h"
#import <MtProtoKit/MtProtoKit.h>
#import <OpenSSLEncryptionProvider/OpenSSLEncryptionProvider.h>
#import <Security/Security.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#if __LP64__
#import "TGModernTcpConnection.h"
#endif

NSString *const TGClientNetworkNotification = @"TGClientNetworkNotification";
NSString *const TGClientPhoneCallNotification = @"TGClientPhoneCallNotification";
NSString *const TGClientCallSignalingNotification = @"TGClientCallSignalingNotification";
NSString *const TGClientPeerUpdateNotification = @"TGClientPeerUpdateNotification";
#if __LP64__
static __weak TGClient *TGAuthTraceClient;
static NSString *TGAuthTraceStage;
static void TGAuthTraceLog(NSString *line) {
    NSString *stage = nil;
    if ([line rangeOfString:@"auth stage: tcpConnected"].location != NSNotFound) stage = @"TCP открыт";
    else if ([line rangeOfString:@"auth stage: reqPQ"].location != NSNotFound) stage = @"запрос ключа подготовлен";
    else if ([line rangeOfString:@"auth stage: tcpWrite"].location != NSNotFound) stage = @"первый пакет передан в TCP";
    else if ([line rangeOfString:@"auth stage: resPQ"].location != NSNotFound) stage = @"сервер ответил на reqPQ";
    else if ([line rangeOfString:@"auth stage: reqDH"].location != NSNotFound) stage = @"отправлен reqDH";
    else if ([line rangeOfString:@"auth stage: serverDH"].location != NSNotFound) stage = @"получены параметры DH";
    else if ([line rangeOfString:@"auth stage: clientDH"].location != NSNotFound) stage = @"отправлен clientDH";
    else if ([line rangeOfString:@"auth stage: done"].location != NSNotFound) stage = @"ключ подтверждён";
    else if ([line rangeOfString:@"MTNetworkAvailability"].location != NSNotFound &&
             [line hasSuffix:@"-]"]) stage = @"MTProto считает сеть недоступной";
    else if ([line rangeOfString:@" connecting to "].location != NSNotFound) stage = @"TCP подключается";
    else if ([line rangeOfString:@" response timeout"].location != NSNotFound) stage = @"TCP: сервер не ответил";
    else if ([line rangeOfString:@" disconnected from "].location != NSNotFound) stage = @"TCP соединение разорвано";
    else if ([line rangeOfString:@"couldn't find valid server public key"].location != NSNotFound)
        stage = @"серверный RSA ключ не распознан";
    else if ([line rangeOfString:@"Factorization failed"].location != NSNotFound)
        stage = @"не удалось разложить pq";
    else if ([line rangeOfString:@"invalid DH"].location != NSNotFound ||
             [line rangeOfString:@"couldn't decode DH"].location != NSNotFound)
        stage = @"ошибка проверки DH";
    if (!stage) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        TGClient *client = TGAuthTraceClient;
        if (!client || [TGAuthTraceStage isEqualToString:stage]) return;
        TGAuthTraceStage = stage;
        TGClientStatus status = client.status;
        if (status && !client.isReady) status([@"MTProto: " stringByAppendingString:stage]);
    });
}
#endif
static dispatch_queue_t TGMediaCacheQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("telegram.media-cache", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
static BOOL TGMediaDataIsDecodable(NSData *data) {
    if (!data.length) return NO;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return NO;
    NSDictionary *options = @{ (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                               (id)kCGImageSourceThumbnailMaxPixelSize: @64 };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    BOOL valid = image != NULL;
    if (image) CGImageRelease(image);
    CFRelease(source);
    return valid;
}
static NSData *TGInflateStrippedThumbnail(NSData *stripped) {
    if (stripped.length < 4 || ((const uint8_t *)stripped.bytes)[0] != 1) return nil;
    NSData *template = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TinyJpegHeader" ofType:@"bin"]];
    if (template.length < 167) return nil;
    NSMutableData *jpeg = [template mutableCopy];
    uint8_t *header = jpeg.mutableBytes;
    const uint8_t *bytes = stripped.bytes;
    header[164] = bytes[1]; header[166] = bytes[2];
    [jpeg appendBytes:bytes + 3 length:stripped.length - 3];
    uint8_t footer[2] = {0xff, 0xd9};
    [jpeg appendBytes:footer length:2];
    return jpeg;
}

@interface TGSerialization : NSObject <MTSerialization>
@property (nonatomic, strong) TGTL *tl;
@end
@implementation TGSerialization
- (NSUInteger)currentLayer { return 229; }
- (id)parseMessage:(NSData *)data { return [self.tl decode:data]; }
- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)dc data:(NSData **)data {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xe5bfffcd];
    [stream writeInt32:dc];
    *data = [stream currentBytes];
    TGTL *tl = self.tl;
    return ^MTExportedAuthorizationData *(NSData *response) {
        NSDictionary *result = [tl decode:response];
        if (![result[@"_"] isEqual:@"auth.exportedAuthorization"] || ![result[@"bytes"] isKindOfClass:[NSData class]]) return nil;
        return [[MTExportedAuthorizationData alloc] initWithAuthorizationBytes:result[@"bytes"]
                                                                authorizationId:[result[@"id"] longLongValue]];
    };
}
- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xa57a7dad];
    [stream writeInt64:authId];
    [stream writeBytes:bytes];
    return [stream currentBytes];
}
- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(NSData **)data { return nil; }
- (MTRequestNoopParser)requestNoop:(NSData **)data {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x1fb33026];
    *data = [stream currentBytes];
    return ^id(NSData *response) { return response; };
}
@end

@interface TGPhoneUpdateService : NSObject <MTMessageService>
@property (nonatomic, weak) TGClient *client;
@end

static void TGCollectPhoneUpdates(id value, NSMutableArray *calls, NSMutableArray *signals,
    NSMutableArray *peers, NSUInteger depth) {
    if (depth > 4 || !value) return;
    if ([value isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)value) TGCollectPhoneUpdates(item, calls, signals, peers, depth + 1);
        return;
    }
    if (![value isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *update = value;
    NSString *name = update[@"_"];
    if ([name isEqual:@"updatePhoneCall"] && [update[@"phone_call"] isKindOfClass:[NSDictionary class]]) {
        [calls addObject:update[@"phone_call"]]; return;
    }
    if ([name isEqual:@"updatePhoneCallSignalingData"] && update[@"phone_call_id"] &&
        [update[@"data"] isKindOfClass:[NSData class]]) {
        [signals addObject:update]; return;
    }
    if ([name isEqual:@"updateUserStatus"] || [name isEqual:@"updateUserTyping"] ||
        [name isEqual:@"updateChatUserTyping"] || [name isEqual:@"updateChannelUserTyping"])
        [peers addObject:update];
    TGCollectPhoneUpdates(update[@"update"], calls, signals, peers, depth + 1); // updateShort
    TGCollectPhoneUpdates(update[@"updates"], calls, signals, peers, depth + 1); // updates/updatesCombined
    TGCollectPhoneUpdates(update[@"other_updates"], calls, signals, peers, depth + 1);
}
@implementation TGPhoneUpdateService
- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message
    authInfoSelector:(MTDatacenterAuthInfoSelector)selector networkType:(int32_t)networkType {
    id body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]) return;
    NSMutableArray *calls = [NSMutableArray array];
    NSMutableArray *signals = [NSMutableArray array];
    NSMutableArray *peers = [NSMutableArray array];
    TGCollectPhoneUpdates(body, calls, signals, peers, 0);
    if (!calls.count && !signals.count && !peers.count) return;
    __weak TGClient *client = self.client;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!client) return;
        for (NSDictionary *call in calls)
            [[NSNotificationCenter defaultCenter] postNotificationName:TGClientPhoneCallNotification object:client
                userInfo:@{ @"call": call }];
        for (NSDictionary *signal in signals)
            [[NSNotificationCenter defaultCenter] postNotificationName:TGClientCallSignalingNotification object:client
                userInfo:@{ @"phone_call_id": signal[@"phone_call_id"], @"data": signal[@"data"] }];
        for (NSDictionary *update in peers)
            [[NSNotificationCenter defaultCenter] postNotificationName:TGClientPeerUpdateNotification object:client
                userInfo:@{ @"update": update }];
    });
}
@end

@interface TGClient () {
    MTContext *_context;
    MTDatacenterAuthAction *_authAction;
    MTProto *_mtProto;
    MTRequestMessageService *_service;
    TGPhoneUpdateService *_phoneUpdates;
    NSMutableDictionary *_mediaProtos;
    NSMutableDictionary *_mediaServices;
    NSMutableSet *_requests;
    NSMutableDictionary *_avatarWaiters;
    NSMutableDictionary *_roundVideoWaiters;
    NSMutableDictionary *_musicWaiters;
    NSMutableDictionary *_savedMusicSnapshots;
    NSDictionary *_imageSearchBot;
    NSString *_accountIdentifier;
    NSCache *_stickerKeyboardPreviewCache;
    TGTL *_tl;
    NSString *_phone;
    NSString *_phoneCodeHash;
    NSInteger _dc;
    NSUInteger _generation;
    BOOL _connectionTrouble;
}
- (void)getHistoryForPeer:(NSDictionary *)inputPeer limit:(int32_t)limit completion:(TGClientCompletion)completion;
- (void)getHistoryForPeer:(NSDictionary *)inputPeer beforeMessageId:(int32_t)messageId limit:(int32_t)limit cacheResult:(BOOL)cacheResult completion:(TGClientCompletion)completion;
- (void)downloadAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo photoId:(NSNumber *)photoId;
- (void)downloadAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo photoId:(NSNumber *)photoId big:(BOOL)big;
- (void)downloadMessagePhoto:(NSDictionary *)photo size:(NSDictionary *)size completion:(TGAvatarCompletion)completion;
- (void)downloadVoiceDocument:(NSDictionary *)document offset:(int64_t)offset data:(NSMutableData *)data completion:(TGAvatarCompletion)completion;
- (void)downloadMusicDocument:(NSDictionary *)document offset:(int64_t)offset partialPath:(NSString *)partialPath
    finalPath:(NSString *)finalPath completion:(TGDocumentPathCompletion)completion;
- (void)uploadProfileMusicData:(NSData *)data fileName:(NSString *)fileName fileId:(int64_t)fileId
    part:(int32_t)part count:(int32_t)count duration:(int32_t)duration completion:(TGClientCompletion)completion;
- (void)downloadStickerDocument:(NSDictionary *)document thumbSize:(NSString *)thumbSize offset:(int64_t)offset
                            data:(NSMutableData *)data completion:(TGAvatarCompletion)completion;
- (void)uploadVoiceData:(NSData *)data fileId:(int64_t)fileId part:(int32_t)part count:(int32_t)count
                 duration:(int32_t)duration waveform:(NSData *)waveform peer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
@end

@implementation TGClient
- (void)getMessages:(NSArray *)ids forPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    if (!ids.count || ids.count > 100) { completion(nil, @"Неверный список сообщений."); return; }
    BOOL channel = [peer[@"_"] isEqual:@"inputPeerChannel"];
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)(channel ? 0xad8c9a23 : 0x63c66506)];
    if (channel) {
        [stream writeInt32:(int32_t)0xf35aec28];
        [stream writeInt64:[peer[@"channel_id"] longLongValue]];
        [stream writeInt64:[peer[@"access_hash"] longLongValue]];
    }
    [stream writeInt32:(int32_t)0x1cb5c415]; [stream writeInt32:(int32_t)ids.count];
    for (NSNumber *identifier in ids) { [stream writeInt32:(int32_t)0xa676a322]; [stream writeInt32:identifier.intValue]; }
    [self rpc:[stream currentBytes] name:channel ? @"channels.getMessages" : @"messages.getMessages" completion:completion];
}

- (instancetype)init {
    return [self initWithAccountIdentifier:TGActiveAccountIdentifier()];
}
- (instancetype)initWithAccountIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _accountIdentifier = [identifier copy] ?: @"";
        _savedMusicSnapshots = [[NSMutableDictionary alloc] init];
#if __LP64__
        TGAuthTraceClient = self;
        MTLogSetLoggingFunction(TGAuthTraceLog);
#endif
        _requests = [NSMutableSet set];
        _avatarWaiters = [NSMutableDictionary dictionary];
        _roundVideoWaiters = [NSMutableDictionary dictionary];
        _musicWaiters = [NSMutableDictionary dictionary];
        _mediaProtos = [NSMutableDictionary dictionary];
        _mediaServices = [NSMutableDictionary dictionary];
        _tl = [[TGTL alloc] initWithSchemaPath:[[NSBundle mainBundle] pathForResource:@"api229" ofType:@"tl"]];
        MTApiEnvironment *environment = [[MTApiEnvironment alloc] initWithDeviceModelName:@"iOS 6"];
        environment.apiId = TG_API_ID;
        environment.appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.13.0";
        environment.layer = @(229);
        NSDictionary *proxy = [self savedProxySettings];
        if ([proxy[@"enabled"] boolValue]) environment = [environment withUpdatedSocksProxySettings:[self proxyForSettings:proxy]];
        TGSerialization *serialization = [[TGSerialization alloc] init];
        serialization.tl = _tl;
        _context = [[MTContext alloc] initWithSerialization:serialization
                                    encryptionProvider:[[OpenSSLEncryptionProvider alloc] init]
                                        apiEnvironment:environment
                                   isTestingEnvironment:false useTempAuthKeys:false];
#if __LP64__
        _context.makeTcpConnectionInterface = ^id<MTTcpConnectionInterface>(id<MTTcpConnectionInterfaceDelegate> delegate,
                                                                              dispatch_queue_t delegateQueue) {
            return [[TGModernTcpConnection alloc] initWithDelegate:delegate delegateQueue:delegateQueue];
        };
#endif
        _context.keychain = [[TGDeviceKeychain alloc] initWithNamespace:_accountIdentifier];
        // Keep the original IPv4 bootstrap for iOS 6; modern networks may need IPv6.
#if __LP64__
        NSArray *seedIps = @[
            @[@"149.154.175.50", @"2001:b28:f23d:f001::a"],
            @[@"149.154.167.50", @"95.161.76.100", @"2001:67c:4e8:f002::a"],
            @[@"149.154.175.100", @"2001:b28:f23d:f003::a"],
            @[@"149.154.167.91", @"2001:67c:4e8:f004::a"],
            @[@"149.154.171.5", @"2001:b28:f23f:f005::a"]
        ];
#else
        NSArray *seedIps = @[
            @[@"149.154.175.51"], @[@"149.154.167.50"], @[@"149.154.175.100"],
            @[@"149.154.167.91"], @[@"91.108.56.125"]
        ];
#endif
        for (NSUInteger i = 0; i < seedIps.count; i++) {
            NSMutableArray *addresses = [NSMutableArray array];
            for (NSString *ip in seedIps[i]) {
                MTDatacenterAddress *address = [[MTDatacenterAddress alloc]
                    initWithIp:ip port:443 preferForMedia:false restrictToTcp:true
                            cdn:false preferForProxy:false secret:nil];
                [addresses addObject:address];
            }
            [_context setSeedAddressSetForDatacenterWithId:i + 1
                seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:addresses]];
        }
        _dc = [[NSUserDefaults standardUserDefaults] integerForKey:[self preferenceKey:@"telegramDc"]];
        if (_dc < 1 || _dc > 5) _dc = [[_context.keychain numberForKey:@"datacenter" group:@"app"] integerValue];
        if (_dc < 1 || _dc > 5) _dc = 2;
    }
    return self;
}
- (NSString *)accountIdentifier { return _accountIdentifier; }
- (NSCache *)stickerKeyboardPreviewCache {
    @synchronized (self) {
        if (!_stickerKeyboardPreviewCache) { _stickerKeyboardPreviewCache=[[NSCache alloc] init]; _stickerKeyboardPreviewCache.totalCostLimit=4*1024*1024; _stickerKeyboardPreviewCache.countLimit=128; }
        return _stickerKeyboardPreviewCache;
    }
}
- (NSString *)stickerKeyboardPreviewPathForDocument:(NSDictionary *)document {
    return [[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"sticker-keyboard-v1-%lld.png",[document[@"id"] longLongValue]]];
}

- (NSString *)preferenceKey:(NSString *)name { return _accountIdentifier.length ? [name stringByAppendingFormat:@"-%@", _accountIdentifier] : name; }
- (void)suspendConnection { [_mtProto stop]; _service = nil; for (MTProto *proto in _mediaProtos.allValues) [proto stop]; [_mediaServices removeAllObjects]; [_mediaProtos removeAllObjects]; }
- (BOOL)hasSavedSession {
    return [[NSUserDefaults standardUserDefaults] boolForKey:[self preferenceKey:@"telegramAuthorized"]] ||
        [[_context.keychain numberForKey:@"authorized" group:@"app"] boolValue];
}
- (BOOL)isReady { return _service != nil; }
- (void)report:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{ if (self.status) self.status(message); });
}
- (void)setConnectionTrouble:(BOOL)trouble {
    if (_connectionTrouble == trouble) return;
    _connectionTrouble = trouble;
    [[NSNotificationCenter defaultCenter] postNotificationName:TGClientNetworkNotification
        object:self userInfo:@{ @"active": @(trouble) }];
}
- (void)openDatacenter:(NSInteger)dc completion:(void (^)(NSString *))completion {
#if __LP64__
    TGAuthTraceStage = @"ожидаем TCP соединение";
    TGAuthTraceClient = self;
    MTLogSetLoggingFunction(TGAuthTraceLog);
#endif
    [self setConnectionTrouble:YES];
    _generation++;
    NSUInteger generation = _generation;
    _dc = dc;
    [_authAction cancel];
    [_mtProto stop];
    _service = nil;
    _mtProto = nil;
    [self report:[NSString stringWithFormat:@"DC%ld: создаём ключ MTProto…", (long)dc]];
    __weak TGClient *weakSelf = self;
    _authAction = [[MTDatacenterAuthAction alloc]
        initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorPersistent
                             isCdn:false skipBind:true
                         completion:^(__unused MTDatacenterAuthAction *action, bool success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TGClient *client = weakSelf;
            if (!client || generation != client->_generation) return;
            if (!success) { completion(@"Не удалось создать ключ MTProto."); return; }
            [client report:@"Ключ готов, соединяемся с Telegram…"];
            client->_mtProto = [[MTProto alloc] initWithContext:client->_context datacenterId:dc
                    usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
            client->_mtProto.useUnauthorizedMode = false;
            client->_service = [[MTRequestMessageService alloc] initWithContext:client->_context];
            [client->_mtProto addMessageService:client->_service];
            client->_phoneUpdates = [[TGPhoneUpdateService alloc] init];
            client->_phoneUpdates.client = client;
            [client->_mtProto addMessageService:client->_phoneUpdates];
            [client->_mtProto resume];
#if __LP64__
            MTLogSetLoggingFunction(NULL);
#endif
            completion(nil);
        });
    }];
    [_authAction execute:_context datacenterId:dc];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        TGClient *client = weakSelf;
        if (client && generation == client->_generation && !client->_service) {
            client->_generation++;
            [client->_authAction cancel];
#if __LP64__
            MTLogSetLoggingFunction(NULL);
            completion([NSString stringWithFormat:@"Тайм-аут создания ключа MTProto (45 с). Этап: %@.",
                TGAuthTraceStage ?: @"неизвестен"]);
#else
            completion(@"Тайм-аут создания ключа MTProto (45 с). ");
#endif
        }
    });
}
- (void)rpc:(NSData *)payload name:(NSString *)name completion:(TGClientCompletion)completion {
    [self rpc:payload name:name service:_service completion:completion];
}
- (void)rpc:(NSData *)payload name:(NSString *)name service:(MTRequestMessageService *)service completion:(TGClientCompletion)completion {
    if (!service || !payload) {
        if (service == _service) [self setConnectionTrouble:YES];
        completion(nil, @"Нет соединения с Telegram."); return;
    }
    MTRequest *request = [[MTRequest alloc] init];
    [request setPayload:payload metadata:name shortMetadata:name responseParser:^id(NSData *data) {
        return data.length >= 4 ? data : nil;
    }];
    request.needsTimeoutTimer = true;
    request.shouldContinueExecutionWithErrorContext = ^bool(__unused MTRequestErrorContext *context) { return false; };
    __weak TGClient *weakSelf = self;
    __weak MTRequest *weakRequest = request;
    __block BOOL finished = NO;
    request.completed = ^(id result, __unused MTRequestResponseInfo *info, MTRpcError *error) {
        TGClient *decodingClient = weakSelf;
        if (!decodingClient) return;
        TGTL *tl = decodingClient->_tl;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *decodeError = nil;
            NSDictionary *decoded = error ? nil : [tl decode:result error:&decodeError];
            NSString *replyError = error ? (error.errorDescription ?: @"Ошибка Telegram.") : nil;
            if (!error && !decoded) {
                uint32_t constructor = 0;
                if ([result isKindOfClass:[NSData class]] && [result length] >= 4)
                    [result getBytes:&constructor length:4];
                replyError = [NSString stringWithFormat:@"Ответ %@: 0x%08x, %lu байт. %@",
                    name, constructor, (unsigned long)[result length], decodeError ?: @"TL ошибка"];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                TGClient *client = weakSelf;
                if (!client || finished) return;
                finished = YES;
                [client->_requests removeObject:weakRequest];
                if (service == client->_service) [client setConnectionTrouble:NO];
                completion(decoded, replyError);
            });
        });
    };
    [_requests addObject:request];
    [service addRequest:request];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        TGClient *client = weakSelf;
        if (!client || finished) return;
        finished = YES;
        if (service == client->_service) [client setConnectionTrouble:YES];
        [service removeRequestByInternalId:request.internalId];
        [client->_requests removeObject:request];
        completion(nil, [NSString stringWithFormat:@"Тайм-аут %@ (60 с).", name]);
    });
}
- (void)restoreSession:(TGClientCompletion)completion {
    if (!self.hasSavedSession) { completion(nil, @"Нет сохранённого входа."); return; }
    if (![_context authInfoForDatacenterWithId:_dc selector:MTDatacenterAuthInfoSelectorPersistent]) {
        completion(nil, @"Сохранённый ключ Telegram не найден. Войдите снова."); return;
    }
    [self openDatacenter:_dc completion:^(NSString *error) {
        if (error) { completion(nil, error); return; }
        [self->_context updateAuthTokenForDatacenterWithId:self->_dc authToken:@1];
        [self->_context.keychain setObject:@YES forKey:@"authorized" group:@"app"];
        [self->_context.keychain setObject:@(self->_dc) forKey:@"datacenter" group:@"app"];
        TGRememberAccount(self.accountIdentifier, nil);
        completion(@{ @"_": @"session.restored" }, nil);
    }];
}
- (void)prepareCallKey:(TGCallKeyCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x26cf8950]; // messages.getDhConfig
    [stream writeInt32:0]; // request the complete configuration
    [stream writeInt32:256];
    [self rpc:[stream currentBytes] name:@"messages.getDhConfig" completion:^(NSDictionary *result, NSString *rpcError) {
        if (rpcError) { completion(nil, rpcError); return; }
        if (![result[@"_"] isEqual:@"messages.dhConfig"] ||
            ![result[@"p"] isKindOfClass:[NSData class]] || !result[@"g"]) {
            completion(nil, @"Telegram не прислал параметры ключа звонка."); return;
        }
        NSData *prime = result[@"p"];
        int32_t generator = [result[@"g"] intValue];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *keyError = nil;
            TGCallCrypto *exchange = [[TGCallCrypto alloc] initWithPrime:prime generator:generator error:&keyError];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(exchange, keyError); });
        });
    }];
}
- (BOOL)writeCall:(NSDictionary *)call to:(MTOutputStream *)stream {
    if (![call[@"id"] isKindOfClass:[NSNumber class]] ||
        ![call[@"access_hash"] isKindOfClass:[NSNumber class]]) return NO;
    [stream writeInt32:(int32_t)0x1e36fded]; // inputPhoneCall
    [stream writeInt64:[call[@"id"] longLongValue]];
    [stream writeInt64:[call[@"access_hash"] longLongValue]];
    return YES;
}
- (BOOL)writeCallProtocolTo:(MTOutputStream *)stream minLayer:(int32_t)minLayer
                   maxLayer:(int32_t)maxLayer versions:(NSArray *)versions {
    if (minLayer < 1 || maxLayer < minLayer || maxLayer > 92 || versions.count == 0 || versions.count > 16)
        return NO;
    for (id version in versions)
        if (![version isKindOfClass:[NSString class]] || [version length] == 0 || [version length] > 32)
            return NO;
    [stream writeInt32:(int32_t)0xfc878fc8]; // phoneCallProtocol
    [stream writeInt32:3]; // udp_p2p and udp_reflector
    [stream writeInt32:minLayer]; [stream writeInt32:maxLayer];
    [stream writeInt32:(int32_t)0x1cb5c415]; [stream writeInt32:(int32_t)versions.count];
    for (NSString *version in versions) [stream writeString:version];
    return YES;
}
- (void)requestAudioCallToUser:(NSDictionary *)inputUser publicHash:(NSData *)publicHash
                  minLayer:(int32_t)minLayer maxLayer:(int32_t)maxLayer
                  versions:(NSArray *)versions completion:(TGClientCompletion)completion {
    if (![inputUser[@"_"] isEqual:@"inputPeerUser"] || !inputUser[@"user_id"] ||
        !inputUser[@"access_hash"] || publicHash.length != 32) {
        completion(nil, @"Неверный пользователь или ключ звонка."); return;
    }
    uint32_t randomId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomId), (uint8_t *)&randomId) != errSecSuccess) {
        completion(nil, @"Не удалось создать случайный идентификатор звонка."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x42ff96ed]; // phone.requestCall
    [stream writeInt32:0]; // audio only
    [stream writeInt32:(int32_t)0xf21158c6]; // inputUser
    [stream writeInt64:[inputUser[@"user_id"] longLongValue]];
    [stream writeInt64:[inputUser[@"access_hash"] longLongValue]];
    [stream writeInt32:(int32_t)randomId];
    [stream writeBytes:publicHash];
    if (![self writeCallProtocolTo:stream minLayer:minLayer maxLayer:maxLayer versions:versions]) {
        completion(nil, @"Неподдерживаемый медиапротокол звонка."); return;
    }
    [self rpc:[stream currentBytes] name:@"phone.requestCall" completion:completion];
}
- (void)acceptAudioCall:(NSDictionary *)call publicValue:(NSData *)publicValue
               minLayer:(int32_t)minLayer maxLayer:(int32_t)maxLayer
               versions:(NSArray *)versions completion:(TGClientCompletion)completion {
    if (publicValue.length != 256) { completion(nil, @"Неверный ключ звонка."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x3bd2b4a0]; // phone.acceptCall
    if (![self writeCall:call to:stream]) { completion(nil, @"Неверный идентификатор звонка."); return; }
    [stream writeBytes:publicValue];
    if (![self writeCallProtocolTo:stream minLayer:minLayer maxLayer:maxLayer versions:versions]) {
        completion(nil, @"Неподдерживаемый медиапротокол звонка."); return;
    }
    [self rpc:[stream currentBytes] name:@"phone.acceptCall" completion:completion];
}
- (void)confirmAudioCall:(NSDictionary *)call publicValue:(NSData *)publicValue
             fingerprint:(int64_t)fingerprint minLayer:(int32_t)minLayer maxLayer:(int32_t)maxLayer
                versions:(NSArray *)versions completion:(TGClientCompletion)completion {
    if (publicValue.length != 256) { completion(nil, @"Неверный ключ звонка."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x2efe1722]; // phone.confirmCall
    if (![self writeCall:call to:stream]) { completion(nil, @"Неверный идентификатор звонка."); return; }
    [stream writeBytes:publicValue]; [stream writeInt64:fingerprint];
    if (![self writeCallProtocolTo:stream minLayer:minLayer maxLayer:maxLayer versions:versions]) {
        completion(nil, @"Неподдерживаемый медиапротокол звонка."); return;
    }
    [self rpc:[stream currentBytes] name:@"phone.confirmCall" completion:completion];
}
- (void)acknowledgeIncomingCall:(NSDictionary *)call completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x17d54f61]; // phone.receivedCall
    if (![self writeCall:call to:stream]) { completion(nil, @"Неверный идентификатор звонка."); return; }
    [self rpc:[stream currentBytes] name:@"phone.receivedCall" completion:completion];
}
- (void)endAudioCall:(NSDictionary *)call reason:(NSString *)reason duration:(int32_t)duration
       connectionId:(int64_t)connectionId
            completion:(TGClientCompletion)completion {
    NSDictionary *reasons = @{ @"hangup": @((int32_t)0x57adc690), @"busy": @((int32_t)0xfaf7e8c9),
                               @"missed": @((int32_t)0x85e42301), @"disconnect": @((int32_t)0xe095c1a0) };
    NSNumber *constructor = reasons[reason ?: @""];
    if (!constructor) { completion(nil, @"Неверная причина завершения звонка."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xb2cbc1c0]; // phone.discardCall
    [stream writeInt32:0]; // audio only
    if (![self writeCall:call to:stream]) { completion(nil, @"Неверный идентификатор звонка."); return; }
    [stream writeInt32:MAX(0, duration)]; [stream writeInt32:[constructor intValue]];
    [stream writeInt64:connectionId];
    [self rpc:[stream currentBytes] name:@"phone.discardCall" completion:completion];
}
- (void)sendCallSignalingData:(NSData *)data call:(NSDictionary *)call completion:(TGClientCompletion)completion {
    if (!data.length || data.length > 65536) { completion(nil, @"Неверные данные сигнализации."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xff7a9383]; // phone.sendSignalingData
    if (![self writeCall:call to:stream]) { completion(nil, @"Неверный идентификатор звонка."); return; }
    [stream writeBytes:data];
    [self rpc:[stream currentBytes] name:@"phone.sendSignalingData" completion:completion];
}
- (void)sendCodeToPhone:(NSString *)phone completion:(TGClientCompletion)completion {
    NSCharacterSet *ignored = [NSCharacterSet characterSetWithCharactersInString:@" ()-\t\n"];
    _phone = [[phone componentsSeparatedByCharactersInSet:ignored] componentsJoinedByString:@""];
    NSString *digits = [_phone hasPrefix:@"+"] ? [_phone substringFromIndex:1] : @"";
    if (digits.length < 5 || digits.length > 15 || [[digits stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] length]) {
        completion(nil, @"Введите номер в формате +79991234567."); return;
    }
    _phoneCodeHash = nil;
    [self sendCodeOnDatacenter:2 migrations:0 completion:completion];
}
- (void)sendCodeOnDatacenter:(NSInteger)dc migrations:(NSUInteger)migrations completion:(TGClientCompletion)completion {
    [self openDatacenter:dc completion:^(NSString *error) {
        if (error) { completion(nil, error); return; }
        MTOutputStream *stream = [[MTOutputStream alloc] init];
        [stream writeInt32:(int32_t)0xa677244f];
        [stream writeString:self->_phone];
        [stream writeInt32:TG_API_ID];
        [stream writeString:TG_API_HASH];
        [stream writeInt32:(int32_t)0xad253d78];
        [stream writeInt32:0];
        [self report:@"Отправляем запрос кода…"];
        [self rpc:[stream currentBytes] name:@"auth.sendCode" completion:^(NSDictionary *result, NSString *rpcError) {
            if (rpcError && migrations < 5 && ([rpcError hasPrefix:@"PHONE_MIGRATE_"] || [rpcError hasPrefix:@"NETWORK_MIGRATE_"])) {
                NSInteger nextDc = [[[rpcError componentsSeparatedByString:@"_"] lastObject] integerValue];
                if (nextDc >= 1 && nextDc <= 5 && nextDc != dc) {
                    [self sendCodeOnDatacenter:nextDc migrations:migrations + 1 completion:completion]; return;
                }
            }
            if (rpcError) { completion(nil, rpcError); return; }
            if ([result[@"_"] isEqual:@"auth.sentCode"]) {
                self->_phoneCodeHash = result[@"phone_code_hash"];
                if (!self->_phoneCodeHash.length) { completion(nil, @"Telegram не вернул phone_code_hash."); return; }
                completion(result, nil);
            } else if ([result[@"_"] isEqual:@"auth.sentCodeSuccess"]) {
                [self authorized]; completion(result, nil);
            } else {
                completion(nil, @"Неожиданный ответ auth.sendCode.");
            }
        }];
    }];
}
- (void)resendLoginCode:(TGClientCompletion)completion {
    if (!_phone.length || !_phoneCodeHash.length) {
        completion(nil, @"Сначала запросите код для номера телефона."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xcae47523]; // auth.resendCode
    [stream writeInt32:0];
    [stream writeString:_phone];
    [stream writeString:_phoneCodeHash];
    [self report:@"Запрашиваем код повторно…"];
    [self rpc:[stream currentBytes] name:@"auth.resendCode" completion:^(NSDictionary *result, NSString *error) {
        if (error) { completion(nil, error); return; }
        if ([result[@"_"] isEqual:@"auth.sentCode"] && [result[@"phone_code_hash"] length]) {
            self->_phoneCodeHash = result[@"phone_code_hash"];
            completion(result, nil);
        } else if ([result[@"_"] isEqual:@"auth.sentCodeSuccess"]) {
            [self authorized]; completion(result, nil);
        } else { completion(nil, @"Telegram не вернул новый код для входа."); }
    }];
}
- (void)signInWithCode:(NSString *)code completion:(TGClientCompletion)completion {
    if (!_phoneCodeHash.length) { completion(nil, @"Сначала запросите код ещё раз."); return; }
    NSString *trimmed = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) { completion(nil, @"Введите код."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x8d52a951];
    [stream writeInt32:1];
    [stream writeString:_phone];
    [stream writeString:_phoneCodeHash];
    [stream writeString:trimmed];
    [self report:@"Проверяем код…"];
    [self rpc:[stream currentBytes] name:@"auth.signIn" completion:^(NSDictionary *result, NSString *error) {
        if (error) { completion(nil, error); return; }
        if ([result[@"_"] isEqual:@"auth.authorization"]) [self authorized];
        completion(result, nil);
    }];
}
- (void)signInWithPassword:(NSString *)password completion:(TGClientCompletion)completion {
    MTOutputStream *get = [[MTOutputStream alloc] init];
    [get writeInt32:(int32_t)0x548a30f5];
    [self report:@"Получаем параметры 2FA…"];
    [self rpc:[get currentBytes] name:@"account.getPassword" completion:^(NSDictionary *config, NSString *error) {
        if (error) { completion(nil, error); return; }
        [self report:@"Вычисляем доказательство SRP…"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *srpError = nil;
            NSData *proof = [TGSRP proofForPassword:password configuration:config error:&srpError];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!proof) { completion(nil, srpError); return; }
                MTOutputStream *check = [[MTOutputStream alloc] init];
                [check writeInt32:(int32_t)0xd18b4d16];
                [check writeData:proof];
                [self report:@"Проверяем пароль 2FA…"];
                [self rpc:[check currentBytes] name:@"auth.checkPassword" completion:^(NSDictionary *result, NSString *checkError) {
                    if (!checkError && [result[@"_"] isEqual:@"auth.authorization"]) [self authorized];
                    completion(result, checkError);
                }];
            });
        });
    }];
}
- (void)authorized {
    TGRememberAccount(self.accountIdentifier, nil);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:[self preferenceKey:@"telegramAuthorized"]];
    [defaults setInteger:_dc forKey:[self preferenceKey:@"telegramDc"]];
    [defaults synchronize];
    [_context.keychain setObject:@YES forKey:@"authorized" group:@"app"];
    [_context.keychain setObject:@(_dc) forKey:@"datacenter" group:@"app"];
    [_context updateAuthTokenForDatacenterWithId:_dc authToken:@1];
}
- (void)clearSavedSession {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:[self preferenceKey:@"telegramAuthorized"]];
    [defaults synchronize];
    [_context.keychain removeObjectForKey:@"authorized" group:@"app"];
    [_context.keychain removeObjectForKey:@"datacenter" group:@"app"];
    [_context updateAuthInfoForDatacenterWithId:_dc authInfo:nil selector:MTDatacenterAuthInfoSelectorPersistent];
    [_context removeAllAuthTokens];
    [_mtProto stop]; _mtProto = nil; _service = nil;
    for (MTProto *proto in _mediaProtos.allValues) [proto stop];
    [_mediaProtos removeAllObjects]; [_mediaServices removeAllObjects];
    [_avatarWaiters removeAllObjects];
    TGClearAccountMediaCache([self cacheDirectory], !_accountIdentifier.length);
}
- (NSString *)cacheDirectory {
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *path = [library stringByAppendingPathComponent:@"TelegramMessageCache"];
    if (_accountIdentifier.length) path = [path stringByAppendingPathComponent:_accountIdentifier];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}
- (NSString *)cachePathForFolder:(NSInteger)folder {
    return [[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"dialogs-%ld.plist", (long)folder]];
}
- (NSString *)cachePathForPeer:(NSDictionary *)peer {
    NSString *type = peer[@"_"] ?: @"peer";
    NSNumber *identifier = peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"] ?: @0;
    return [[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"history-%@-%@.plist", type, identifier]];
}
- (NSDictionary *)readCache:(NSString *)path {
    NSDictionary *cached = [NSDictionary dictionaryWithContentsOfFile:path];
    return [cached isKindOfClass:[NSDictionary class]] ? cached : nil;
}
- (void)writeCache:(NSDictionary *)result toPath:(NSString *)path {
    if (![result isKindOfClass:[NSDictionary class]]) return;
    static dispatch_queue_t cacheQueue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cacheQueue = dispatch_queue_create("telegram.cache", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(cacheQueue, ^{
        [result writeToFile:path atomically:YES];
        [[NSFileManager defaultManager] setAttributes:@{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication }
                                             ofItemAtPath:path error:nil];
    });
}
- (dispatch_queue_t)historyCacheQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("telegram.history.cache", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
- (void)mergeHistoryCache:(NSDictionary *)result toPath:(NSString *)path {
    if (![result[@"messages"] isKindOfClass:[NSArray class]]) return;
    dispatch_async([self historyCacheQueue], ^{
        NSDictionary *old = [NSDictionary dictionaryWithContentsOfFile:path];
        NSMutableDictionary *merged = [result mutableCopy];
        NSMutableDictionary *byId = [NSMutableDictionary dictionary];
        for (NSDictionary *message in old[@"messages"])
            if (message[@"id"]) byId[message[@"id"]] = message;
        for (NSDictionary *message in result[@"messages"])
            if (message[@"id"]) byId[message[@"id"]] = message;
        NSArray *ids = [[byId allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
            return [b compare:a];
        }];
        NSMutableArray *messages = [NSMutableArray array];
        for (NSNumber *identifier in ids) {
            if (messages.count >= 200) break;
            [messages addObject:byId[identifier]];
        }
        merged[@"messages"] = messages;
        for (NSString *key in @[@"users", @"chats"]) {
            NSMutableDictionary *entities = [NSMutableDictionary dictionary];
            for (NSDictionary *entity in old[key]) if (entity[@"id"]) entities[entity[@"id"]] = entity;
            for (NSDictionary *entity in result[key]) if (entity[@"id"]) entities[entity[@"id"]] = entity;
            merged[key] = [entities allValues];
        }
        [merged writeToFile:path atomically:YES];
        [[NSFileManager defaultManager] setAttributes:@{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication }
                                             ofItemAtPath:path error:nil];
    });
}
- (void)changeCachedMessage:(int32_t)messageId inPeer:(NSDictionary *)peer text:(NSString *)text deleted:(BOOL)deleted {
    NSString *mainPath = [self cachePathForPeer:peer];
    NSString *topicPrefix = [NSString stringWithFormat:@"topic-%@-", peer[@"channel_id"] ?: @0];
    NSString *directory = [self cacheDirectory];
    dispatch_async([self historyCacheQueue], ^{
        NSMutableArray *paths = [NSMutableArray arrayWithObject:mainPath];
        if (peer[@"channel_id"]) for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil])
            if ([name hasPrefix:topicPrefix] && [name hasSuffix:@".plist"])
                [paths addObject:[directory stringByAppendingPathComponent:name]];
        for (NSString *path in paths) {
            NSDictionary *old = [NSDictionary dictionaryWithContentsOfFile:path];
            if (!old[@"messages"]) continue;
            NSMutableArray *messages = [NSMutableArray array];
            BOOL changed = NO;
            for (NSDictionary *message in old[@"messages"]) {
                if ([message[@"id"] intValue] != messageId) { [messages addObject:message]; continue; }
                changed = YES;
                if (!deleted) {
                    NSMutableDictionary *updated = [message mutableCopy];
                    updated[@"message"] = text ?: @"";
                    [messages addObject:updated];
                }
            }
            if (!changed) continue;
            NSMutableDictionary *updated = [old mutableCopy];
            updated[@"messages"] = messages;
            [updated writeToFile:path atomically:YES];
        }
    });
}
- (void)getDialogs:(TGClientCompletion)completion {
    [self getDialogsForFolder:0 completion:completion];
}
- (NSDictionary *)cachedDialogsForFolder:(NSInteger)folder { return [self readCache:[self cachePathForFolder:folder]]; }
- (NSString *)selfProfileCachePath {
    return [[self cacheDirectory] stringByAppendingPathComponent:@"self-profile.plist"];
}
- (NSDictionary *)cachedSelfProfile { return [self readCache:[self selfProfileCachePath]]; }
- (NSString *)savedMusicKeyForUser:(NSDictionary *)user {
    NSNumber *identifier = user[@"user_id"];
    return identifier ? [NSString stringWithFormat:@"user-%@", identifier] : @"self";
}
- (NSString *)savedMusicCachePathForUser:(NSDictionary *)user {
    return [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"saved-music-%@.plist", [self savedMusicKeyForUser:user]]];
}
- (NSDictionary *)cachedSavedMusicForUser:(NSDictionary *)user {
    NSString *key = [self savedMusicKeyForUser:user];
    NSDictionary *cached = _savedMusicSnapshots[key];
    if (!cached) {
        cached = [self readCache:[self savedMusicCachePathForUser:user]];
        if (cached) _savedMusicSnapshots[key] = cached;
    }
    return cached;
}
- (void)getSelfProfile:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xb60f5918]; // users.getFullUser
    [stream writeInt32:(int32_t)0xf7c1b13f]; // inputUserSelf
    [self rpc:[stream currentBytes] name:@"users.getFullUser" completion:^(NSDictionary *result, NSString *error) {
        if (!error && [result[@"_"] isEqual:@"users.userFull"]) { [self writeCache:result toPath:[self selfProfileCachePath]]; for (NSDictionary *user in result[@"users"]) if ([user[@"id"] isEqual:result[@"full_user"][@"id"]]) { TGRememberAccount(self.accountIdentifier, user); break; } }
        completion(result, error);
    }];
}
- (void)getSavedMusicForUser:(NSDictionary *)user offset:(int32_t)offset limit:(int32_t)limit completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x788d7fe3]; // users.getSavedMusic
    if (!user || [user[@"_"] isEqual:@"inputPeerSelf"] || [user[@"_"] isEqual:@"inputUserSelf"]) {
        [stream writeInt32:(int32_t)0xf7c1b13f];
    } else if (user[@"user_id"] && user[@"access_hash"]) {
        [stream writeInt32:(int32_t)0xf21158c6]; // inputUser
        [stream writeInt64:[user[@"user_id"] longLongValue]];
        [stream writeInt64:[user[@"access_hash"] longLongValue]];
    } else { completion(nil, @"Неизвестный пользователь."); return; }
    [stream writeInt32:MAX(0, offset)];
    [stream writeInt32:MIN(50, MAX(1, limit))];
    [stream writeInt64:0]; // no cached hash
    [self rpc:[stream currentBytes] name:@"users.getSavedMusic" completion:^(NSDictionary *result, NSString *error) {
        if (!error && offset == 0 && [result[@"_"] isEqual:@"users.savedMusic"]) {
            NSDictionary *snapshot = result;
            if (limit == 1) {
                NSDictionary *old = [self cachedSavedMusicForUser:user];
                NSArray *oldDocuments = old[@"documents"];
                if (oldDocuments.count > 1 && [result[@"count"] integerValue] > 1) {
                    NSMutableArray *merged = [NSMutableArray arrayWithArray:result[@"documents"]];
                    for (NSDictionary *candidate in oldDocuments) {
                        if (merged.count >= [result[@"count"] integerValue]) break;
                        if (![candidate[@"id"] isEqual:[merged.firstObject objectForKey:@"id"]]) [merged addObject:candidate];
                    }
                    NSMutableDictionary *copy = [result mutableCopy];
                    copy[@"documents"] = merged;
                    snapshot = copy;
                }
            }
            _savedMusicSnapshots[[self savedMusicKeyForUser:user]] = snapshot;
            [self writeCache:snapshot toPath:[self savedMusicCachePathForUser:user]];
        }
        completion(result, error);
    }];
}
- (void)saveMusicDocument:(NSDictionary *)document remove:(BOOL)remove completion:(TGClientCompletion)completion {
    if (!document[@"id"] || !document[@"access_hash"]) { completion(nil, @"Аудиофайл недоступен."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xb26732a9]; // account.saveMusic
    [stream writeInt32:remove ? 1 : 0];
    [stream writeInt32:(int32_t)0x1abfb575]; // inputDocument
    [stream writeInt64:[document[@"id"] longLongValue]];
    [stream writeInt64:[document[@"access_hash"] longLongValue]];
    [stream writeBytes:document[@"file_reference"] ?: [NSData data]];
    [self rpc:[stream currentBytes] name:@"account.saveMusic" completion:^(NSDictionary *result, NSString *error) {
        if (!error && [result[@"_"] isEqual:@"boolTrue"]) {
            NSMutableDictionary *cached = [[self cachedSavedMusicForUser:nil] mutableCopy];
            if (!cached) cached = [@{ @"_": @"users.savedMusic", @"count": @0, @"documents": @[] } mutableCopy];
            NSMutableArray *documents = [cached[@"documents"] mutableCopy] ?: [[NSMutableArray alloc] init];
            NSIndexSet *same = [documents indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger index, BOOL *stop) {
                return [item[@"id"] isEqual:document[@"id"]];
            }];
            [documents removeObjectsAtIndexes:same];
            if (!remove) [documents insertObject:document atIndex:0];
            cached[@"documents"] = documents;
            NSInteger count = [cached[@"count"] integerValue] + (remove ? -1 : same.count ? 0 : 1);
            cached[@"count"] = @(MAX(0, count));
            _savedMusicSnapshots[[self savedMusicKeyForUser:nil]] = cached;
            [self writeCache:cached toPath:[self savedMusicCachePathForUser:nil]];
        }
        completion(result, error);
    }];
}
- (void)uploadProfileMusicData:(NSData *)data fileName:(NSString *)fileName duration:(int32_t)duration completion:(TGClientCompletion)completion {
    NSString *extension = [[fileName pathExtension] lowercaseString];
    if (![@[@"mp3", @"m4a", @"aac", @"wav"] containsObject:extension]) {
        completion(nil, @"Выберите MP3, M4A, AAC или WAV."); return;
    }
    if (!data.length || data.length > 15 * 1024 * 1024) { completion(nil, @"Трек пустой или больше 15 МБ."); return; }
    int64_t fileId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(fileId), (uint8_t *)&fileId) != errSecSuccess) {
        completion(nil, @"Не удалось создать ID файла."); return;
    }
    int32_t count = (int32_t)((data.length + 524287) / 524288);
    [self uploadProfileMusicData:data fileName:fileName fileId:fileId part:0 count:count duration:duration completion:completion];
}
- (void)uploadProfileMusicData:(NSData *)data fileName:(NSString *)fileName fileId:(int64_t)fileId
    part:(int32_t)part count:(int32_t)count duration:(int32_t)duration completion:(TGClientCompletion)completion {
    BOOL big = data.length > 10 * 1024 * 1024;
    if (part < count) {
        NSUInteger offset = (NSUInteger)part * 524288;
        NSData *chunk = [data subdataWithRange:NSMakeRange(offset, MIN((NSUInteger)524288, data.length - offset))];
        MTOutputStream *stream = [[MTOutputStream alloc] init];
        [stream writeInt32:(int32_t)(big ? 0xde7b673d : 0xb304a621)];
        [stream writeInt64:fileId];
        [stream writeInt32:part];
        if (big) [stream writeInt32:count];
        [stream writeBytes:chunk];
        [self rpc:[stream currentBytes] name:@"upload.saveFilePart.music" completion:^(NSDictionary *result, NSString *error) {
            if (error || ![result[@"_"] isEqual:@"boolTrue"]) { completion(nil, error ?: @"Telegram отклонил часть аудиофайла."); return; }
            [self uploadProfileMusicData:data fileName:fileName fileId:fileId part:part + 1 count:count duration:duration completion:completion];
        }];
        return;
    }
    NSString *checksum = @"";
    if (!big) {
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5(data.bytes, (CC_LONG)data.length, digest);
        NSMutableString *hex = [NSMutableString string];
        for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
        checksum = hex;
    }
    NSString *extension = [[fileName pathExtension] lowercaseString];
    NSString *mime = [extension isEqual:@"mp3"] ? @"audio/mpeg" : [extension isEqual:@"m4a"] ? @"audio/mp4" :
        [extension isEqual:@"aac"] ? @"audio/aac" : @"audio/wav";
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x14967978]; // messages.uploadMedia
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0x7da07ec9]; // inputPeerSelf
    [stream writeInt32:(int32_t)0x037c9330]; // inputMediaUploadedDocument
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)(big ? 0xfa4f0bb5 : 0xf52ff27f)];
    [stream writeInt64:fileId];
    [stream writeInt32:count];
    [stream writeString:fileName];
    if (!big) [stream writeString:checksum];
    [stream writeString:mime];
    [stream writeInt32:(int32_t)0x1cb5c415]; // Vector
    [stream writeInt32:2];
    [stream writeInt32:(int32_t)0x15590068];
    [stream writeString:fileName];
    [stream writeInt32:(int32_t)0x9852f9c6]; // documentAttributeAudio
    [stream writeInt32:3]; // title and performer
    [stream writeInt32:MAX(0, duration)];
    [stream writeString:[fileName stringByDeletingPathExtension]];
    [stream writeString:@""];
    [self rpc:[stream currentBytes] name:@"messages.uploadMedia.music" completion:completion];
}
- (void)getMusicFileForDocument:(NSDictionary *)document completion:(TGDocumentPathCompletion)completion {
    int64_t expected = [document[@"size"] longLongValue];
    if (!document[@"id"] || !document[@"access_hash"] || !document[@"dc_id"] || expected <= 0 || expected > 40 * 1024 * 1024) {
        completion(nil, @"Файл недоступен или больше 40 МБ для этого iPhone."); return;
    }
    NSString *key = [document[@"id"] description];
    NSMutableArray *waiting = _musicWaiters[key];
    if (waiting) { [waiting addObject:[completion copy]]; return; }
    _musicWaiters[key] = [NSMutableArray arrayWithObject:[completion copy]];
    __weak TGClient *weakSelf = self;
    TGDocumentPathCompletion finish = ^(NSString *finishedPath, NSString *error) {
        TGClient *current = weakSelf;
        if (!current) return;
        NSArray *callbacks = [current->_musicWaiters[key] copy];
        [current->_musicWaiters removeObjectForKey:key];
        for (TGDocumentPathCompletion callback in callbacks) callback(finishedPath, error);
    };
    NSString *mime = document[@"mime_type"];
    NSString *extension = [mime isEqual:@"audio/mp4"] ? @"m4a" : [mime isEqual:@"audio/aac"] ? @"aac" :
        [mime isEqual:@"audio/wav"] || [mime isEqual:@"audio/x-wav"] ? @"wav" : @"mp3";
    NSString *path = [[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"music-%@.%@", document[@"id"], extension]];
    NSString *partialPath = [path stringByAppendingString:@".part"];
    dispatch_async(TGMediaCacheQueue(), ^{
        unsigned long long cachedSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
        unsigned long long partialSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:partialPath error:nil] fileSize];
        if (partialSize > (unsigned long long)expected ||
            (partialSize != (unsigned long long)expected && partialSize % 524288 != 0)) {
            [[NSFileManager defaultManager] removeItemAtPath:partialPath error:nil];
            partialSize = 0;
        }
        if (cachedSize != (unsigned long long)expected && partialSize == (unsigned long long)expected) {
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            if ([[NSFileManager defaultManager] moveItemAtPath:partialPath toPath:path error:nil])
                cachedSize = (unsigned long long)expected;
            else {
                [[NSFileManager defaultManager] removeItemAtPath:partialPath error:nil];
                partialSize = 0;
            }
        }
        if (cachedSize != (unsigned long long)expected && !partialSize) {
            [[NSData data] writeToFile:partialPath atomically:NO];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cachedSize == (unsigned long long)expected) { finish(path, nil); return; }
            [self downloadMusicDocument:document offset:(int64_t)partialSize partialPath:partialPath finalPath:path completion:finish];
        });
    });
}
- (void)getFileForDocument:(NSDictionary *)document completion:(TGDocumentPathCompletion)completion {
    // The chunked document loader is shared with music; the caller gives the file its original extension.
    [self getMusicFileForDocument:document completion:completion];
}
- (void)downloadMusicDocument:(NSDictionary *)document offset:(int64_t)offset partialPath:(NSString *)partialPath
    finalPath:(NSString *)finalPath completion:(TGDocumentPathCompletion)completion {
    int64_t expected = [document[@"size"] longLongValue];
    NSInteger batchCount = MIN(4, (NSInteger)((expected - offset + 524287) / 524288));
    if (batchCount <= 0) { completion(nil, @"Неверный размер аудиофайла."); return; }
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:batchCount];
    for (NSInteger i = 0; i < batchCount; i++) [parts addObject:[NSNull null]];
    __block NSInteger received = 0;
    __block NSString *batchError = nil;
    for (NSInteger i = 0; i < batchCount; i++) {
        int64_t partOffset = offset + i * 524288;
        NSUInteger wanted = (NSUInteger)MIN((int64_t)524288, expected - partOffset);
        MTOutputStream *stream = [[MTOutputStream alloc] init];
        [stream writeInt32:(int32_t)0xbe5335be]; // upload.getFile
        [stream writeInt32:0];
        [stream writeInt32:(int32_t)0xbad07584]; // inputDocumentFileLocation
        [stream writeInt64:[document[@"id"] longLongValue]];
        [stream writeInt64:[document[@"access_hash"] longLongValue]];
        [stream writeBytes:document[@"file_reference"] ?: [NSData data]];
        [stream writeString:@""];
        [stream writeInt64:partOffset];
        [stream writeInt32:524288];
        [self rpc:[stream currentBytes] name:@"upload.getFile.music"
            service:[self fileServiceForDc:[document[@"dc_id"] integerValue]] completion:^(NSDictionary *result, NSString *error) {
            NSData *bytes = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
            if (error || bytes.length != wanted) batchError = error ?: @"Музыка загружена не полностью.";
            else parts[i] = bytes;
            if (++received != batchCount) return;
            if (batchError) { completion(nil, batchError); return; }
            dispatch_async(TGMediaCacheQueue(), ^{
                NSString *writeError = nil;
                @try {
                    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:partialPath];
                    if (!handle) @throw [NSException exceptionWithName:@"MusicCache" reason:@"No cache file" userInfo:nil];
                    [handle seekToFileOffset:(unsigned long long)offset];
                    for (NSData *piece in parts) [handle writeData:piece];
                    [handle closeFile];
                } @catch (__unused NSException *exception) {
                    writeError = @"Не удалось сохранить музыку на iPhone.";
                }
                int64_t nextOffset = MIN(expected, offset + batchCount * 524288);
                if (!writeError && nextOffset == expected) {
                    [[NSFileManager defaultManager] removeItemAtPath:finalPath error:nil];
                    NSError *moveError = nil;
                    if (![[NSFileManager defaultManager] moveItemAtPath:partialPath toPath:finalPath error:&moveError])
                        writeError = moveError.localizedDescription ?: @"Не удалось сохранить музыку.";
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (writeError) completion(nil, writeError);
                    else if (nextOffset == expected) completion(finalPath, nil);
                    else [self downloadMusicDocument:document offset:nextOffset partialPath:partialPath
                        finalPath:finalPath completion:completion];
                });
            });
        }];
    }
}
- (void)acceptDeviceLoginToken:(NSData *)token completion:(TGClientCompletion)completion {
    if (![token isKindOfClass:[NSData class]] || token.length < 16 || token.length > 512) {
        completion(nil, @"Неверный QR-код входа."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xe894ad4d]; // auth.acceptLoginToken
    [stream writeBytes:token];
    [self rpc:[stream currentBytes] name:@"auth.acceptLoginToken" completion:completion];
}
- (void)getDeviceSessions:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xe320c158]; // account.getAuthorizations
    [self rpc:[stream currentBytes] name:@"account.getAuthorizations" completion:completion];
}
- (void)terminateDeviceSession:(NSNumber *)hash completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xdf77f3bc]; // account.resetAuthorization
    [stream writeInt64:[hash longLongValue]];
    [self rpc:[stream currentBytes] name:@"account.resetAuthorization" completion:completion];
}
- (void)terminateOtherDeviceSessions:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x9fab0d1a]; // auth.resetAuthorizations
    [self rpc:[stream currentBytes] name:@"auth.resetAuthorizations" completion:completion];
}
- (void)confirmDeviceSession:(NSNumber *)hash completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x40f48462]; // account.changeAuthorizationSettings
    [stream writeInt32:1 << 3]; // confirmed
    [stream writeInt64:[hash longLongValue]];
    [self rpc:[stream currentBytes] name:@"account.changeAuthorizationSettings" completion:completion];
}
- (void)getBlockedPeers:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x9a868f80]; // contacts.getBlocked
    [stream writeInt32:0];
    [stream writeInt32:0];
    [stream writeInt32:100];
    [self rpc:[stream currentBytes] name:@"contacts.getBlocked" completion:completion];
}
- (void)unblockPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xb550d328]; // contacts.unblock
    [stream writeInt32:0];
    [self writePeer:peer to:stream];
    [self rpc:[stream currentBytes] name:@"contacts.unblock" completion:completion];
}
- (int32_t)notifyPeerConstructorForKind:(NSInteger)kind {
    return kind == 1 ? (int32_t)0x4a95e84e : kind == 2 ? (int32_t)0xb1db7c7e : (int32_t)0x193b4417;
}
- (void)getGlobalNotificationsForKind:(NSInteger)kind completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x12b3ad31];
    [stream writeInt32:[self notifyPeerConstructorForKind:kind]];
    [self rpc:[stream currentBytes] name:@"account.getNotifySettings" completion:completion];
}
- (void)setGlobalNotificationsEnabled:(BOOL)enabled forKind:(NSInteger)kind completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x84be5b93];
    [stream writeInt32:[self notifyPeerConstructorForKind:kind]];
    [stream writeInt32:(int32_t)0xcacb6ae2];
    [stream writeInt32:1 << 2];
    [stream writeInt32:enabled ? 0 : INT32_MAX];
    [self rpc:[stream currentBytes] name:@"account.updateNotifySettings" completion:completion];
}
- (void)uploadProfilePhotoData:(NSData *)data completion:(TGClientCompletion)completion {
    if (!data.length || data.length > 8 * 1024 * 1024) {
        completion(nil, @"Фотография слишком большая."); return;
    }
    int64_t fileId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(fileId), (uint8_t *)&fileId) != errSecSuccess) {
        completion(nil, @"Не удалось подготовить фотографию."); return;
    }
    int32_t parts = (int32_t)((data.length + 524287) / 524288);
    [self uploadProfilePhotoData:data fileId:fileId part:0 count:parts completion:completion];
}
- (void)updateProfileFirstName:(NSString *)firstName lastName:(NSString *)lastName completion:(TGClientCompletion)completion {
    if (!firstName.length) { completion(nil, @"Введите имя."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x78515775];
    [stream writeInt32:3];
    [stream writeString:firstName];
    [stream writeString:lastName ?: @""];
    [self rpc:[stream currentBytes] name:@"account.updateProfile" completion:^(NSDictionary *result, NSString *error) {
        if (!error) [self getSelfProfile:^(__unused NSDictionary *profile, __unused NSString *profileError) {
            completion(result, nil);
        }];
        else completion(nil, error);
    }];
}
- (void)uploadProfilePhotoData:(NSData *)data fileId:(int64_t)fileId part:(int32_t)part
    count:(int32_t)count completion:(TGClientCompletion)completion {
    if (part < count) {
        NSUInteger offset = (NSUInteger)part * 524288;
        NSData *chunk = [data subdataWithRange:NSMakeRange(offset, MIN((NSUInteger)524288, data.length - offset))];
        MTOutputStream *stream = [[MTOutputStream alloc] init];
        [stream writeInt32:(int32_t)0xb304a621];
        [stream writeInt64:fileId];
        [stream writeInt32:part];
        [stream writeBytes:chunk];
        [self rpc:[stream currentBytes] name:@"upload.saveFilePart.profilePhoto" completion:^(NSDictionary *result, NSString *error) {
            if (error || ![result[@"_"] isEqual:@"boolTrue"]) {
                completion(nil, error ?: @"Не удалось загрузить фотографию."); return;
            }
            [self uploadProfilePhotoData:data fileId:fileId part:part + 1 count:count completion:completion];
        }];
        return;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *checksum = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [checksum appendFormat:@"%02x", digest[i]];
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x388a3b5]; // photos.uploadProfilePhoto
    [stream writeInt32:1]; // file
    [stream writeInt32:(int32_t)0xf52ff27f]; // inputFile
    [stream writeInt64:fileId];
    [stream writeInt32:count];
    [stream writeString:@"profile.jpg"];
    [stream writeString:checksum];
    [self rpc:[stream currentBytes] name:@"photos.uploadProfilePhoto" completion:^(NSDictionary *result, NSString *error) {
        if (!error) [self getSelfProfile:^(__unused NSDictionary *profile, __unused NSString *profileError) {
            completion(result, nil);
        }];
        else completion(nil, error);
    }];
}
- (void)getDialogsForFolder:(NSInteger)folder completion:(TGClientCompletion)completion {
    [self getDialogsForFolder:folder offsetDate:0 offsetId:0 offsetPeer:nil completion:completion];
}
- (void)getDialogsForFolder:(NSInteger)folder offsetDate:(int32_t)date offsetId:(int32_t)messageId offsetPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xa0f4cb4f];
    [stream writeInt32:2]; // folder_id is present in flags.1
    [stream writeInt32:(int32_t)folder];
    [stream writeInt32:date]; [stream writeInt32:messageId];
    if (peer) [self writePeer:peer to:stream];
    else [stream writeInt32:(int32_t)0x7f3b18ea]; // inputPeerEmpty
    [stream writeInt32:50]; [stream writeInt64:0];
    if (!messageId) [self report:@"Загружаем чаты…"];
    [self rpc:[stream currentBytes] name:@"messages.getDialogs" completion:^(NSDictionary *result, NSString *error) {
        completion(result, error);
    }];
}
- (void)cacheDialogsSnapshot:(NSDictionary *)snapshot forFolder:(NSInteger)folder {
    [self writeCache:snapshot toPath:[self cachePathForFolder:folder]];
}
- (void)searchImages:(NSString *)query forPeer:(NSDictionary *)peer offset:(NSString *)offset completion:(TGClientCompletion)completion {
    if (!query.length) { completion(@{ @"results": @[] }, nil); return; }
    if (!_imageSearchBot) {
        MTOutputStream *resolve = [[MTOutputStream alloc] init];
        [resolve writeInt32:(int32_t)0x725afbbc]; // contacts.resolveUsername
        [resolve writeInt32:0];
        [resolve writeString:@"pic"];
        __weak TGClient *weakSelf = self;
        [self rpc:[resolve currentBytes] name:@"contacts.resolveUsername.pic" completion:^(NSDictionary *resolved, NSString *error) {
            TGClient *client = weakSelf;
            if (!client) return;
            NSDictionary *bot = [resolved[@"users"] firstObject];
            if (error || !bot[@"id"] || !bot[@"access_hash"]) {
                completion(nil, error ?: @"Бот @pic недоступен."); return;
            }
            client->_imageSearchBot = bot;
            [client searchImages:query forPeer:peer offset:offset completion:completion];
        }];
        return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x514e999d]; // messages.getInlineBotResults
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0xf21158c6]; // inputUser
    [stream writeInt64:[_imageSearchBot[@"id"] longLongValue]];
    [stream writeInt64:[_imageSearchBot[@"access_hash"] longLongValue]];
    [self writePeer:peer to:stream];
    [stream writeString:query];
    [stream writeString:offset ?: @""];
    [self rpc:[stream currentBytes] name:@"messages.getInlineBotResults.pic" completion:completion];
}
- (void)sendImageSearchResult:(NSDictionary *)result queryId:(NSNumber *)queryId toPeer:(NSDictionary *)peer
                       topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    if (!result[@"id"] || !queryId) { completion(nil, @"Результат поиска устарел."); return; }
    int64_t randomId = 0;
    arc4random_buf(&randomId, sizeof(randomId));
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xc0cf7646]; // messages.sendInlineBotResult
    [stream writeInt32:topicId > 1 ? 1 : 0];
    [self writePeer:peer to:stream];
    if (topicId > 1) {
        [stream writeInt32:(int32_t)0x3bd4b7c2]; // inputReplyToMessage
        [stream writeInt32:0];
        [stream writeInt32:topicId];
    }
    [stream writeInt64:randomId];
    [stream writeInt64:[queryId longLongValue]];
    [stream writeString:result[@"id"]];
    [self rpc:[stream currentBytes] name:@"messages.sendInlineBotResult.pic" completion:completion];
}
- (void)searchPeers:(NSString *)query completion:(TGClientCompletion)completion {
    if (!query.length) { completion(@{}, nil); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x05f58d0f];
    [stream writeInt32:0];
    [stream writeString:query];
    [stream writeInt32:30];
    [self rpc:[stream currentBytes] name:@"contacts.search" completion:completion];
}
- (void)getContacts:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x5dd69e12];
    [stream writeInt64:0];
    [self rpc:[stream currentBytes] name:@"contacts.getContacts" completion:^(NSDictionary *result, NSString *error) {
        if (!error && [result[@"users"] isKindOfClass:[NSArray class]])
            [self writeCache:result toPath:[[self cacheDirectory] stringByAppendingPathComponent:@"contacts.plist"]];
        completion(result, error);
    }];
}
- (NSDictionary *)cachedContacts {
    return [self readCache:[[self cacheDirectory] stringByAppendingPathComponent:@"contacts.plist"]];
}
- (void)createGroupWithTitle:(NSString *)title users:(NSArray *)users completion:(TGClientCompletion)completion {
    if (!title.length || !users.count) { completion(nil, @"Укажите название и выберите участников."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x92ceddd4]; // messages.createChat
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0x1cb5c415];
    [stream writeInt32:(int32_t)users.count];
    for (NSDictionary *user in users) {
        [stream writeInt32:(int32_t)0xf21158c6]; // inputUser
        [stream writeInt64:[user[@"user_id"] longLongValue]];
        [stream writeInt64:[user[@"access_hash"] longLongValue]];
    }
    [stream writeString:title];
    [self rpc:[stream currentBytes] name:@"messages.createChat" completion:completion];
}
- (void)createChannelWithTitle:(NSString *)title about:(NSString *)about group:(BOOL)group completion:(TGClientCompletion)completion {
    if (!title.length) { completion(nil, @"Укажите название."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x91006707]; // channels.createChannel
    [stream writeInt32:group ? 2 : 1];
    [stream writeString:title];
    [stream writeString:about ?: @""];
    [self rpc:[stream currentBytes] name:@"channels.createChannel" completion:completion];
}
- (void)inviteUsers:(NSArray *)users toChannel:(NSDictionary *)channel completion:(TGClientCompletion)completion {
    if (!users.count || !channel[@"id"] || !channel[@"access_hash"]) {
        completion(nil, @"Не удалось добавить участников: неполные данные чата."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xc9e33d54]; // channels.inviteToChannel, layer 229
    [stream writeInt32:(int32_t)0xf35aec28]; // inputChannel
    [stream writeInt64:[channel[@"id"] longLongValue]];
    [stream writeInt64:[channel[@"access_hash"] longLongValue]];
    [stream writeInt32:(int32_t)0x1cb5c415]; // vector
    [stream writeInt32:(int32_t)users.count];
    for (NSDictionary *user in users) {
        [stream writeInt32:(int32_t)0xf21158c6]; // inputUser
        [stream writeInt64:[user[@"id"] longLongValue]];
        [stream writeInt64:[user[@"access_hash"] longLongValue]];
    }
    [self rpc:[stream currentBytes] name:@"channels.inviteToChannel" completion:completion];
}
// Channel creation wizard (constructors from the bundled layer 229 schema).
- (void)writeWizardChannel:(NSDictionary *)channel stream:(MTOutputStream *)stream {
    [stream writeInt32:(int32_t)0xf35aec28];
    [stream writeInt64:[channel[@"id"] longLongValue]];
    [stream writeInt64:[channel[@"access_hash"] longLongValue]];
}
- (NSDictionary *)wizardChannelPeer:(NSDictionary *)channel {
    return @{ @"_":@"inputPeerChannel", @"channel_id":channel[@"id"] ?: @0, @"access_hash":channel[@"access_hash"] ?: @0 };
}
- (void)checkChannelUsername:(NSString *)username channel:(NSDictionary *)channel completion:(TGClientCompletion)completion {
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x10e6bd2c]; [self writeWizardChannel:channel stream:stream]; [stream writeString:username];
    [self rpc:[stream currentBytes] name:@"channels.checkUsername" completion:completion];
}
- (void)setChannelUsername:(NSString *)username channel:(NSDictionary *)channel completion:(TGClientCompletion)completion {
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x3514b3de]; [self writeWizardChannel:channel stream:stream]; [stream writeString:username ?: @""];
    [self rpc:[stream currentBytes] name:@"channels.updateUsername" completion:completion];
}
- (void)exportChannelInvite:(NSDictionary *)channel requestNeeded:(BOOL)requestNeeded completion:(TGClientCompletion)completion {
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xa455de90]; [stream writeInt32:requestNeeded ? 8 : 0];
    [self writePeer:[self wizardChannelPeer:channel] to:stream];
    [self rpc:[stream currentBytes] name:@"messages.exportChatInvite" completion:completion];
}
- (void)editChannelInvite:(NSString *)link channel:(NSDictionary *)channel requestNeeded:(BOOL)requestNeeded completion:(TGClientCompletion)completion {
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbdca2f75]; [stream writeInt32:8];
    [self writePeer:[self wizardChannelPeer:channel] to:stream]; [stream writeString:link];
    [stream writeInt32:(int32_t)(requestNeeded ? 0x997275b5 : 0xbc799737)];
    [self rpc:[stream currentBytes] name:@"messages.editExportedChatInvite" completion:^(NSDictionary *result,NSString *error) { completion(result[@"invite"],error); }];
}
- (void)resetChannelInvite:(NSString *)link channel:(NSDictionary *)channel requestNeeded:(BOOL)requestNeeded completion:(TGClientCompletion)completion {
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbdca2f75]; [stream writeInt32:4];
    [self writePeer:[self wizardChannelPeer:channel] to:stream]; [stream writeString:link];
    [self rpc:[stream currentBytes] name:@"messages.editExportedChatInvite.revoke" completion:^(NSDictionary *result,NSString *error) {
        if (error) { completion(nil,error); return; }
        [self exportChannelInvite:channel requestNeeded:requestNeeded completion:^(NSDictionary *invite,NSString *inviteError) { completion(invite ?: @{ @"revoked":@YES },inviteError); }];
    }];
}
- (void)setChannelProtection:(BOOL)enabled channel:(NSDictionary *)channel completion:(TGClientCompletion)completion {
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xb2081a35]; [stream writeInt32:0];
    [self writePeer:[self wizardChannelPeer:channel] to:stream]; [stream writeInt32:(int32_t)(enabled ? 0x997275b5 : 0xbc799737)];
    [self rpc:[stream currentBytes] name:@"messages.toggleNoForwards" completion:completion];
}
- (void)updateChannel:(NSDictionary *)channel title:(NSString *)title about:(NSString *)about completion:(TGClientCompletion)completion {
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x566decd0]; [self writeWizardChannel:channel stream:stream]; [stream writeString:title];
    [self rpc:[stream currentBytes] name:@"channels.editTitle" completion:^(NSDictionary *result, NSString *error) {
        if (error && !([error rangeOfString:@"CHAT_NOT_MODIFIED"].location!=NSNotFound)) { completion(nil,error); return; }
        MTOutputStream *description=[[MTOutputStream alloc] init];
        [description writeInt32:(int32_t)0xdef60797]; [self writePeer:[self wizardChannelPeer:channel] to:description]; [description writeString:about ?: @""];
        [self rpc:[description currentBytes] name:@"messages.editChatAbout" completion:^(NSDictionary *updated,NSString *aboutError) {
            if (aboutError && ([aboutError rangeOfString:@"CHAT_ABOUT_NOT_MODIFIED"].location!=NSNotFound || [aboutError rangeOfString:@"CHAT_NOT_MODIFIED"].location!=NSNotFound)) completion(@{ @"_":@"boolTrue" },nil);
            else completion(updated,aboutError);
        }];
    }];
}
- (void)setChannelPhoto:(NSData *)data channel:(NSDictionary *)channel completion:(TGClientCompletion)completion {
    if (!data.length || data.length>8*1024*1024) { completion(nil,@"Фотография слишком большая."); return; }
    int64_t fileId=0;
    if (SecRandomCopyBytes(kSecRandomDefault,sizeof(fileId),(uint8_t *)&fileId)!=errSecSuccess) { completion(nil,@"Не удалось подготовить фото."); return; }
    [self uploadWizardPhoto:data channel:channel fileId:fileId part:0 completion:completion];
}
- (void)uploadWizardPhoto:(NSData *)data channel:(NSDictionary *)channel fileId:(int64_t)fileId part:(int32_t)part completion:(TGClientCompletion)completion {
    int32_t count=(int32_t)((data.length+524287)/524288);
    MTOutputStream *stream=[[MTOutputStream alloc] init];
    if (part<count) {
        NSUInteger offset=(NSUInteger)part*524288;
        [stream writeInt32:(int32_t)0xb304a621]; [stream writeInt64:fileId]; [stream writeInt32:part];
        [stream writeBytes:[data subdataWithRange:NSMakeRange(offset,MIN((NSUInteger)524288,data.length-offset))]];
        [self rpc:[stream currentBytes] name:@"upload.saveFilePart.channelPhoto" completion:^(NSDictionary *result,NSString *error) {
            if (error || ![result[@"_"] isEqual:@"boolTrue"]) { completion(nil,error ?: @"Ошибка загрузки фото."); return; }
            [self uploadWizardPhoto:data channel:channel fileId:fileId part:part+1 completion:completion];
        }]; return;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH]; CC_MD5(data.bytes,(CC_LONG)data.length,digest);
    NSMutableString *checksum=[NSMutableString string]; for(int i=0;i<CC_MD5_DIGEST_LENGTH;i++) [checksum appendFormat:@"%02x",digest[i]];
    [stream writeInt32:(int32_t)0xf12e57c9]; [self writeWizardChannel:channel stream:stream];
    [stream writeInt32:(int32_t)0xbdcdaec0]; [stream writeInt32:1]; // inputChatUploadedPhoto.file
    [stream writeInt32:(int32_t)0xf52ff27f]; [stream writeInt64:fileId]; [stream writeInt32:count];
    [stream writeString:@"channel.jpg"]; [stream writeString:checksum];
    [self rpc:[stream currentBytes] name:@"channels.editPhoto" completion:completion];
}
- (void)getCustomEmojiDocuments:(NSArray *)documentIds completion:(TGClientCompletion)completion {
    if (!documentIds.count) { completion(@{ @"items": @[] }, nil); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xd9ab0f54]; // messages.getCustomEmojiDocuments
    [stream writeInt32:(int32_t)0x1cb5c415];
    [stream writeInt32:(int32_t)documentIds.count];
    for (NSNumber *identifier in documentIds) [stream writeInt64:identifier.longLongValue];
    [self rpc:[stream currentBytes] name:@"messages.getCustomEmojiDocuments" completion:completion];
}
- (NSDictionary *)cachedRecentStickers { return [self readCache:[[self cacheDirectory] stringByAppendingPathComponent:@"stickers-recent.plist"]]; }
- (NSDictionary *)cachedInstalledStickerSets { return [self readCache:[[self cacheDirectory] stringByAppendingPathComponent:@"stickers-sets.plist"]]; }
- (NSDictionary *)cachedStickerSet:(NSDictionary *)set { return [self readCache:[[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"sticker-set-%@.plist", set[@"id"]]]]; }
- (void)getRecentStickers:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x9da9403b];
    [stream writeInt32:0];
    [stream writeInt64:0];
    [self rpc:[stream currentBytes] name:@"messages.getRecentStickers" completion:^(NSDictionary *result, NSString *error) {
        if (!error && [result[@"stickers"] isKindOfClass:[NSArray class]]) [self writeCache:result toPath:[[self cacheDirectory] stringByAppendingPathComponent:@"stickers-recent.plist"]];
        completion(result, error);
    }];
}
- (void)getInstalledStickerSets:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xb8a0a1a8];
    [stream writeInt64:0];
    [self rpc:[stream currentBytes] name:@"messages.getAllStickers" completion:^(NSDictionary *result, NSString *error) {
        if (!error && [result[@"sets"] isKindOfClass:[NSArray class]]) [self writeCache:result toPath:[[self cacheDirectory] stringByAppendingPathComponent:@"stickers-sets.plist"]];
        completion(result, error);
    }];
}
- (void)getStickerSet:(NSDictionary *)set completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xc8a0ec74];
    [stream writeInt32:(int32_t)0x9de7a269];
    [stream writeInt64:[set[@"id"] longLongValue]];
    [stream writeInt64:[set[@"access_hash"] longLongValue]];
    [stream writeInt32:0];
    [self rpc:[stream currentBytes] name:@"messages.getStickerSet" completion:^(NSDictionary *result, NSString *error) {
        if (!error && [result[@"documents"] isKindOfClass:[NSArray class]]) [self writeCache:result toPath:[[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"sticker-set-%@.plist", set[@"id"]]]];
        completion(result, error);
    }];
}
- (void)sendStickerDocument:(NSDictionary *)document toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    if (!document[@"id"] || !document[@"access_hash"]) { completion(nil, @"Стикер недоступен."); return; }
    int64_t randomId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomId), (uint8_t *)&randomId) != errSecSuccess) {
        completion(nil, @"Нет случайного идентификатора сообщения."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x0330e77f]; // messages.sendMedia
    [stream writeInt32:topicId > 1 ? 1 : 0];
    [self writePeer:peer to:stream];
    if (topicId > 1) {
        [stream writeInt32:(int32_t)0x3bd4b7c2]; // inputReplyToMessage
        [stream writeInt32:0];
        [stream writeInt32:topicId];
    }
    [stream writeInt32:(int32_t)0xa8763ab5]; // inputMediaDocument
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0x1abfb575]; // inputDocument
    [stream writeInt64:[document[@"id"] longLongValue]];
    [stream writeInt64:[document[@"access_hash"] longLongValue]];
    [stream writeBytes:document[@"file_reference"] ?: [NSData data]];
    [stream writeString:@""];
    [stream writeInt64:randomId];
    [self rpc:[stream currentBytes] name:@"messages.sendMedia.sticker" completion:completion];
}
- (void)writePeer:(NSDictionary *)peer to:(MTOutputStream *)stream {
    NSString *type = peer[@"_"];
    if ([type isEqual:@"inputPeerSelf"]) {
        [stream writeInt32:(int32_t)0x7da07ec9];
    } else if ([type isEqual:@"inputPeerUser"]) {
        [stream writeInt32:(int32_t)0xdde8a54c];
        [stream writeInt64:[peer[@"user_id"] longLongValue]];
        [stream writeInt64:[peer[@"access_hash"] longLongValue]];
    } else if ([type isEqual:@"inputPeerChat"]) {
        [stream writeInt32:(int32_t)0x35a95cb9];
        [stream writeInt64:[peer[@"chat_id"] longLongValue]];
    } else if ([type isEqual:@"inputPeerChannel"]) {
        [stream writeInt32:(int32_t)0x27bcbbfc];
        [stream writeInt64:[peer[@"channel_id"] longLongValue]];
        [stream writeInt64:[peer[@"access_hash"] longLongValue]];
    }
}
- (void)getHistoryForPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion {
    [self getHistoryForPeer:inputPeer limit:50 completion:completion];
}
- (void)getPeerDialog:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion {
    MTOutputStream *request = [[MTOutputStream alloc] init];
    [request writeInt32:(int32_t)0xe470bcfd]; // messages.getPeerDialogs
    [request writeInt32:(int32_t)0x1cb5c415]; // vector
    [request writeInt32:1];
    [request writeInt32:(int32_t)0xfcaafeb7]; // inputDialogPeer
    [self writePeer:inputPeer to:request];
    [self rpc:[request currentBytes] name:@"messages.getPeerDialogs" completion:completion];
}
- (void)getLatestMessageForPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion {
    [self getHistoryForPeer:inputPeer limit:1 completion:completion];
}
- (void)markReadThroughMessage:(int32_t)messageId inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    if (messageId <= 0) { completion(nil, nil); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    BOOL channel = [peer[@"_"] isEqual:@"inputPeerChannel"];
    [stream writeInt32:channel ? (int32_t)0xcc104937 : (int32_t)0xe306d3a];
    if (channel) {
        [stream writeInt32:(int32_t)0xf35aec28];
        [stream writeInt64:[peer[@"channel_id"] longLongValue]];
        [stream writeInt64:[peer[@"access_hash"] longLongValue]];
    } else [self writePeer:peer to:stream];
    [stream writeInt32:messageId];
    [self rpc:[stream currentBytes] name:channel ? @"channels.readHistory" : @"messages.readHistory" completion:completion];
}
- (void)getHistoryForPeer:(NSDictionary *)inputPeer limit:(int32_t)limit completion:(TGClientCompletion)completion {
    [self getHistoryForPeer:inputPeer beforeMessageId:0 limit:limit completion:completion];
}
- (void)getHistoryForPeer:(NSDictionary *)inputPeer beforeMessageId:(int32_t)messageId limit:(int32_t)limit completion:(TGClientCompletion)completion {
    [self getHistoryForPeer:inputPeer beforeMessageId:messageId limit:limit cacheResult:limit > 1 completion:completion];
}
- (void)getHistoryForPeer:(NSDictionary *)inputPeer beforeMessageId:(int32_t)messageId limit:(int32_t)limit cacheResult:(BOOL)cacheResult completion:(TGClientCompletion)completion {
    MTOutputStream *request = [[MTOutputStream alloc] init];
    [request writeInt32:(int32_t)0x4423e6c5];
    [self writePeer:inputPeer to:request];
    [request writeInt32:messageId]; [request writeInt32:0]; [request writeInt32:0];
    [request writeInt32:limit]; [request writeInt32:0]; [request writeInt32:0]; [request writeInt64:0];
    [self rpc:[request currentBytes] name:@"messages.getHistory" completion:^(NSDictionary *result, NSString *error) {
        if (!error && cacheResult) [self mergeHistoryCache:result toPath:[self cachePathForPeer:inputPeer]];
        completion(result, error);
    }];
}
- (NSDictionary *)cachedHistoryForPeer:(NSDictionary *)inputPeer { return [self readCache:[self cachePathForPeer:inputPeer]]; }
- (NSString *)cachePathForTopic:(NSDictionary *)peer topicId:(int32_t)topicId {
    return [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"topic-%@-%d.plist", peer[@"channel_id"] ?: @0, topicId]];
}
- (NSDictionary *)cachedTopicHistoryForPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId {
    return [self readCache:[self cachePathForTopic:inputPeer topicId:topicId]];
}
- (void)getForumTopicsForPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x3ba47bff];
    [stream writeInt32:0];
    [self writePeer:inputPeer to:stream];
    [stream writeInt32:0]; [stream writeInt32:0]; [stream writeInt32:0];
    [stream writeInt32:100];
    [self rpc:[stream currentBytes] name:@"messages.getForumTopics" completion:^(NSDictionary *result, NSString *error) {
        if (!error) [self writeCache:result toPath:[self cachePathForTopic:inputPeer topicId:0]];
        completion(result, error);
    }];
}
- (NSDictionary *)cachedForumTopicsForPeer:(NSDictionary *)inputPeer {
    return [self readCache:[self cachePathForTopic:inputPeer topicId:0]];
}
- (void)getReactionAuthorsForPeer:(NSDictionary *)inputPeer messageId:(int32_t)messageId completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x461b3f48];
    [stream writeInt32:0];
    [self writePeer:inputPeer to:stream];
    [stream writeInt32:messageId];
    [stream writeInt32:50];
    [self rpc:[stream currentBytes] name:@"messages.getMessageReactionsList" completion:completion];
}
- (void)getJoinedCommunities:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xa663e830];
    [self rpc:[stream currentBytes] name:@"communities.getJoinedCommunities" completion:completion];
}
- (void)getFullCommunity:(NSDictionary *)community completion:(TGClientCompletion)completion {
    if (!community[@"id"] || !community[@"access_hash"]) { completion(nil, @"Сообщество недоступно."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x08736a09];
    [stream writeInt32:(int32_t)0xf35aec28];
    [stream writeInt64:[community[@"id"] longLongValue]];
    [stream writeInt64:[community[@"access_hash"] longLongValue]];
    [self rpc:[stream currentBytes] name:@"channels.getFullChannel.community" completion:^(NSDictionary *result, NSString *error) {
        if (!error) [self writeCache:result toPath:[self cachePathForCommunity:community[@"id"]]];
        completion(result, error);
    }];
}
- (NSString *)cachePathForCommunity:(NSNumber *)communityId {
    return [[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"community-%@.plist", communityId ?: @0]];
}
- (NSDictionary *)cachedCommunity:(NSNumber *)communityId { return [self readCache:[self cachePathForCommunity:communityId]]; }
- (void)setCommunity:(NSDictionary *)community collapsed:(BOOL)collapsed completion:(TGClientCompletion)completion {
    if (!community[@"id"] || !community[@"access_hash"]) { completion(nil, @"Сообщество недоступно."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xd766e3ea];
    [stream writeInt32:collapsed ? 1 : 0];
    [stream writeInt32:(int32_t)0xf35aec28];
    [stream writeInt64:[community[@"id"] longLongValue]];
    [stream writeInt64:[community[@"access_hash"] longLongValue]];
    [self rpc:[stream currentBytes] name:@"communities.toggleCommunityCollapsedInDialogs" completion:completion];
}
- (void)joinChannel:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion {
    if (![inputPeer[@"_"] isEqual:@"inputPeerChannel"]) { completion(nil, @"Вступление в этот чат пока недоступно."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x7f6a1e22];
    [stream writeInt32:(int32_t)0xf35aec28];
    [stream writeInt64:[inputPeer[@"channel_id"] longLongValue]];
    [stream writeInt64:[inputPeer[@"access_hash"] longLongValue]];
    [self rpc:[stream currentBytes] name:@"channels.joinChannel" completion:completion];
}
- (void)getTopicHistoryForPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId limit:(int32_t)limit completion:(TGClientCompletion)completion {
    [self getTopicHistoryForPeer:inputPeer topicId:topicId beforeMessageId:0 limit:limit completion:completion];
}
- (void)getTopicHistoryForPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId beforeMessageId:(int32_t)messageId limit:(int32_t)limit completion:(TGClientCompletion)completion {
    if (topicId == 1) {
        [self getHistoryForPeer:inputPeer beforeMessageId:messageId limit:100 cacheResult:limit > 1
            completion:^(NSDictionary *result, NSString *error) {
            if (error) { completion(nil, error); return; }
            NSMutableArray *general = [NSMutableArray array];
            for (NSDictionary *message in result[@"messages"]) {
                if (message[@"reply_to"][@"reply_to_top_id"] ||
                    [message[@"action"][@"_"] isEqual:@"messageActionTopicCreate"]) continue;
                [general addObject:message];
                if (limit == 1) break;
            }
            NSMutableDictionary *filtered = [result mutableCopy];
            filtered[@"messages"] = general;
            if (limit > 1) [self mergeHistoryCache:filtered toPath:[self cachePathForTopic:inputPeer topicId:1]];
            completion(filtered, nil);
        }];
        return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x22ddd30c];
    [self writePeer:inputPeer to:stream];
    [stream writeInt32:topicId];
    [stream writeInt32:messageId]; [stream writeInt32:0]; [stream writeInt32:0];
    [stream writeInt32:limit]; [stream writeInt32:0]; [stream writeInt32:0]; [stream writeInt64:0];
    [self rpc:[stream currentBytes] name:@"messages.getReplies" completion:^(NSDictionary *result, NSString *error) {
        if (!error && limit > 1) [self mergeHistoryCache:result toPath:[self cachePathForTopic:inputPeer topicId:topicId]];
        completion(result, error);
    }];
}
- (NSString *)avatarPathForPhoto:(NSDictionary *)photo {
    return [[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"avatar-hi-%@.jpg", photo[@"photo_id"] ?: @0]];
}
- (NSData *)cachedAvatarForPhoto:(NSDictionary *)photo {
    NSString *path = [self avatarPathForPhoto:photo];
    return [NSData dataWithContentsOfFile:path];
}
- (void)finishAvatar:(NSNumber *)photoId data:(NSData *)data error:(NSString *)error {
    NSArray *waiters = [_avatarWaiters[photoId] copy];
    [_avatarWaiters removeObjectForKey:photoId];
    for (TGAvatarCompletion waiter in waiters) waiter(data, error);
}
- (MTRequestMessageService *)fileServiceForDc:(NSInteger)dc {
    if (dc < 1 || dc > 5) dc = _dc;
    if (dc == _dc) return _service;
    MTRequestMessageService *service = _mediaServices[@(dc)];
    if (!service) {
        MTProto *proto = [[MTProto alloc] initWithContext:_context datacenterId:dc usageCalculationInfo:nil
                                   requiredAuthToken:@1 authTokenMasterDatacenterId:_dc];
        proto.useUnauthorizedMode = false;
        service = [[MTRequestMessageService alloc] initWithContext:_context];
        [proto addMessageService:service];
        _mediaProtos[@(dc)] = proto;
        _mediaServices[@(dc)] = service;
        [proto resume];
    }
    return service;
}
- (void)getAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo completion:(TGAvatarCompletion)completion {
    NSNumber *photoId = photo[@"photo_id"];
    if (!photoId) { completion(nil, @"Нет фотографии."); return; }
    if (_avatarWaiters[photoId]) { [_avatarWaiters[photoId] addObject:[completion copy]]; return; }
    _avatarWaiters[photoId] = [NSMutableArray arrayWithObject:[completion copy]];
    dispatch_async(TGMediaCacheQueue(), ^{
        NSData *cached = [self cachedAvatarForPhoto:photo];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self->_avatarWaiters[photoId]) return;
            if (cached.length) [self finishAvatar:photoId data:cached error:nil];
            else [self downloadAvatarForPeer:peer photo:photo photoId:photoId];
        });
    });
}
- (void)getFullAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo completion:(TGAvatarCompletion)completion {
    if (!photo[@"photo_id"] || !peer) { completion(nil, @"Нет фотографии."); return; }
    NSString *path = [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"avatar-full-%@.jpg", photo[@"photo_id"]]];
    dispatch_async(TGMediaCacheQueue(), ^{
        NSData *cached = [NSData dataWithContentsOfFile:path];
        if (cached.length) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(cached, nil); });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            MTOutputStream *stream = [[MTOutputStream alloc] init];
            [stream writeInt32:(int32_t)0xbe5335be];
            [stream writeInt32:0];
            [stream writeInt32:(int32_t)0x37257e99];
            [stream writeInt32:1];
            [self writePeer:peer to:stream];
            [stream writeInt64:[photo[@"photo_id"] longLongValue]];
            [stream writeInt64:0];
            [stream writeInt32:1048576];
            [self rpc:[stream currentBytes] name:@"upload.getFile.fullAvatar"
                service:[self fileServiceForDc:[photo[@"dc_id"] integerValue]] completion:^(NSDictionary *result, NSString *error) {
                NSData *bytes = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
                dispatch_async(TGMediaCacheQueue(), ^{
                    BOOL valid = TGMediaDataIsDecodable(bytes);
                    if (valid && ![bytes writeToFile:path atomically:YES]) NSLog(@"Telegram media: cannot cache full avatar");
                    dispatch_async(dispatch_get_main_queue(), ^{ completion(valid ? bytes : nil, error ?: (valid ? nil : @"Фото недоступно.")); });
                });
            }];
        });
    });
}
- (void)downloadAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo photoId:(NSNumber *)photoId {
    [self downloadAvatarForPeer:peer photo:photo photoId:photoId big:NO];
}
- (void)downloadAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo photoId:(NSNumber *)photoId big:(BOOL)big {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbe5335be]; // upload.getFile
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0x37257e99]; // inputPeerPhotoFileLocation
    [stream writeInt32:big ? 1 : 0]; // small avatar first: quick and sufficient for list rows
    [self writePeer:peer to:stream];
    [stream writeInt64:[photo[@"photo_id"] longLongValue]];
    [stream writeInt64:0]; // offset
    [stream writeInt32:524288]; // complete small avatar in one part
    MTRequestMessageService *service = [self fileServiceForDc:[photo[@"dc_id"] integerValue]];
    [self rpc:[stream currentBytes] name:@"upload.getFile" service:service completion:^(NSDictionary *result, NSString *error) {
        NSData *bytes = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
        if (!error && bytes.length) {
            NSString *path = [self avatarPathForPhoto:photo];
            dispatch_async(TGMediaCacheQueue(), ^{
                if (!TGMediaDataIsDecodable(bytes)) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!big) [self downloadAvatarForPeer:peer photo:photo photoId:photoId big:YES];
                        else [self finishAvatar:photoId data:nil error:@"Аватар не декодируется."];
                    });
                    return;
                }
                if (![bytes writeToFile:path atomically:YES]) NSLog(@"Telegram media: cannot cache avatar");
                [[NSFileManager defaultManager] setAttributes:@{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication }
                                                     ofItemAtPath:path error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ [self finishAvatar:photoId data:bytes error:nil]; });
            });
        } else if (!big) [self downloadAvatarForPeer:peer photo:photo photoId:photoId big:YES];
        else {
            NSString *reason = error ?: result[@"_"] ?: @"Не удалось загрузить аватар.";
            NSLog(@"Telegram media: avatar download failed (%@)", reason);
            [self finishAvatar:photoId data:nil error:reason];
        }
    }];
}
- (NSDictionary *)messagePhotoSize:(NSDictionary *)photo {
    NSDictionary *larger = nil, *smaller = nil;
    NSInteger largerPixels = NSIntegerMax, smallerPixels = 0;
    for (NSDictionary *size in photo[@"sizes"]) {
        NSString *kind = size[@"_"];
        if (![kind isEqual:@"photoSize"] && ![kind isEqual:@"photoCachedSize"] && ![kind isEqual:@"photoSizeProgressive"]) continue;
        NSInteger pixels = MAX([size[@"w"] integerValue], [size[@"h"] integerValue]);
        NSInteger fileSize = [size[@"size"] integerValue];
        if ([kind isEqual:@"photoSizeProgressive"]) fileSize = [[size[@"sizes"] lastObject] integerValue];
        if (fileSize > 524288) continue;
        if (pixels >= 480 && pixels < largerPixels) { larger = size; largerPixels = pixels; }
        else if (pixels < 480 && pixels > smallerPixels) { smaller = size; smallerPixels = pixels; }
    }
    if (larger ?: smaller) return larger ?: smaller;
    NSDictionary *best = nil;
    NSInteger bestPixels = NSIntegerMax;
    for (NSDictionary *size in photo[@"sizes"]) {
        NSString *kind = size[@"_"];
        if (![kind isEqual:@"photoSize"] && ![kind isEqual:@"photoCachedSize"]) continue;
        if ([size[@"size"] integerValue] > 524288) continue;
        NSInteger pixels = MAX([size[@"w"] integerValue], [size[@"h"] integerValue]);
        if (!best || pixels < bestPixels) { best = size; bestPixels = pixels; }
    }
    return best;
}
- (NSString *)messagePhotoPath:(NSDictionary *)photo {
    return [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"media-%@.jpg", photo[@"id"] ?: @0]];
}
- (NSData *)cachedMessagePhoto:(NSDictionary *)photo {
    NSDictionary *size = [self messagePhotoSize:photo];
    if ([size[@"bytes"] isKindOfClass:[NSData class]] && [size[@"bytes"] length]) return size[@"bytes"];
    NSString *path = [self messagePhotoPath:photo];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data.length) {
        for (NSDictionary *candidate in photo[@"sizes"]) {
            NSString *type = candidate[@"type"];
            if (![type isKindOfClass:[NSString class]]) continue;
            NSString *legacy = [[self cacheDirectory] stringByAppendingPathComponent:
                [NSString stringWithFormat:@"media-%@-%@.jpg", photo[@"id"], type]];
            data = [NSData dataWithContentsOfFile:legacy];
            if (data.length) { [data writeToFile:path atomically:YES]; break; }
        }
    }
    if (!data.length) return nil;
    return data;
}
- (void)getMessagePhoto:(NSDictionary *)photo completion:(TGAvatarCompletion)completion {
    NSDictionary *size = [self messagePhotoSize:photo];
    if (!photo[@"id"] || !photo[@"access_hash"] || !size[@"type"]) { completion(nil, @"Фото недоступно."); return; }
    dispatch_async(TGMediaCacheQueue(), ^{
        NSData *cached = [self cachedMessagePhoto:photo];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cached.length) completion(cached, nil);
            else [self downloadMessagePhoto:photo size:size completion:completion];
        });
    });
}
- (void)getFullMessagePhoto:(NSDictionary *)photo completion:(TGAvatarCompletion)completion {
    NSDictionary *best = nil;
    NSInteger bestPixels = 0;
    for (NSDictionary *candidate in photo[@"sizes"]) {
        NSString *type = candidate[@"_"];
        if (![type isEqual:@"photoSize"] && ![type isEqual:@"photoSizeProgressive"] &&
            ![type isEqual:@"photoCachedSize"]) continue;
        NSInteger pixels = MAX([candidate[@"w"] integerValue], [candidate[@"h"] integerValue]);
        NSInteger fileSize = [candidate[@"size"] integerValue];
        if ([type isEqual:@"photoSizeProgressive"])
            fileSize = [[candidate[@"sizes"] lastObject] integerValue];
        if (pixels > bestPixels && pixels <= 2560 && fileSize <= 5 * 1024 * 1024 && candidate[@"type"]) {
            best = candidate; bestPixels = pixels;
        }
    }
    if (!best || !photo[@"id"] || !photo[@"access_hash"]) {
        [self getMessagePhoto:photo completion:completion]; return;
    }
    NSString *path = [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"media-full-%@-%@.jpg", photo[@"id"], best[@"type"]]];
    dispatch_async(TGMediaCacheQueue(), ^{
        NSData *cached = [NSData dataWithContentsOfFile:path];
        BOOL valid = cached.length && TGMediaDataIsDecodable(cached);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (valid) completion(cached, nil);
            else [self downloadFullMessagePhoto:photo size:best offset:0 accumulated:[NSMutableData data]
                path:path completion:completion];
        });
    });
}
- (void)downloadFullMessagePhoto:(NSDictionary *)photo size:(NSDictionary *)size offset:(NSUInteger)offset
                      accumulated:(NSMutableData *)accumulated path:(NSString *)path
                       completion:(TGAvatarCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbe5335be]; // upload.getFile
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0x40181ffe]; // inputPhotoFileLocation
    [stream writeInt64:[photo[@"id"] longLongValue]];
    [stream writeInt64:[photo[@"access_hash"] longLongValue]];
    [stream writeBytes:photo[@"file_reference"] ?: [NSData data]];
    [stream writeString:size[@"type"]];
    [stream writeInt64:(int64_t)offset];
    [stream writeInt32:524288];
    MTRequestMessageService *service = [self fileServiceForDc:[photo[@"dc_id"] integerValue]];
    [self rpc:[stream currentBytes] name:@"upload.getFile.fullPhoto" service:service
        completion:^(NSDictionary *result, NSString *error) {
            NSData *part = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
            if (error || !part.length || accumulated.length + part.length > 5 * 1024 * 1024) {
                [self getMessagePhoto:photo completion:completion]; return;
            }
            [accumulated appendData:part];
            NSInteger expected = [size[@"size"] integerValue];
            if ([size[@"_"] isEqual:@"photoSizeProgressive"])
                expected = [[size[@"sizes"] lastObject] integerValue];
            if (part.length == 524288 && (expected <= 0 || accumulated.length < (NSUInteger)expected)) {
                [self downloadFullMessagePhoto:photo size:size offset:offset + part.length
                    accumulated:accumulated path:path completion:completion];
                return;
            }
            NSData *finished = [accumulated copy];
            dispatch_async(TGMediaCacheQueue(), ^{
                BOOL valid = TGMediaDataIsDecodable(finished);
                if (valid) [finished writeToFile:path atomically:YES];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (valid) completion(finished, nil);
                    else [self getMessagePhoto:photo completion:completion];
                });
            });
        }];
}
- (void)downloadMessagePhoto:(NSDictionary *)photo size:(NSDictionary *)size completion:(TGAvatarCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbe5335be]; // upload.getFile
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0x40181ffe]; // inputPhotoFileLocation
    [stream writeInt64:[photo[@"id"] longLongValue]];
    [stream writeInt64:[photo[@"access_hash"] longLongValue]];
    [stream writeBytes:photo[@"file_reference"] ?: [NSData data]];
    [stream writeString:size[@"type"]];
    [stream writeInt64:0];
    [stream writeInt32:524288];
    MTRequestMessageService *service = [self fileServiceForDc:[photo[@"dc_id"] integerValue]];
    [self rpc:[stream currentBytes] name:@"upload.getFile.photo" service:service completion:^(NSDictionary *result, NSString *error) {
        NSData *bytes = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
        NSString *path = [self messagePhotoPath:photo];
        dispatch_async(TGMediaCacheQueue(), ^{
            if (error || !TGMediaDataIsDecodable(bytes)) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSDictionary *fallback = nil;
                    NSInteger currentPixels = MAX([size[@"w"] integerValue], [size[@"h"] integerValue]);
                    NSInteger bestPixels = 0;
                    for (NSDictionary *candidate in photo[@"sizes"]) {
                        if (![candidate[@"type"] isKindOfClass:[NSString class]] || [candidate[@"type"] isEqual:size[@"type"]]) continue;
                        NSInteger pixels = MAX([candidate[@"w"] integerValue], [candidate[@"h"] integerValue]);
                        if (pixels < currentPixels && pixels > bestPixels && [candidate[@"size"] integerValue] <= 524288) {
                            fallback = candidate; bestPixels = pixels;
                        }
                    }
                    if (fallback) [self downloadMessagePhoto:photo size:fallback completion:completion];
                    else {
                        NSString *reason = error ?: result[@"_"] ?: @"Фото не загрузилось.";
                        NSLog(@"Telegram media: message photo download failed (%@)", reason);
                        completion(nil, reason);
                    }
                });
                return;
            }
            if (![bytes writeToFile:path atomically:YES]) NSLog(@"Telegram media: cannot cache message photo");
            [[NSFileManager defaultManager] setAttributes:@{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication }
                                                 ofItemAtPath:path error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(bytes, nil); });
        });
    }];
}
- (NSString *)voicePathForDocument:(NSDictionary *)document {
    return [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"voice-%@.ogg", document[@"id"] ?: @0]];
}
- (NSString *)stickerPathForDocument:(NSDictionary *)document thumbSize:(NSString *)thumbSize {
    return [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"sticker-%@-%@.bin", document[@"id"] ?: @0, thumbSize.length ? thumbSize : @"full"]];
}
- (void)getStickerDataForDocument:(NSDictionary *)document completion:(TGAvatarCompletion)completion {
    if (!document[@"id"] || !document[@"access_hash"] || !document[@"dc_id"]) {
        completion(nil, @"Стикер недоступен."); return;
    }
    BOOL staticSticker = [document[@"mime_type"] isEqual:@"image/webp"];
    NSString *thumbSize = @"";
    NSData *stripped = nil;
    NSData *cachedThumb = nil;
    if (!staticSticker) {
        NSDictionary *best = nil;
        NSInteger bestPixels = 0;
        for (NSDictionary *thumb in document[@"thumbs"]) {
            if ([thumb[@"_"] isEqual:@"photoCachedSize"] && [thumb[@"bytes"] isKindOfClass:[NSData class]] &&
                [thumb[@"bytes"] length]) cachedThumb = thumb[@"bytes"];
            if ([thumb[@"_"] isEqual:@"photoStrippedSize"] && [thumb[@"bytes"] isKindOfClass:[NSData class]])
                stripped = TGInflateStrippedThumbnail(thumb[@"bytes"]);
            if (![thumb[@"_"] isEqual:@"photoSize"] || ![thumb[@"type"] isKindOfClass:[NSString class]]) continue;
            NSInteger pixels = MAX([thumb[@"w"] integerValue], [thumb[@"h"] integerValue]);
            if (pixels > bestPixels) { best = thumb; bestPixels = pixels; }
        }
        thumbSize = best[@"type"];
        if (!thumbSize.length) {
            NSData *fallback = cachedThumb ?: stripped;
            completion(fallback, fallback ? nil : @"У медиа нет превью."); return;
        }
    }
    NSString *path = [self stickerPathForDocument:document thumbSize:thumbSize];
    dispatch_async(TGMediaCacheQueue(), ^{
        NSData *cached = [NSData dataWithContentsOfFile:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cached.length) completion(cached, nil);
            else [self downloadStickerDocument:document thumbSize:thumbSize offset:0
                data:[NSMutableData data] completion:^(NSData *data, NSString *error) {
                    if (!data.length && (cachedThumb.length || stripped.length)) completion(cachedThumb ?: stripped, nil);
                    else completion(data, error);
                }];
        });
    });
}
- (void)getAnimatedStickerDataForDocument:(NSDictionary *)document completion:(TGAvatarCompletion)completion {
    BOOL supported = [document[@"mime_type"] isEqual:@"application/x-tgsticker"] || [document[@"mime_type"] isEqual:@"video/webm"];
    if (!supported ||
        !document[@"id"] || !document[@"access_hash"] || !document[@"dc_id"] ||
        [document[@"size"] longLongValue] > 512 * 1024) {
        completion(nil, @"Анимированный стикер недоступен."); return;
    }
    NSString *path = [self stickerPathForDocument:document thumbSize:@""];
    dispatch_async(TGMediaCacheQueue(), ^{
        NSData *cached = [NSData dataWithContentsOfFile:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cached.length) completion(cached, nil);
            else [self downloadStickerDocument:document thumbSize:@"" offset:0
                data:[NSMutableData data] completion:completion];
        });
    });
}
- (NSString *)roundVideoPathForDocument:(NSDictionary *)document {
    return [[self cacheDirectory] stringByAppendingPathComponent:
        [NSString stringWithFormat:@"round-%@.mp4", document[@"id"] ?: @0]];
}
- (NSString *)cachedRoundVideoPathForDocument:(NSDictionary *)document {
    if (!document[@"id"]) return nil;
    NSString *path = [self roundVideoPathForDocument:document];
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ? path : nil;
}
- (void)getRoundVideoForDocument:(NSDictionary *)document completion:(TGDocumentPathCompletion)completion {
    if (!document[@"id"] || !document[@"access_hash"] || !document[@"dc_id"] ||
        [document[@"size"] longLongValue] > 20 * 1024 * 1024) {
        completion(nil, @"Кружок недоступен или слишком большой."); return;
    }
    NSString *path = [self cachedRoundVideoPathForDocument:document];
    if (path) { completion(path, nil); return; }
    NSNumber *identifier = document[@"id"];
    NSMutableArray *waiters = _roundVideoWaiters[identifier];
    if (waiters) { [waiters addObject:[completion copy]]; return; }
    _roundVideoWaiters[identifier] = [NSMutableArray arrayWithObject:[completion copy]];
    [self downloadRoundVideo:document offset:0 data:[NSMutableData data]
        completion:^(NSString *finishedPath, NSString *error) {
        NSArray *callbacks = [_roundVideoWaiters[identifier] copy];
        [_roundVideoWaiters removeObjectForKey:identifier];
        for (TGDocumentPathCompletion callback in callbacks) callback(finishedPath, error);
    }];
}
- (void)downloadRoundVideo:(NSDictionary *)document offset:(int64_t)offset data:(NSMutableData *)data
                completion:(TGDocumentPathCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbe5335be];
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0xbad07584];
    [stream writeInt64:[document[@"id"] longLongValue]];
    [stream writeInt64:[document[@"access_hash"] longLongValue]];
    [stream writeBytes:document[@"file_reference"] ?: [NSData data]];
    [stream writeString:@""];
    [stream writeInt64:offset];
    [stream writeInt32:1048576];
    [self rpc:[stream currentBytes] name:@"upload.getFile.roundVideo"
        service:[self fileServiceForDc:[document[@"dc_id"] integerValue]] completion:^(NSDictionary *result, NSString *error) {
        NSData *part = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
        if (error || !part.length) { completion(nil, error ?: @"Не удалось загрузить кружок."); return; }
        if (data.length + part.length > 20 * 1024 * 1024) {
            completion(nil, @"Кружок слишком большой."); return;
        }
        [data appendData:part];
        int64_t expected = [document[@"size"] longLongValue];
        if ((expected > 0 && data.length >= expected) || (expected <= 0 && part.length < 1048576)) {
            NSData *finished = [data copy];
            NSString *path = [self roundVideoPathForDocument:document];
            dispatch_async(TGMediaCacheQueue(), ^{
                BOOL written = [finished writeToFile:path atomically:YES];
                if (written) [[NSFileManager defaultManager] setAttributes:
                    @{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication }
                    ofItemAtPath:path error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(written ? path : nil, written ? nil : @"Не удалось сохранить кружок.");
                });
            });
        } else [self downloadRoundVideo:document offset:offset + part.length data:data completion:completion];
    }];
}
- (void)downloadStickerDocument:(NSDictionary *)document thumbSize:(NSString *)thumbSize offset:(int64_t)offset
                            data:(NSMutableData *)data completion:(TGAvatarCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbe5335be];
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0xbad07584];
    [stream writeInt64:[document[@"id"] longLongValue]];
    [stream writeInt64:[document[@"access_hash"] longLongValue]];
    [stream writeBytes:document[@"file_reference"] ?: [NSData data]];
    [stream writeString:thumbSize];
    [stream writeInt64:offset];
    [stream writeInt32:524288];
    [self rpc:[stream currentBytes] name:@"upload.getFile.sticker"
        service:[self fileServiceForDc:[document[@"dc_id"] integerValue]] completion:^(NSDictionary *result, NSString *error) {
        NSData *part = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
        if (error || !part.length) { completion(nil, error ?: @"Не удалось загрузить стикер."); return; }
        [data appendData:part];
        if (data.length > 2 * 1024 * 1024) { completion(nil, @"Стикер слишком большой."); return; }
        int64_t expected = thumbSize.length ? 0 : [document[@"size"] longLongValue];
        if ((expected > 0 && data.length >= expected) || part.length < 524288) {
            NSData *finished = [data copy];
            NSString *path = [self stickerPathForDocument:document thumbSize:thumbSize];
            dispatch_async(TGMediaCacheQueue(), ^{
                if (![finished writeToFile:path atomically:YES]) NSLog(@"Telegram media: cannot cache sticker");
                dispatch_async(dispatch_get_main_queue(), ^{ completion(finished, nil); });
            });
        } else [self downloadStickerDocument:document thumbSize:thumbSize offset:offset + part.length
            data:data completion:completion];
    }];
}
- (void)getVoiceDataForDocument:(NSDictionary *)document completion:(TGAvatarCompletion)completion {
    if (!document[@"id"] || !document[@"access_hash"] || !document[@"dc_id"]) {
        completion(nil, @"Голосовое сообщение недоступно."); return;
    }
    if ([document[@"size"] longLongValue] > 20 * 1024 * 1024) {
        completion(nil, @"Голосовое сообщение слишком большое."); return;
    }
    NSString *path = [self voicePathForDocument:document];
    dispatch_async(TGMediaCacheQueue(), ^{
        NSData *cached = [NSData dataWithContentsOfFile:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cached.length) completion(cached, nil);
            else [self downloadVoiceDocument:document offset:0 data:[NSMutableData data] completion:completion];
        });
    });
}
- (void)downloadVoiceDocument:(NSDictionary *)document offset:(int64_t)offset data:(NSMutableData *)data completion:(TGAvatarCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xbe5335be];
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0xbad07584];
    [stream writeInt64:[document[@"id"] longLongValue]];
    [stream writeInt64:[document[@"access_hash"] longLongValue]];
    [stream writeBytes:document[@"file_reference"] ?: [NSData data]];
    [stream writeString:@""];
    [stream writeInt64:offset];
    [stream writeInt32:524288];
    [self rpc:[stream currentBytes] name:@"upload.getFile.voice"
        service:[self fileServiceForDc:[document[@"dc_id"] integerValue]] completion:^(NSDictionary *result, NSString *error) {
        NSData *part = [result[@"bytes"] isKindOfClass:[NSData class]] ? result[@"bytes"] : nil;
        if (error || !part.length) { completion(nil, error ?: @"Не удалось загрузить голосовое сообщение."); return; }
        [data appendData:part];
        int64_t expected = [document[@"size"] longLongValue];
        if (data.length > 20 * 1024 * 1024) { completion(nil, @"Голосовое сообщение слишком большое."); return; }
        if ((expected > 0 && data.length >= expected) || part.length < 524288) {
            NSData *finished = [data copy];
            NSString *path = [self voicePathForDocument:document];
            dispatch_async(TGMediaCacheQueue(), ^{
                if (![finished writeToFile:path atomically:YES]) NSLog(@"Telegram media: cannot cache voice");
                dispatch_async(dispatch_get_main_queue(), ^{ completion(finished, nil); });
            });
        } else [self downloadVoiceDocument:document offset:offset + part.length data:data completion:completion];
    }];
}
- (void)sendVoiceData:(NSData *)data waveform:(NSData *)waveform duration:(int32_t)duration toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    if (!data.length || data.length > 10 * 1024 * 1024) { completion(nil, @"Запись пуста или слишком велика."); return; }
    int64_t fileId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(fileId), (uint8_t *)&fileId) != errSecSuccess) {
        completion(nil, @"Нет безопасного источника случайных чисел."); return;
    }
    int32_t count = (int32_t)((data.length + 524287) / 524288);
    [self uploadVoiceData:data fileId:fileId part:0 count:count duration:MAX(1, duration) waveform:waveform
        peer:peer topicId:topicId completion:completion];
}
- (void)sendVideoData:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType duration:(NSTimeInterval)duration width:(int32_t)width height:(int32_t)height toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    [self sendUploadedData:data fileName:fileName mimeType:mimeType photo:NO video:@{ @"duration": @(MAX(0.1, duration)), @"width": @(MAX(1, width)), @"height": @(MAX(1, height)) } toPeer:peer topicId:topicId completion:completion];
}
- (void)sendPhotoData:(NSData *)data fileName:(NSString *)fileName toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    [self sendUploadedData:data fileName:fileName ?: @"photo.jpg" mimeType:nil photo:YES video:nil
                    toPeer:peer topicId:topicId completion:completion];
}
- (void)sendDocumentData:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType
                   toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    [self sendUploadedData:data fileName:fileName ?: @"file" mimeType:mimeType ?: @"application/octet-stream"
                    photo:NO video:nil toPeer:peer topicId:topicId completion:completion];
}
- (void)sendUploadedData:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType
                    photo:(BOOL)photo video:(NSDictionary *)video toPeer:(NSDictionary *)peer topicId:(int32_t)topicId
               completion:(TGClientCompletion)completion {
    if (!data.length || data.length > (NSUInteger)4000 * 524288) {
        completion(nil, @"Файл пустой или больше 2000 МБ."); return;
    }
    int64_t fileId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(fileId), (uint8_t *)&fileId) != errSecSuccess) {
        completion(nil, @"Нет безопасного источника случайных чисел."); return;
    }
    int32_t count = (int32_t)((data.length + 524287) / 524288);
    [self uploadMediaData:data fileId:fileId part:0 count:count fileName:fileName mimeType:mimeType
                    photo:photo video:video peer:peer topicId:topicId prepareOnly:NO completion:completion];
}
- (void)uploadMediaData:(NSData *)data fileId:(int64_t)fileId part:(int32_t)part count:(int32_t)count
               fileName:(NSString *)fileName mimeType:(NSString *)mimeType photo:(BOOL)photo video:(NSDictionary *)video
                   peer:(NSDictionary *)peer topicId:(int32_t)topicId prepareOnly:(BOOL)prepareOnly completion:(TGClientCompletion)completion {
    BOOL big = data.length > 10 * 1024 * 1024;
    if (part < count) {
        NSUInteger offset = (NSUInteger)part * 524288;
        NSData *chunk = [data subdataWithRange:NSMakeRange(offset, MIN((NSUInteger)524288, data.length - offset))];
        MTOutputStream *stream = [[MTOutputStream alloc] init];
        [stream writeInt32:(int32_t)(big ? 0xde7b673d : 0xb304a621)];
        [stream writeInt64:fileId];
        [stream writeInt32:part];
        if (big) [stream writeInt32:count];
        [stream writeBytes:chunk];
        [self rpc:[stream currentBytes] name:@"upload.saveFilePart.media" completion:^(NSDictionary *result, NSString *error) {
            if (error || ![result[@"_"] isEqual:@"boolTrue"]) {
                completion(nil, error ?: @"Telegram отклонил часть файла."); return;
            }
            [self uploadMediaData:data fileId:fileId part:part + 1 count:count fileName:fileName
                         mimeType:mimeType photo:photo video:video peer:peer topicId:topicId prepareOnly:prepareOnly completion:completion];
        }];
        return;
    }
    NSString *checksum = @"";
    if (!big) {
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5(data.bytes, (CC_LONG)data.length, digest);
        NSMutableString *hex = [NSMutableString string];
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
        checksum = hex;
    }
    NSMutableDictionary *file = [@{@"_": big ? @"inputFileBig" : @"inputFile", @"id": @(fileId), @"parts": @(count), @"name": fileName ?: @"file"} mutableCopy];
    if (!big) file[@"md5_checksum"] = checksum;
    NSMutableDictionary *media = [@{@"_": photo ? @"inputMediaUploadedPhoto" : @"inputMediaUploadedDocument", @"file": file} mutableCopy];
    if (!photo) {
        media[@"mime_type"] = mimeType ?: @"application/octet-stream";
        NSMutableArray *attributes = [NSMutableArray arrayWithObject:@{@"_": @"documentAttributeFilename", @"file_name": fileName ?: @"file"}];
        if (video) [attributes addObject:@{@"_": @"documentAttributeVideo", @"duration": video[@"duration"] ?: @0, @"w": video[@"width"] ?: @1, @"h": video[@"height"] ?: @1, @"supports_streaming": @YES}];
        media[@"attributes"] = attributes; media[@"force_file"] = @(!video);
    }
    if (prepareOnly) {
        [self performRequest:@{@"_": @"messages.uploadMedia", @"peer": peer, @"media": media} completion:^(NSDictionary *result, NSString *error) {
            NSDictionary *object = result[photo ? @"photo" : @"document"];
            if (error || !object[@"id"] || !object[@"access_hash"]) { completion(nil, error ?: @"Не удалось подготовить альбом."); return; }
            completion(@{@"_": photo ? @"inputMediaPhoto" : @"inputMediaDocument", @"id": @{@"_": photo ? @"inputPhoto" : @"inputDocument", @"id": object[@"id"], @"access_hash": object[@"access_hash"], @"file_reference": object[@"file_reference"] ?: [NSData data]}}, nil);
        }];
    } else [self sendInputMedia:media peer:peer topic:topicId reply:0 completion:completion];
}
- (void)prepareAlbumMedia:(NSData *)data fileName:(NSString *)name mimeType:(NSString *)mime photo:(BOOL)photo video:(NSDictionary *)video peer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    if (!data.length || data.length > (NSUInteger)4000 * 524288) { completion(nil, @"Файл пустой или больше 2000 МБ."); return; }
    int64_t identifier = 0; if (SecRandomCopyBytes(kSecRandomDefault, sizeof(identifier), (uint8_t *)&identifier) != errSecSuccess) { completion(nil, @"Не удалось подготовить загрузку."); return; }
    [self uploadMediaData:data fileId:identifier part:0 count:(int32_t)((data.length + 524287) / 524288) fileName:name mimeType:mime photo:photo video:video peer:peer topicId:0 prepareOnly:YES completion:completion];
}
- (void)sendAlbum:(NSArray *)media peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply completion:(TGClientCompletion)completion {
    if (!media.count || media.count > 10) { completion(nil, @"Альбом должен содержать от 1 до 10 вложений."); return; }
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *attachment in media) { int64_t random = 0; if (SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *)&random) != errSecSuccess) { completion(nil, @"Не удалось подготовить отправку."); return; } [items addObject:@{@"_": @"inputSingleMedia", @"media": attachment, @"random_id": @(random), @"message": @""}]; }
    NSMutableDictionary *request = [@{@"_": @"messages.sendMultiMedia", @"peer": peer, @"multi_media": items, @"clear_draft": @YES} mutableCopy];
    if (reply > 0 || topic > 1) { NSMutableDictionary *target = [@{@"_": @"inputReplyToMessage", @"reply_to_msg_id": @(reply > 0 ? reply : topic)} mutableCopy]; if (reply > 0 && topic > 1) target[@"top_msg_id"] = @(topic); request[@"reply_to"] = target; }
    [self performRequest:request completion:completion];
}
- (void)sendRoundVideoData:(NSData *)data duration:(NSTimeInterval)duration width:(int32_t)width
    height:(int32_t)height toPeer:(NSDictionary *)peer topicId:(int32_t)topicId
    completion:(TGClientCompletion)completion {
    if (!data.length || data.length > 10 * 1024 * 1024) {
        completion(nil, @"Кружок пустой или больше 10 МБ."); return;
    }
    int64_t fileId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(fileId), (uint8_t *)&fileId) != errSecSuccess) {
        completion(nil, @"Нет безопасного источника случайных чисел."); return;
    }
    int32_t count = (int32_t)((data.length + 524287) / 524288);
    [self uploadRoundVideoData:data fileId:fileId part:0 count:count duration:duration
        width:width height:height peer:peer topicId:topicId completion:completion];
}
- (void)uploadRoundVideoData:(NSData *)data fileId:(int64_t)fileId part:(int32_t)part count:(int32_t)count
    duration:(NSTimeInterval)duration width:(int32_t)width height:(int32_t)height
    peer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    if (part < count) {
        NSUInteger offset = (NSUInteger)part * 524288;
        NSData *chunk = [data subdataWithRange:NSMakeRange(offset, MIN((NSUInteger)524288, data.length - offset))];
        MTOutputStream *stream = [[MTOutputStream alloc] init];
        [stream writeInt32:(int32_t)0xb304a621];
        [stream writeInt64:fileId];
        [stream writeInt32:part];
        [stream writeBytes:chunk];
        [self rpc:[stream currentBytes] name:@"upload.saveFilePart.roundVideo" completion:^(NSDictionary *result, NSString *error) {
            if (error || ![result[@"_"] isEqual:@"boolTrue"]) {
                completion(nil, error ?: @"Telegram отклонил часть кружка."); return;
            }
            [self uploadRoundVideoData:data fileId:fileId part:part + 1 count:count duration:duration
                width:width height:height peer:peer topicId:topicId completion:completion];
        }];
        return;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *checksum = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [checksum appendFormat:@"%02x", digest[i]];
    int64_t randomId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomId), (uint8_t *)&randomId) != errSecSuccess) {
        completion(nil, @"Нет безопасного источника случайных чисел."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x0330e77f];
    [stream writeInt32:topicId > 1 ? 1 : 0];
    [self writePeer:peer to:stream];
    if (topicId > 1) {
        [stream writeInt32:(int32_t)0x3bd4b7c2];
        [stream writeInt32:0];
        [stream writeInt32:topicId];
    }
    [stream writeInt32:(int32_t)0x037c9330];
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0xf52ff27f];
    [stream writeInt64:fileId];
    [stream writeInt32:count];
    [stream writeString:@"round.mp4"];
    [stream writeString:checksum];
    [stream writeString:@"video/mp4"];
    [stream writeInt32:(int32_t)0x1cb5c415];
    [stream writeInt32:1];
    [stream writeInt32:(int32_t)0x43c57c48];
    [stream writeInt32:1]; // round_message
    [stream writeDouble:MAX(1, duration)];
    [stream writeInt32:MAX(1, width)];
    [stream writeInt32:MAX(1, height)];
    [stream writeString:@""];
    [stream writeInt64:randomId];
    [self rpc:[stream currentBytes] name:@"messages.sendMedia.roundVideo" completion:completion];
}
- (void)uploadVoiceData:(NSData *)data fileId:(int64_t)fileId part:(int32_t)part count:(int32_t)count
                 duration:(int32_t)duration waveform:(NSData *)waveform peer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    if (part < count) {
        NSUInteger offset = (NSUInteger)part * 524288;
        NSData *chunk = [data subdataWithRange:NSMakeRange(offset, MIN((NSUInteger)524288, data.length - offset))];
        MTOutputStream *stream = [[MTOutputStream alloc] init];
        [stream writeInt32:(int32_t)0xb304a621];
        [stream writeInt64:fileId];
        [stream writeInt32:part];
        [stream writeBytes:chunk];
        [self rpc:[stream currentBytes] name:@"upload.saveFilePart.voice" completion:^(NSDictionary *result, NSString *error) {
            if (error || ![result[@"_"] isEqual:@"boolTrue"]) {
                completion(nil, error ?: @"Telegram отклонил часть записи."); return;
            }
            [self uploadVoiceData:data fileId:fileId part:part + 1 count:count duration:duration waveform:waveform
                peer:peer topicId:topicId completion:completion];
        }];
        return;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *checksum = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [checksum appendFormat:@"%02x", digest[i]];
    int64_t randomId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomId), (uint8_t *)&randomId) != errSecSuccess) {
        completion(nil, @"Нет безопасного источника случайных чисел."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x0330e77f];
    [stream writeInt32:topicId > 1 ? 1 : 0];
    [self writePeer:peer to:stream];
    if (topicId > 1) {
        [stream writeInt32:(int32_t)0x3bd4b7c2];
        [stream writeInt32:0];
        [stream writeInt32:topicId];
    }
    [stream writeInt32:(int32_t)0x037c9330];
    [stream writeInt32:0];
    [stream writeInt32:(int32_t)0xf52ff27f];
    [stream writeInt64:fileId];
    [stream writeInt32:count];
    [stream writeString:@"voice.ogg"];
    [stream writeString:checksum];
    [stream writeString:@"audio/ogg"];
    [stream writeInt32:(int32_t)0x1cb5c415];
    [stream writeInt32:1];
    [stream writeInt32:(int32_t)0x9852f9c6];
    BOOL hasWaveform = waveform.length > 0 && waveform.length <= 512;
    [stream writeInt32:(1 << 10) | (hasWaveform ? (1 << 2) : 0)];
    [stream writeInt32:duration];
    if (hasWaveform) [stream writeBytes:waveform];
    [stream writeString:@""];
    [stream writeInt64:randomId];
    [self rpc:[stream currentBytes] name:@"messages.sendMedia.voice" completion:completion];
}
- (NSDictionary *)savedProxySettings {
    NSMutableDictionary *settings = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TGProxySettings"] mutableCopy] ?: [NSMutableDictionary dictionary];
    TGDeviceKeychain *keychain = [[TGDeviceKeychain alloc] initWithNamespace:@"proxy"];
    NSDictionary *credentials = [keychain dictionaryForKey:@"credentials" group:@"network"];
    if (credentials) [settings addEntriesFromDictionary:credentials];
    return settings;
}
- (MTSocksProxySettings *)proxyForSettings:(NSDictionary *)settings {
    if (![settings[@"enabled"] boolValue]) return nil;
    NSString *secret = settings[@"secret"];
    NSData *data = secret.length ? [[MTProxySecret parse:secret] serialize] : nil;
    return [[MTSocksProxySettings alloc] initWithIp:settings[@"host"] port:[settings[@"port"] intValue] username:settings[@"username"] password:settings[@"password"] secret:data];
}
- (NSString *)updateProxySettings:(NSDictionary *)settings {
    if ([settings[@"enabled"] boolValue]) {
        NSInteger port = [settings[@"port"] integerValue];
        if (![settings[@"host"] length] || port < 1 || port > 65535) return @"Укажите адрес сервера и порт от 1 до 65535.";
        if ([settings[@"secret"] length] && ![MTProxySecret parse:settings[@"secret"]]) return @"Неверный секрет MTProto.";
    }
    TGDeviceKeychain *keychain = [[TGDeviceKeychain alloc] initWithNamespace:@"proxy"];
    [keychain setObject:@{@"password": settings[@"password"] ?: @"", @"secret": settings[@"secret"] ?: @""} forKey:@"credentials" group:@"network"];
    NSMutableDictionary *publicSettings = [settings mutableCopy]; [publicSettings removeObjectForKey:@"password"]; [publicSettings removeObjectForKey:@"secret"];
    [[NSUserDefaults standardUserDefaults] setObject:publicSettings forKey:@"TGProxySettings"];
    MTSocksProxySettings *proxy = [self proxyForSettings:settings];
    [_context updateApiEnvironment:^MTApiEnvironment *(MTApiEnvironment *environment) { return [environment withUpdatedSocksProxySettings:proxy]; }];
    return nil;
}
- (NSString *)mediaKindForName:(NSString *)name {
    if ([name hasPrefix:@"avatar-"] || [name hasPrefix:@"media-"]) return @"photos";
    if ([name hasPrefix:@"sticker-"] && ![name hasSuffix:@".plist"]) return @"stickers";
    if ([name hasPrefix:@"round-"]) return @"videos";
    return nil;
}
- (void)mediaCacheSizes:(void (^)(NSDictionary *))completion {
    NSString *directory = [self cacheDirectory]; dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSMutableDictionary *sizes = [NSMutableDictionary dictionary];
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil]) { NSString *kind = [self mediaKindForName:name]; if (!kind) continue; unsigned long long size = [[[NSFileManager defaultManager] attributesOfItemAtPath:[directory stringByAppendingPathComponent:name] error:nil][NSFileSize] unsignedLongLongValue]; sizes[kind] = @([sizes[kind] unsignedLongLongValue] + size); }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(sizes); });
    });
}
- (void)clearMediaCacheKind:(NSString *)kind completion:(void (^)(void))completion {
    if ([kind isEqual:@"stickers"]) [[self stickerKeyboardPreviewCache] removeAllObjects];
    NSString *directory = [self cacheDirectory]; dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil]) if ([[self mediaKindForName:name] isEqual:kind]) [[NSFileManager defaultManager] removeItemAtPath:[directory stringByAppendingPathComponent:name] error:nil];
        dispatch_async(dispatch_get_main_queue(), completion);
    });
}
- (void)updateTwoStepPassword:(NSString *)oldPassword newPassword:(NSString *)newPassword hint:(NSString *)hint email:(NSString *)email completion:(TGClientCompletion)completion {
    [self performRequest:@{ @"_": @"account.getPassword" } completion:^(NSDictionary *configuration, NSString *error) {
        if (error) { completion(nil, error); return; }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *issue = nil; NSDictionary *proof = @{ @"_": @"inputCheckPasswordEmpty" };
            if ([configuration[@"has_password"] boolValue]) { NSData *bytes = [TGSRP proofForPassword:oldPassword configuration:configuration error:&issue]; proof = bytes ? [self->_tl decode:bytes] : nil; }
            BOOL removing = !newPassword.length;
            NSDictionary *next = proof ? (removing ? @{ @"algo": @{ @"_": @"passwordKdfAlgoUnknown" }, @"hash": [NSData data] } : [TGSRP newPasswordSettings:newPassword algorithm:configuration[@"new_algo"] error:&issue]) : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!proof || !next) { completion(nil, issue ?: @"Не удалось изменить пароль."); return; }
                NSMutableDictionary *settings = [@{ @"_": @"account.passwordInputSettings", @"new_algo": next[@"algo"], @"new_password_hash": next[@"hash"], @"hint": removing ? @"" : hint ?: @"" } mutableCopy]; if (email.length || removing) settings[@"email"] = removing ? @"" : email;
                [self performRequest:@{ @"_": @"account.updatePasswordSettings", @"password": proof, @"new_settings": settings } completion:completion];
            });
        });
    }];
}
- (void)sendInputMedia:(NSDictionary *)media peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply completion:(TGClientCompletion)completion {
    int64_t random = 0; if (SecRandomCopyBytes(kSecRandomDefault, 8, (uint8_t *)&random) != errSecSuccess) { completion(nil, @"Не удалось подготовить сообщение."); return; }
    NSMutableDictionary *request = [@{ @"_": @"messages.sendMedia", @"peer": peer, @"media": media, @"message": @"", @"random_id": @(random), @"clear_draft": @YES } mutableCopy];
    if (reply > 0 || topic > 1) { NSMutableDictionary *target = [@{ @"_": @"inputReplyToMessage", @"reply_to_msg_id": @(reply > 0 ? reply : topic) } mutableCopy]; if (reply > 0 && topic > 1) target[@"top_msg_id"] = @(topic); request[@"reply_to"] = target; }
    [self performRequest:request completion:completion];
}
- (void)searchGIFs:(NSString *)query peer:(NSDictionary *)peer offset:(NSString *)offset completion:(TGClientCompletion)completion {
    [self performRequest:@{ @"_": @"contacts.resolveUsername", @"username": @"gif" } completion:^(NSDictionary *resolved, NSString *error) {
        NSDictionary *bot = [resolved[@"users"] firstObject]; if (error || !bot[@"access_hash"]) { completion(nil, error ?: @"Бот @gif недоступен."); return; }
        [self performRequest:@{ @"_": @"messages.getInlineBotResults", @"bot": @{ @"_": @"inputUser", @"user_id": bot[@"id"], @"access_hash": bot[@"access_hash"] }, @"peer": peer, @"query": query ?: @"", @"offset": offset ?: @"" } completion:completion];
    }];
}
- (void)performRequest:(NSDictionary *)request completion:(TGClientCompletion)completion {
    NSString *error = nil; NSData *bytes = [_tl encode:request error:&error];
    if (!bytes) { if (completion) completion(nil, error); return; }
    [self rpc:bytes name:request[@"_"] completion:completion];
}
- (NSString *)draftCachePathForPeer:(NSDictionary *)peer topic:(int32_t)topic {
    NSNumber *identifier = peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"] ?: @0;
    return [[self cacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"draft-%@-%@-%d.plist", peer[@"_"], identifier, topic]];
}
- (NSDictionary *)cachedDraftForPeer:(NSDictionary *)peer topic:(int32_t)topic {
    return [self readCache:[self draftCachePathForPeer:peer topic:topic]];
}
- (void)saveDraft:(NSString *)text peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply { [self saveDraft:text peer:peer topic:topic reply:reply entities:@[]]; }
- (void)saveDraft:(NSString *)text peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply entities:(NSArray *)entities {
    [self writeCache:@{ @"message": text ?: @"", @"reply": @(reply), @"entities": entities ?: @[], @"date": @([[NSDate date] timeIntervalSince1970]) } toPath:[self draftCachePathForPeer:peer topic:topic]];
    NSDictionary *parsed = TGParseFormattedText(text); NSMutableArray *formatted = [parsed[@"entities"] mutableCopy]; NSArray *mapping = parsed[@"mapping"];
    for (NSDictionary *entity in entities) { NSUInteger start = [entity[@"offset"] unsignedIntegerValue], end = start + [entity[@"length"] unsignedIntegerValue]; if (start < mapping.count && end < mapping.count) { NSMutableDictionary *adjusted = [entity mutableCopy]; adjusted[@"offset"] = mapping[start]; adjusted[@"length"] = @([mapping[end] unsignedIntegerValue] - [mapping[start] unsignedIntegerValue]); [formatted addObject:adjusted]; } }
    NSMutableDictionary *request = [@{ @"_": @"messages.saveDraft", @"peer": peer, @"message": parsed[@"text"] } mutableCopy];
    if (formatted.count) request[@"entities"] = formatted;
    if (reply > 0 || topic > 1) {
        NSMutableDictionary *target = [@{ @"_": @"inputReplyToMessage", @"reply_to_msg_id": @(reply > 0 ? reply : topic) } mutableCopy];
        if (reply > 0 && topic > 1) target[@"top_msg_id"] = @(topic);
        request[@"reply_to"] = target;
    }
    [self performRequest:request completion:^(__unused NSDictionary *result, __unused NSString *error) {}];
}
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)peer topicId:(int32_t)topic replyToMessageId:(int32_t)reply
       silent:(BOOL)silent scheduleDate:(int32_t)date entities:(NSArray *)entities completion:(TGClientCompletion)completion {
    uint64_t random = 0;
    if (!text.length || SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *)&random) != errSecSuccess) { completion(nil, @"Не удалось подготовить сообщение."); return; }
    NSMutableDictionary *request = [@{ @"_": @"messages.sendMessage", @"peer": peer, @"message": text, @"random_id": @(random), @"clear_draft": @YES, @"silent": @(silent) } mutableCopy];
    if (reply > 0 || topic > 1) {
        NSMutableDictionary *target = [@{ @"_": @"inputReplyToMessage", @"reply_to_msg_id": @(reply > 0 ? reply : topic) } mutableCopy];
        if (reply > 0 && topic > 1) target[@"top_msg_id"] = @(topic); request[@"reply_to"] = target;
    }
    if (date > 0) request[@"schedule_date"] = @(date);
    if (entities.count) request[@"entities"] = entities;
    [self performRequest:request completion:completion];
}
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion {
    [self sendText:text toPeer:inputPeer topicId:0 completion:completion];
}
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId completion:(TGClientCompletion)completion {
    [self sendText:text toPeer:inputPeer topicId:topicId replyToMessageId:0 completion:completion];
}
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId replyToMessageId:(int32_t)messageId completion:(TGClientCompletion)completion {
    if (!text.length) { completion(nil, @"Введите сообщение."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xfef48f62];
    [stream writeInt32:(topicId > 1 || messageId > 0) ? 1 : 0];
    [self writePeer:inputPeer to:stream];
    if (topicId > 1 || messageId > 0) {
        [stream writeInt32:(int32_t)0x3bd4b7c2];
        [stream writeInt32:(topicId > 1 && messageId > 0) ? 1 : 0];
        [stream writeInt32:messageId > 0 ? messageId : topicId];
        if (topicId > 1 && messageId > 0) [stream writeInt32:topicId];
    }
    [stream writeString:text];
    uint64_t randomId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomId), (uint8_t *)&randomId) != errSecSuccess) {
        completion(nil, @"Нет безопасного источника случайных чисел."); return;
    }
    [stream writeInt64:(int64_t)randomId];
    [self rpc:[stream currentBytes] name:@"messages.sendMessage" completion:completion];
}
- (void)editMessage:(int32_t)messageId text:(NSString *)text inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    if (messageId <= 0 || !text.length) { completion(nil, @"Нечего редактировать."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xb106e66c];
    [stream writeInt32:(1 << 11)];
    [self writePeer:peer to:stream];
    [stream writeInt32:messageId];
    [stream writeString:text];
    [self rpc:[stream currentBytes] name:@"messages.editMessage" completion:^(NSDictionary *result, NSString *error) {
        if (!error) [self changeCachedMessage:messageId inPeer:peer text:text deleted:NO];
        completion(result, error);
    }];
}
- (void)deleteMessage:(int32_t)messageId inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    if (messageId <= 0) { completion(nil, @"Сообщение недоступно."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    BOOL channel = [peer[@"_"] isEqual:@"inputPeerChannel"];
    [stream writeInt32:channel ? (int32_t)0x84c1fd4e : (int32_t)0xe58e95d2];
    if (channel) {
        [stream writeInt32:(int32_t)0xf35aec28];
        [stream writeInt64:[peer[@"channel_id"] longLongValue]];
        [stream writeInt64:[peer[@"access_hash"] longLongValue]];
    } else [stream writeInt32:1]; // revoke for everyone
    [stream writeInt32:(int32_t)0x1cb5c415];
    [stream writeInt32:1];
    [stream writeInt32:messageId];
    [self rpc:[stream currentBytes] name:channel ? @"channels.deleteMessages" : @"messages.deleteMessages" completion:^(NSDictionary *result, NSString *error) {
        if (!error) [self changeCachedMessage:messageId inPeer:peer text:nil deleted:YES];
        completion(result, error);
    }];
}
- (void)sendReaction:(NSString *)emoji toMessage:(int32_t)messageId inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    if (messageId <= 0 || !emoji.length) { completion(nil, @"Реакция недоступна."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xd30d78d4];
    [stream writeInt32:1];
    [self writePeer:peer to:stream];
    [stream writeInt32:messageId];
    [stream writeInt32:(int32_t)0x1cb5c415];
    [stream writeInt32:1];
    [stream writeInt32:(int32_t)0x1b2286b8];
    [stream writeString:emoji];
    [self rpc:[stream currentBytes] name:@"messages.sendReaction" completion:completion];
}
- (void)forwardMessage:(int32_t)messageId fromPeer:(NSDictionary *)source toPeer:(NSDictionary *)destination completion:(TGClientCompletion)completion {
    if (messageId <= 0 || !source || !destination) { completion(nil, @"Нельзя переслать сообщение."); return; }
    uint64_t randomId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomId), (uint8_t *)&randomId) != errSecSuccess) {
        completion(nil, @"Нет безопасного источника случайных чисел."); return;
    }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x13704a7c];
    [stream writeInt32:0];
    [self writePeer:source to:stream];
    [stream writeInt32:(int32_t)0x1cb5c415]; [stream writeInt32:1]; [stream writeInt32:messageId];
    [stream writeInt32:(int32_t)0x1cb5c415]; [stream writeInt32:1]; [stream writeInt64:(int64_t)randomId];
    [self writePeer:destination to:stream];
    [self rpc:[stream currentBytes] name:@"messages.forwardMessages" completion:completion];
}
- (void)setMuted:(BOOL)muted forPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x84be5b93]; // account.updateNotifySettings
    [stream writeInt32:(int32_t)0xb8bc5b0c]; // inputNotifyPeer
    [self writePeer:peer to:stream];
    [stream writeInt32:(int32_t)0xcacb6ae2]; // inputPeerNotifySettings
    [stream writeInt32:4]; // mute_until is present
    [stream writeInt32:muted ? INT32_MAX : 0];
    [self rpc:[stream currentBytes] name:@"account.updateNotifySettings" completion:completion];
}
- (void)setArchived:(BOOL)archived forPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion {
    if (!peer) { completion(nil, @"Чат недоступен."); return; }
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x6847d0ab]; // folders.editPeerFolders
    [stream writeInt32:(int32_t)0x1cb5c415]; // Vector
    [stream writeInt32:1];
    [stream writeInt32:(int32_t)0xfbd2c296]; // inputFolderPeer
    [self writePeer:peer to:stream];
    [stream writeInt32:archived ? 1 : 0];
    [self rpc:[stream currentBytes] name:@"folders.editPeerFolders" completion:completion];
}
- (void)logOut:(TGClientCompletion)completion {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x3e72ba19];
    [self rpc:[stream currentBytes] name:@"auth.logOut" completion:^(NSDictionary *result, NSString *error) {
        if (!error) {
            [self clearSavedSession];
        }
        completion(result, error);
    }];
}
@end
