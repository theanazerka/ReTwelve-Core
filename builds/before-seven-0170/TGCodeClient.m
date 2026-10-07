#import "TGCodeClient.h"
#import "LocalConfig.h"

#import <MtProtoKit/MtProtoKit.h>
#import <OpenSSLEncryptionProvider/OpenSSLEncryptionProvider.h>

@interface TGMemoryKeychain : NSObject <MTKeychain>
@property (nonatomic, strong) NSMutableDictionary *values;
@end

@implementation TGMemoryKeychain
- (instancetype)init {
    self = [super init];
    if (self) _values = [[NSMutableDictionary alloc] init];
    return self;
}
- (NSString *)nameForKey:(NSString *)key group:(NSString *)group {
    return [NSString stringWithFormat:@"%@/%@", group, key];
}
- (void)setObject:(id)object forKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        NSString *name = [self nameForKey:key group:group];
        if (object) self.values[name] = object;
        else [self.values removeObjectForKey:name];
    }
}
- (NSDictionary *)dictionaryForKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        id value = self.values[[self nameForKey:key group:group]];
        return [value isKindOfClass:[NSDictionary class]] ? value : nil;
    }
}
- (NSNumber *)numberForKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        id value = self.values[[self nameForKey:key group:group]];
        return [value isKindOfClass:[NSNumber class]] ? value : nil;
    }
}
- (void)removeObjectForKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        [self.values removeObjectForKey:[self nameForKey:key group:group]];
    }
}
@end

// MTProtoKit parses its own service messages. This demo only sends one API method.
@interface TGCodeSerialization : NSObject <MTSerialization>
@end

@implementation TGCodeSerialization
- (NSUInteger)currentLayer { return 225; }
- (id)parseMessage:(NSData *)data { return nil; }
- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)dc data:(NSData **)data { return nil; }
- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes { return nil; }
- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(NSData **)data { return nil; }
- (MTRequestNoopParser)requestNoop:(NSData **)data {
    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0x1fb33026]; // help.getNearestDc
    *data = [stream currentBytes];
    return ^id(NSData *response) { return response; };
}
@end

static uint32_t TGReadUInt32(NSData *data, NSUInteger offset) {
    if (data.length < offset + 4) return 0;
    uint32_t value = 0;
    [data getBytes:&value range:NSMakeRange(offset, 4)];
    return value;
}

static NSString *TGMessageForResponse(NSData *data, BOOL *success) {
    uint32_t constructor = TGReadUInt32(data, 0);
    if (constructor == 0x5e002502) { // auth.sentCode
        *success = YES;
        uint32_t deliveryType = TGReadUInt32(data, 8);
        if (deliveryType == 0x3dbb5986) return @"Код отправлен в Telegram на другом устройстве.";
        if (deliveryType == 0xc000bba2) return @"Код отправлен по SMS.";
        if (deliveryType == 0x5353e5a7) return @"Код отправлен голосовым звонком.";
        if (deliveryType == 0xf450f59b) return @"Код отправлен на почту.";
        return @"Telegram принял запрос. Проверьте Telegram, SMS и почту.";
    }
    if (constructor == 0x2390fe44) {
        *success = YES;
        return @"Аккаунт уже авторизован; новый код не требовался.";
    }
    if (constructor == 0xf8827ebf) {
        *success = NO;
        return @"Telegram требует оплату для получения кода на этот номер.";
    }
    *success = NO;
    return [NSString stringWithFormat:@"Неизвестный ответ Telegram: 0x%08x", constructor];
}

@interface TGCodeClient () {
    MTContext *_context;
    MTDatacenterAuthAction *_authAction;
    MTProto *_mtProto;
    MTRequestMessageService *_requestService;
    MTRequest *_activeRequest;
    NSString *_phone;
    TGCodeCompletion _completion;
    TGCodeStatus _status;
    NSUInteger _generation;
    NSUInteger _migrationCount;
}
@end

@implementation TGCodeClient

- (instancetype)init {
    self = [super init];
    if (self) {
        MTApiEnvironment *environment = [[MTApiEnvironment alloc] initWithDeviceModelName:@"iOS 6"];
        environment.apiId = TG_API_ID;
        environment.appVersion = @"0.1";
        environment.layer = @(225);
        _context = [[MTContext alloc] initWithSerialization:[[TGCodeSerialization alloc] init]
                                    encryptionProvider:[[OpenSSLEncryptionProvider alloc] init]
                                        apiEnvironment:environment
                                   isTestingEnvironment:false
                                       useTempAuthKeys:false];
        _context.keychain = [[TGMemoryKeychain alloc] init];

        // Bootstrap addresses. Telegram may redirect auth.sendCode to another DC.
        NSArray *ips = @[@"149.154.175.51", @"149.154.167.50", @"149.154.175.100",
                         @"149.154.167.91", @"91.108.56.125"];
        for (NSUInteger i = 0; i < ips.count; i++) {
            MTDatacenterAddress *address = [[MTDatacenterAddress alloc]
                initWithIp:ips[i] port:443 preferForMedia:false restrictToTcp:true
                        cdn:false preferForProxy:false secret:nil];
            MTDatacenterAddressSet *set = [[MTDatacenterAddressSet alloc] initWithAddressList:@[address]];
            [_context setSeedAddressSetForDatacenterWithId:i + 1 seedAddressSet:set];
        }
    }
    return self;
}

- (void)reportStatus:(NSString *)message generation:(NSUInteger)generation {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (generation == self->_generation && self->_completion != nil && self->_status != nil)
            self->_status(message);
    });
}

