#import "TGCallDTLS.h"
#import <openssl/ssl.h>
#import <openssl/x509.h>
#import <openssl/evp.h>
#import <openssl/ec.h>
#import <openssl/crypto.h>

static NSString *TGFingerprint(X509 *certificate) {
    uint8_t bytes[EVP_MAX_MD_SIZE]; unsigned int count = 0;
    if (!certificate || X509_digest(certificate, EVP_sha256(), bytes, &count) != 1 || count != 32) return nil;
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int i = 0; i < count; i++) [parts addObject:[NSString stringWithFormat:@"%02X", bytes[i]]];
    return [parts componentsJoinedByString:@":"];
}

static BOOL TGMakeCertificate(SSL_CTX *context, NSString **fingerprint) {
    EC_KEY *ec = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
    EVP_PKEY *key = EVP_PKEY_new();
    X509 *certificate = X509_new();
    BOOL valid = ec && key && certificate && EC_KEY_generate_key(ec) == 1;
    if (valid && EVP_PKEY_assign_EC_KEY(key, ec) == 1) ec = NULL;
    else valid = NO;
    if (valid) {
        X509_set_version(certificate, 2);
        ASN1_INTEGER_set(X509_get_serialNumber(certificate), (long)arc4random());
        X509_gmtime_adj(X509_get_notBefore(certificate), -60);
        X509_gmtime_adj(X509_get_notAfter(certificate), 24 * 3600);
        X509_set_pubkey(certificate, key);
        X509_NAME *name = X509_get_subject_name(certificate);
        X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, (const unsigned char *)"iOS6 Telegram Call", -1, -1, 0);
        X509_set_issuer_name(certificate, name);
        valid = X509_sign(certificate, key, EVP_sha256()) > 0 &&
            SSL_CTX_use_certificate(context, certificate) == 1 &&
            SSL_CTX_use_PrivateKey(context, key) == 1;
        if (valid) *fingerprint = TGFingerprint(certificate);
        valid = valid && (*fingerprint).length > 0;
    }
    EC_KEY_free(ec); EVP_PKEY_free(key); X509_free(certificate);
    return valid;
}

// Certificate identity is checked against the SHA-256 fingerprint after the
// handshake. OpenSSL's CA verifier is not applicable to ephemeral call certs.
static int TGAcceptEphemeralCert(int preverified, X509_STORE_CTX *context) { return 1; }

@interface TGCallDTLS () {
    SSL_CTX *_context;
    SSL *_ssl;
    BOOL _caller;
    BOOL _ready;
    BOOL _started, _tlsClient;
    NSUInteger _sentPackets, _receivedPackets;
    NSTimeInterval _startedAt;
    NSMutableArray *_pendingPackets;
    NSString *_peerFingerprint;
    dispatch_source_t _timer;
    dispatch_queue_t _timerQueue;
}
@property (nonatomic, readwrite) NSString *localFingerprint;
@property (nonatomic, readwrite) NSData *outboundSRTPKey;
@property (nonatomic, readwrite) NSData *inboundSRTPKey;
@end

