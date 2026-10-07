#import "TGCallMedia.h"
#import "TGClient.h"
#import "TGCallAudio.h"
#import "TGCallCipher.h"
#import "TGCallDTLS.h"
#import "TGCallICE.h"
#import "TGCallRTP.h"
#import "TGCallSignal.h"
#import "TGCallReflectorProtocol.h"
#import <Security/Security.h>

@interface TGCallMedia () {
    uint32_t _localSSRC, _remoteSSRC, _localOfferExchangeId, _remoteOfferExchangeId;
    uint8_t _remotePayloadType;
    BOOL _iceConnected, _dtlsReady, _stopped, _sentInitialSetup, _sentLocalOffer;
    NSUInteger _localCandidates, _remoteCandidates, _remoteCandidatesSeen;
    NSUInteger _localHost, _localSrflx, _localRelay;
    NSUInteger _stunServers, _turnServers;
    NSUInteger _reflectorServers, _remoteReflectorCandidates;
    NSUInteger _sentSignals, _sentSignalsOK, _incomingSignals, _decryptedSignals, _parsedSignals;
    BOOL _receivedRemoteSetup;
}
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *call;
@property (nonatomic, strong) TGCallCipher *cipher;
@property (nonatomic, strong) TGCallICE *ice;
@property (nonatomic, strong) TGCallDTLS *dtls;
@property (nonatomic, strong) TGCallRTP *rtp;
@property (nonatomic, strong) TGCallAudio *audio;
@property (nonatomic, strong) NSString *remoteFingerprint;
@property (nonatomic, strong) NSString *remoteSetup;
@property (nonatomic, strong) NSMutableArray *pendingCandidates;
@property (nonatomic) BOOL caller;
@end