- (void)finish:(BOOL)success message:(NSString *)message generation:(NSUInteger)generation {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (generation != self->_generation || self->_completion == nil) return;
        TGCodeCompletion completion = self->_completion;
        self->_completion = nil;
        self->_status = nil;
        [self->_authAction cancel];
        [self->_mtProto stop];
        self->_authAction = nil;
        self->_mtProto = nil;
        self->_requestService = nil;
        self->_activeRequest = nil;
        completion(success, message);
    });
}

- (void)requestCodeForPhone:(NSString *)phone status:(TGCodeStatus)status completion:(TGCodeCompletion)completion {
    NSCharacterSet *ignored = [NSCharacterSet characterSetWithCharactersInString:@" ()-\t\n"];
    NSString *normalized = [[phone componentsSeparatedByCharactersInSet:ignored] componentsJoinedByString:@""];
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSString *numberPart = [normalized hasPrefix:@"+"] ? [normalized substringFromIndex:1] : @"";
    if (numberPart.length < 5 || numberPart.length > 15 ||
        [[numberPart stringByTrimmingCharactersInSet:digits] length] != 0) {
        completion(NO, @"Введите номер в международном формате: +79991234567");
        return;
    }

    _generation++;
    NSUInteger generation = _generation;
    _migrationCount = 0;
    _phone = normalized;
    _completion = [completion copy];
    _status = [status copy];
    [_authAction cancel];
    [_mtProto stop];
    _activeRequest = nil;
    _requestService = nil;
    _mtProto = nil;

    [self startOnDatacenter:2 generation:generation];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(90 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSString *stage = self->_activeRequest == nil ? @"создания ключа MTProto" : @"ответа на auth.sendCode";
        [self finish:NO message:[NSString stringWithFormat:@"Тайм-аут %@ (90 с).", stage] generation:generation];
    });
}

- (void)startOnDatacenter:(NSInteger)dc generation:(NSUInteger)generation {
    if (generation != _generation) return;
    [self reportStatus:[NSString stringWithFormat:@"DC%ld: создаём ключ MTProto…", (long)dc] generation:generation];
    __weak TGCodeClient *weakSelf = self;
    _authAction = [[MTDatacenterAuthAction alloc]
        initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorPersistent
                             isCdn:false skipBind:true
                         completion:^(MTDatacenterAuthAction *action, bool success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TGCodeClient *strongSelf = weakSelf;
            if (strongSelf == nil || generation != strongSelf->_generation ||
                strongSelf->_completion == nil) return;
            if (!success) {
                [strongSelf finish:NO message:@"Не удалось создать ключ MTProto." generation:generation];
                return;
            }
            [strongSelf sendRequestOnDatacenter:dc generation:generation];
        });
    }];
    [_authAction execute:_context datacenterId:dc];
}

- (void)sendRequestOnDatacenter:(NSInteger)dc generation:(NSUInteger)generation {
    [self reportStatus:[NSString stringWithFormat:@"DC%ld: ключ готов, отправляем auth.sendCode…", (long)dc] generation:generation];
    [_mtProto stop];
    _mtProto = [[MTProto alloc] initWithContext:_context datacenterId:dc
                          usageCalculationInfo:nil requiredAuthToken:nil
                    authTokenMasterDatacenterId:0];
    // auth.sendCode is unauthenticated at the account level, but its MTProto
    // transport must use the encrypted session created by the auth action.
    _mtProto.useUnauthorizedMode = false;
    _requestService = [[MTRequestMessageService alloc] initWithContext:_context];
    [_mtProto addMessageService:_requestService];
    [_mtProto resume];

    MTOutputStream *stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xa677244f]; // auth.sendCode
    [stream writeString:_phone];
    [stream writeInt32:TG_API_ID];
    [stream writeString:TG_API_HASH];
    [stream writeInt32:(int32_t)0xad253d78]; // codeSettings
    [stream writeInt32:0]; // Flags: Telegram chooses the delivery method.

    _activeRequest = [[MTRequest alloc] init];
    [_activeRequest setPayload:[stream currentBytes] metadata:@"auth.sendCode"
                    shortMetadata:@"sendCode" responseParser:^id(NSData *response) {
        return response.length >= 4 ? response : nil;
    }];
    _activeRequest.needsTimeoutTimer = true;
    _activeRequest.shouldContinueExecutionWithErrorContext = ^bool(MTRequestErrorContext *context) {
        return false; // Show flood and server errors; never retry a code request silently.
    };

    __weak TGCodeClient *weakSelf = self;
    _activeRequest.completed = ^(id result, MTRequestResponseInfo *info, MTRpcError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TGCodeClient *strongSelf = weakSelf;
            if (strongSelf == nil || generation != strongSelf->_generation ||
                strongSelf->_completion == nil) return;

            NSString *description = error.errorDescription;
            if (description != nil && strongSelf->_migrationCount < 5) {
                BOOL migration = [description hasPrefix:@"PHONE_MIGRATE_"] ||
                                 [description hasPrefix:@"NETWORK_MIGRATE_"];
                if (migration) {
                    NSInteger newDc = [[[description componentsSeparatedByString:@"_"] lastObject] integerValue];
                    if (newDc >= 1 && newDc <= 5 && newDc != dc) {
                        strongSelf->_migrationCount++;
                        [strongSelf startOnDatacenter:newDc generation:generation];
                        return;
                    }
                }
            }

            if (error != nil) {
                NSString *message = [NSString stringWithFormat:@"Telegram: %@ (%d)",
                                     description ?: @"ошибка", error.errorCode];
                [strongSelf finish:NO message:message generation:generation];
                return;
            }
            BOOL success = NO;
            NSString *message = TGMessageForResponse(result, &success);
            [strongSelf finish:success message:message generation:generation];
        });
    };
    [_requestService addRequest:_activeRequest];
}

@end