@implementation TGCallDTLS
- (instancetype)initWithCaller:(BOOL)caller {
    self = [super init];
    if (self) { _caller = caller; _pendingPackets = [NSMutableArray array]; }
    return self;
}
- (BOOL)prepareWithError:(NSString **)error {
    if (_ssl) return YES;
    _context = SSL_CTX_new(DTLS_method());
    NSString *generatedFingerprint = nil;
    if (!_context || !SSL_CTX_set_min_proto_version(_context, DTLS1_2_VERSION) ||
        SSL_CTX_set_tlsext_use_srtp(_context, "SRTP_AES128_CM_SHA1_80") != 0 ||
        !TGMakeCertificate(_context, &generatedFingerprint)) goto failure;
    self.localFingerprint = generatedFingerprint;
    SSL_CTX_set_verify(_context, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, TGAcceptEphemeralCert);
    _ssl = SSL_new(_context);
    if (!_ssl) goto failure;
    BIO *incoming = BIO_new(BIO_s_mem()), *outgoing = BIO_new(BIO_s_mem());
    if (!incoming || !outgoing) { BIO_free(incoming); BIO_free(outgoing); goto failure; }
    BIO_set_mem_eof_return(incoming, -1);
    SSL_set_bio(_ssl, incoming, outgoing);
    SSL_set_options(_ssl, SSL_OP_NO_QUERY_MTU);
    SSL_set_mtu(_ssl, 1200);
    if (_caller) SSL_set_connect_state(_ssl); else SSL_set_accept_state(_ssl);
    return YES;
failure:
    if (error) *error = @"Не удалось подготовить DTLS для звонка.";
    [self stop];
    return NO;
}
- (BOOL)startWithPeerFingerprint:(NSString *)fingerprint error:(NSString **)error {
    return [self startWithPeerFingerprint:fingerprint setup:@"actpass" error:error];
}
- (BOOL)startWithPeerFingerprint:(NSString *)fingerprint setup:(NSString *)setup error:(NSString **)error {
    @synchronized (self) {
    if (![fingerprint isKindOfClass:[NSString class]] || fingerprint.length != 95) {
        if (error) *error = @"Отсутствует отпечаток ключа собеседника.";
        return NO;
    }
    if (![self prepareWithError:error]) return NO;
    if (setup.length && ![setup isEqual:@"active"] && ![setup isEqual:@"passive"] && ![setup isEqual:@"actpass"]) {
        if (error) *error = @"Неподдерживаемая роль DTLS собеседника.";
        return NO;
    }
    if (_started) {
        if ([_peerFingerprint isEqual:[fingerprint uppercaseString]]) return YES;
        if (error) *error = @"Ключ собеседника изменился во время соединения.";
        return NO;
    }
    _tlsClient = [setup isEqual:@"passive"] ? YES : [setup isEqual:@"active"] ? NO : _caller;
    if (_tlsClient) SSL_set_connect_state(_ssl); else SSL_set_accept_state(_ssl);
    _peerFingerprint = [fingerprint uppercaseString];
    _started = YES; _startedAt = [NSDate timeIntervalSinceReferenceDate];
    _timerQueue = dispatch_queue_create("telegram.call-dtls-timer", DISPATCH_QUEUE_SERIAL);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _timerQueue);
    __weak TGCallDTLS *weakSelf = self;
    dispatch_source_set_event_handler(_timer, ^{
        TGCallDTLS *strongSelf = weakSelf;
        if (strongSelf) [strongSelf tick];
    });
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
                              100 * NSEC_PER_MSEC, 20 * NSEC_PER_MSEC);
    dispatch_resume(_timer);
    [self drive];
    NSArray *pending = [_pendingPackets copy]; [_pendingPackets removeAllObjects];
    for (NSData *packet in pending) {
        if (!_ssl || _ready) break;
        BIO_write(SSL_get_rbio(_ssl), packet.bytes, (int)packet.length); [self drive];
    }
    return YES;
    }
}
- (void)drainOutgoing {
    if (!_ssl) return;
    BIO *output = SSL_get_wbio(_ssl);
    uint8_t bytes[1500];
    // Memory BIOs expose a byte stream. Split it at DTLS record boundaries
    // so ICE sends complete datagrams rather than arbitrary BIO chunks.
    while (BIO_ctrl_pending(output) >= 13) {
        int header = BIO_read(output, bytes, 13);
        if (header != 13) break;
        NSUInteger bodyLength = ((NSUInteger)bytes[11] << 8) | bytes[12];
        if (bodyLength > sizeof(bytes) - 13 || BIO_ctrl_pending(output) < bodyLength) break;
        int count = BIO_read(output, bytes + 13, (int)bodyLength);
        if (count != bodyLength) break;
        _sentPackets++;
        if (self.packetHandler) self.packetHandler([NSData dataWithBytes:bytes length:13 + bodyLength]);
    }
}
- (void)drive {
    @synchronized (self) {
        if (!_ssl || !_started || _ready) return;
        int result = SSL_do_handshake(_ssl);
        int code = result == 1 ? SSL_ERROR_NONE : SSL_get_error(_ssl, result);
        [self drainOutgoing];
        if (result == 1) {
            X509 *peer = SSL_get_peer_certificate(_ssl);
            NSString *actual = TGFingerprint(peer);
            X509_free(peer);
            const SRTP_PROTECTION_PROFILE *profile = SSL_get_selected_srtp_profile(_ssl);
            if (![actual isEqual:_peerFingerprint] || !profile ||
                strcmp(profile->name, "SRTP_AES128_CM_SHA1_80") != 0) {
                if (self.readyHandler) self.readyHandler(NO, @"Отпечаток DTLS или профиль SRTP не совпал.");
                [self stop]; return;
            }
            uint8_t material[60] = {0};
            static const char label[] = "EXTRACTOR-dtls_srtp";
            if (SSL_export_keying_material(_ssl, material, sizeof(material), label, sizeof(label) - 1,
                                            NULL, 0, 0) != 1) {
                if (self.readyHandler) self.readyHandler(NO, @"Не удалось получить ключи SRTP.");
                [self stop]; return;
            }
            NSMutableData *clientKey = [NSMutableData dataWithLength:30];
            NSMutableData *serverKey = [NSMutableData dataWithLength:30];
            memcpy(clientKey.mutableBytes, material, 16);
            memcpy((uint8_t *)clientKey.mutableBytes + 16, material + 32, 14);
            memcpy(serverKey.mutableBytes, material + 16, 16);
            memcpy((uint8_t *)serverKey.mutableBytes + 16, material + 46, 14);
            OPENSSL_cleanse(material, sizeof(material));
            self.outboundSRTPKey = _tlsClient ? clientKey : serverKey;
            self.inboundSRTPKey = _tlsClient ? serverKey : clientKey;
            _ready = YES;
            if (self.readyHandler) self.readyHandler(YES, nil);
        } else {
            if (code != SSL_ERROR_WANT_READ && code != SSL_ERROR_WANT_WRITE) {
                if (self.readyHandler) self.readyHandler(NO, @"Ошибка DTLS-соединения.");
                [self stop];
            }
        }
    }
}
- (void)receivePacket:(NSData *)packet {
    if (!packet.length || packet.length > 1500) return;
    @synchronized (self) {
        if (!_ssl || _ready) return;
        _receivedPackets++;
        if (!_started) {
            if (_pendingPackets.count < 16) [_pendingPackets addObject:[packet copy]];
            return;
        }
        BIO_write(SSL_get_rbio(_ssl), packet.bytes, (int)packet.length);
        [self drive];
    }
}
- (void)tick {
    @synchronized (self) {
        if (!_ssl || _ready) return;
        if (_started && [NSDate timeIntervalSinceReferenceDate] - _startedAt >= 25) {
            if (self.readyHandler) self.readyHandler(NO, [@"Не завершён обмен ключами. " stringByAppendingString:[self diagnostics]]);
            [self stop]; return;
        }
        struct timeval timeout;
        if (DTLSv1_get_timeout(_ssl, &timeout) == 1 && timeout.tv_sec == 0 && timeout.tv_usec == 0) {
            DTLSv1_handle_timeout(_ssl);
            [self drainOutgoing];
        }
    }
}
- (NSString *)diagnostics {
    @synchronized (self) {
        return [NSString stringWithFormat:@"DTLS %@ ↑%lu ↓%lu · %@", _started ? (_tlsClient ? @"client" : @"server") : @"ожидание",
            (unsigned long)_sentPackets, (unsigned long)_receivedPackets,
            _ssl ? [NSString stringWithUTF8String:SSL_state_string_long(_ssl)] : @"остановлен"];
    }
}
- (void)stop {
    @synchronized (self) {
        if (_timer) { dispatch_source_cancel(_timer); _timer = nil; }
        if (_ssl) { SSL_free(_ssl); _ssl = NULL; }
        if (_context) { SSL_CTX_free(_context); _context = NULL; }
        if ([_outboundSRTPKey isKindOfClass:[NSMutableData class]])
            OPENSSL_cleanse(((NSMutableData *)_outboundSRTPKey).mutableBytes, _outboundSRTPKey.length);
        if ([_inboundSRTPKey isKindOfClass:[NSMutableData class]])
            OPENSSL_cleanse(((NSMutableData *)_inboundSRTPKey).mutableBytes, _inboundSRTPKey.length);
        self.outboundSRTPKey = nil; self.inboundSRTPKey = nil; _ready = NO; _started = NO;
        [_pendingPackets removeAllObjects]; _peerFingerprint = nil;
    }
}
- (void)dealloc { [self stop]; }
@end