@implementation TGCallMedia
- (instancetype)initWithClient:(TGClient *)client call:(NSDictionary *)call key:(NSData *)key caller:(BOOL)caller {
    if (!client || !call[@"id"] || !call[@"access_hash"] || key.length != 256) return nil;
    self = [super init];
    if (self) {
        _client = client; _call = [call copy]; _caller = caller;
        _cipher = [[TGCallCipher alloc] initWithKey:key caller:caller signaling:YES];
        _pendingCandidates = [NSMutableArray array];
        _reflectorServers = [TGCallReflectorProtocol endpoints:call[@"connections"]].count;
        for (NSDictionary *connection in call[@"connections"]) {
            if (![connection isKindOfClass:[NSDictionary class]] ||
                ![connection[@"_"] isEqual:@"phoneConnectionWebrtc"]) continue;
            if ([connection[@"stun"] boolValue]) _stunServers++;
            if ([connection[@"turn"] boolValue]) _turnServers++;
            if ([connection[@"username"] isEqual:@"reflector"]) _reflectorServers++;
        }
    }
    return self;
}
- (void)report:(NSString *)state error:(NSString *)error {
    if (self.stateHandler) self.stateHandler(state, error);
}
- (void)reportICEProgress {
    if (_stopped || _iceConnected) return;
    NSString *detail = [NSString stringWithFormat:
        @"Поиск соединения · %@%@\nL:%lu H:%lu S:%lu T:%lu · R:%lu/%lu\nСерверы S:%lu T:%lu reflector:%lu · R-ref:%lu\nСигналы ↑%lu/%lu ↓%lu/%lu/%lu",
        self.caller ? @"вызов" : @"ответ", _receivedRemoteSetup ? @"" : @" · ждём параметры",
        (unsigned long)_localCandidates, (unsigned long)_localHost,
        (unsigned long)_localSrflx, (unsigned long)_localRelay,
        (unsigned long)_remoteCandidates, (unsigned long)_remoteCandidatesSeen,
        (unsigned long)_stunServers, (unsigned long)_turnServers,
        (unsigned long)_reflectorServers, (unsigned long)_remoteReflectorCandidates,
        (unsigned long)_sentSignalsOK, (unsigned long)_sentSignals,
        (unsigned long)_incomingSignals, (unsigned long)_decryptedSignals,
        (unsigned long)_parsedSignals];
    [self report:@"ice-progress" error:[detail stringByAppendingFormat:@"\n%@", [self.ice transportDiagnostics] ?: @""]];
}
- (void)scheduleProgress {
    __weak TGCallMedia *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        TGCallMedia *media = weakSelf;
        if (!media || media->_stopped || media.audio) return;
        if (media->_iceConnected) {
            NSString *detail = [NSString stringWithFormat:@"Защита соединения…\n%@\nАудиоканал: %@ · Сигналы ↓%lu/%lu/%lu\n%@",
                [media.dtls diagnostics], media->_remoteSSRC ? @"получен" : @"ожидание",
                (unsigned long)media->_incomingSignals, (unsigned long)media->_decryptedSignals,
                (unsigned long)media->_parsedSignals, [media.ice transportDiagnostics]];
            NSLog(@"Telegram call: %@", detail);
            [media report:@"securing" error:detail];
        } else [media reportICEProgress];
        [media scheduleProgress];
    });
}
- (void)sendSignal:(NSData *)plain {
    if (_stopped || !plain.length) return;
    NSData *sealed = [self.cipher encrypt:plain];
    if (!sealed) { [self report:@"failed" error:@"Не удалось зашифровать сигнал звонка."]; return; }
    _sentSignals++;
    [self reportICEProgress];
    __weak TGCallMedia *weakSelf = self;
    [self.client sendCallSignalingData:sealed call:self.call completion:^(NSDictionary *result, NSString *error) {
        TGCallMedia *media = weakSelf;
        if (!media || media->_stopped) return;
        if (error) [media report:@"failed" error:error];
        else { media->_sentSignalsOK++; [media reportICEProgress]; }
    }];
}
- (BOOL)start:(NSString **)error {
    if (_ice || _stopped) return NO;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(_localSSRC), (uint8_t *)&_localSSRC) != errSecSuccess)
        return NO;
    if (!_localSSRC) _localSSRC = 1;
    self.dtls = [[TGCallDTLS alloc] initWithCaller:self.caller];
    if (![self.dtls prepareWithError:error]) return NO;
    self.ice = [[TGCallICE alloc] initWithConnections:self.call[@"connections"] caller:self.caller];
    __weak TGCallMedia *weakSelf = self;
    self.ice.candidateHandler = ^(NSString *candidate) {
        TGCallMedia *media = weakSelf;
        if (media && !media->_stopped && candidate.length) {
            media->_localCandidates++;
            if ([candidate rangeOfString:@" typ host"].location != NSNotFound) media->_localHost++;
            else if ([candidate rangeOfString:@" typ srflx"].location != NSNotFound) media->_localSrflx++;
            else if ([candidate rangeOfString:@" typ relay"].location != NSNotFound) media->_localRelay++;
            [media sendSignal:[TGCallSignal candidates:@[candidate]]];
            [media reportICEProgress];
        }
    };
    self.ice.stateHandler = ^(NSString *state) {
        TGCallMedia *media = weakSelf;
        if (!media || media->_stopped) return;
        if ([state isEqual:@"connected"] || [state isEqual:@"completed"]) {
            media->_iceConnected = YES;
            [media report:@"securing" error:nil];
            [media startDTLSIfReady];
        } else if ([state isEqual:@"gathering"] || [state isEqual:@"connecting"]) {
            [media reportICEProgress];
        } else if ([state isEqual:@"failed"] || [state isEqual:@"disconnected"])
            [media report:@"failed" error:@"ICE-соединение звонка прервалось."];
    };
    self.ice.packetHandler = ^(NSData *packet) {
        TGCallMedia *media = weakSelf;
        if (!media || media->_stopped || !packet.length) return;
        uint8_t first = ((const uint8_t *)packet.bytes)[0];
        if (first >= 20 && first <= 63) [media.dtls receivePacket:packet];
        else if (first >= 128 && first <= 191 && media.rtp) {
            NSData *opus = [media.rtp unprotectOpus:packet];
            if (opus) [media.audio receivePacket:opus];
        }
    };
    self.dtls.packetHandler = ^(NSData *packet) {
        TGCallMedia *media = weakSelf;
        if (media && !media->_stopped) [media.ice sendPacket:packet];
    };
    self.dtls.readyHandler = ^(BOOL ready, NSString *failure) {
        TGCallMedia *media = weakSelf;
        if (!media || media->_stopped) return;
        if (!ready) [media report:@"failed" error:failure];
        else { media->_dtlsReady = YES; [media startAudioIfReady]; }
    };
    if (![self.ice start:error]) { [self stop]; return NO; }
    [self scheduleProgress];
    NSString *description = [self.ice localDescription];
    NSString *ufrag = nil, *password = nil;
    [TGCallSignal iceCredentialsFromDescription:description ufrag:&ufrag password:&password];
    NSData *setup = [TGCallSignal initialSetupWithUfrag:ufrag password:password
        fingerprint:self.dtls.localFingerprint caller:self.caller];
    if (!setup) {
        if (error) *error = @"Не удалось подготовить параметры аудиоканала.";
        [self stop]; return NO;
    }
    if (self.caller) {
        [self sendSignal:setup]; _sentInitialSetup = YES;
        [self sendLocalOffer];
    }
    [self reportICEProgress];
    return YES;
}
- (void)receiveSignalingPacket:(NSData *)data {
    if (_stopped || !self.ice) return;
    _incomingSignals++;
    NSData *plain = [self.cipher decrypt:data];
    if (plain) _decryptedSignals++;
    NSDictionary *message = [TGCallSignal parse:plain];
    if (!message) { [self reportICEProgress]; return; }
    _parsedSignals++;
    NSString *type = message[@"@type"];
    if ([type isEqual:@"InitialSetup"]) {
        NSString *ufrag = message[@"ufrag"], *password = message[@"pwd"];
        NSArray *fingerprints = message[@"fingerprints"];
        NSDictionary *fingerprint = fingerprints.count ? fingerprints[0] : nil;
        if (!ufrag.length || !password.length ||
            ![fingerprint[@"hash"] isEqual:@"sha-256"] ||
            ![fingerprint[@"fingerprint"] isKindOfClass:[NSString class]]) {
            [self report:@"failed" error:@"Неподдерживаемая защита звонка."]; return;
        }
        self.remoteFingerprint = fingerprint[@"fingerprint"];
        self.remoteSetup = [fingerprint[@"setup"] isKindOfClass:[NSString class]] ? fingerprint[@"setup"] : @"actpass";
        _receivedRemoteSetup = YES;
        if (!self.caller && !_sentInitialSetup) {
            NSString *localDescription = [self.ice localDescription];
            NSString *localUfrag = nil, *localPassword = nil;
            [TGCallSignal iceCredentialsFromDescription:localDescription
                ufrag:&localUfrag password:&localPassword];
            NSData *localSetup = [TGCallSignal initialSetupWithUfrag:localUfrag password:localPassword
                fingerprint:self.dtls.localFingerprint caller:NO];
            if (localSetup) { [self sendSignal:localSetup]; _sentInitialSetup = YES; }
        }
        NSString *description = [NSString stringWithFormat:@"a=ice-ufrag:%@\r\na=ice-pwd:%@\r\n", ufrag, password];
        if (![self.ice setRemoteDescription:description]) {
            [self report:@"failed" error:@"Не удалось установить параметры ICE."]; return;
        }
        for (NSString *candidate in self.pendingCandidates)
            if ([self.ice addRemoteCandidate:candidate]) _remoteCandidates++;
        [self.pendingCandidates removeAllObjects];
        [self reportICEProgress];
        [self startDTLSIfReady];
    } else if ([type isEqual:@"Candidates"]) {
        for (NSDictionary *item in message[@"candidates"]) {
            NSString *candidate = item[@"sdpString"];
            _remoteCandidatesSeen++;
            if ([candidate rangeOfString:@".reflector"].location != NSNotFound)
                _remoteReflectorCandidates++;
            if (self.remoteFingerprint) {
                if ([self.ice addRemoteCandidate:candidate]) _remoteCandidates++;
            }
            else if (self.pendingCandidates.count < 128) [self.pendingCandidates addObject:candidate];
        }
        [self reportICEProgress];
    } else if ([type isEqual:@"NegotiateChannels"]) {
        uint32_t exchangeId = 0, offeredSSRC = 0;
        uint8_t offeredPayloadType = 0;
        if (![TGCallSignal exchangeIdFromChannels:message value:&exchangeId]) return;
        if (_sentLocalOffer && exchangeId == _localOfferExchangeId) return; // answer to our offer
        if (![TGCallSignal remoteAudioFromChannels:message ssrc:&offeredSSRC payloadType:&offeredPayloadType]) {
            [self report:@"failed" error:@"Собеседник не предложил совместимый Opus-аудиоканал."];
            return;
        }
        if (_remoteOfferExchangeId == exchangeId && _remoteSSRC == offeredSSRC) return;
        _remoteOfferExchangeId = exchangeId;
        _remoteSSRC = offeredSSRC; _remotePayloadType = offeredPayloadType;
        [self sendSignal:[TGCallSignal audioChannelsWithSSRC:offeredSSRC exchangeId:exchangeId]];
        if (!_sentLocalOffer) [self sendLocalOffer];
        [self startAudioIfReady];
    }
}
- (void)sendLocalOffer {
    if (_sentLocalOffer || _stopped) return;
    uint32_t exchangeId = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(exchangeId), (uint8_t *)&exchangeId) != errSecSuccess)
        return;
    if (!exchangeId || exchangeId == _remoteOfferExchangeId) exchangeId++;
    NSData *offer = [TGCallSignal audioChannelsWithSSRC:_localSSRC exchangeId:exchangeId];
    if (!offer) return;
    _localOfferExchangeId = exchangeId; _sentLocalOffer = YES;
    [self sendSignal:offer];
}
- (void)startDTLSIfReady {
    if (!_iceConnected || !self.remoteFingerprint || _dtlsReady) return;
    NSString *error = nil;
    if (![self.dtls startWithPeerFingerprint:self.remoteFingerprint setup:self.remoteSetup error:&error])
        [self report:@"failed" error:error];
}
- (void)startAudioIfReady {
    if (!_dtlsReady || !_remoteSSRC || self.audio || _stopped) return;
    self.rtp = [[TGCallRTP alloc] initWithLocalSSRC:_localSSRC remoteSSRC:_remoteSSRC
        outboundKey:self.dtls.outboundSRTPKey inboundKey:self.dtls.inboundSRTPKey
        sendPayloadType:111 receivePayloadType:_remotePayloadType];
    if (!self.rtp) { [self report:@"failed" error:@"Не удалось запустить SRTP."]; return; }
    self.audio = [[TGCallAudio alloc] init];
    __weak TGCallMedia *weakSelf = self;
    self.audio.packetHandler = ^(NSData *opus) {
        TGCallMedia *media = weakSelf;
        if (!media || media->_stopped) return;
        NSData *packet = [media.rtp protectOpus:opus];
        if (packet) [media.ice sendPacket:packet];
    };
    NSString *error = nil;
    if (![self.audio start:&error]) { [self report:@"failed" error:error]; return; }
    [self report:@"connected" error:nil];
}
- (void)stop {
    _stopped = YES;
    [self.audio stop]; self.audio = nil;
    [self.rtp stop]; self.rtp = nil;
    [self.dtls stop]; self.dtls = nil;
    [self.ice stop]; self.ice = nil;
    self.cipher = nil;
    self.remoteFingerprint = nil;
}
- (void)dealloc { [self stop]; }
@end
