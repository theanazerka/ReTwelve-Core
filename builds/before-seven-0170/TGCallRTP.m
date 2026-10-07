#import "TGCallRTP.h"
#import <srtp.h>
#import <Security/Security.h>
#import <openssl/crypto.h>

@interface TGCallRTP () {
    srtp_t _send;
    srtp_t _receive;
    NSMutableData *_sendKey;
    NSMutableData *_receiveKey;
    uint16_t _sequence;
    uint32_t _timestamp;
    uint8_t _sendPayloadType, _receivePayloadType;
}
@property (nonatomic, readwrite) uint32_t localSSRC;
@property (nonatomic, readwrite) uint32_t remoteSSRC;
@end

@implementation TGCallRTP
- (instancetype)initWithLocalSSRC:(uint32_t)localSSRC remoteSSRC:(uint32_t)remoteSSRC
                    outboundKey:(NSData *)outboundKey inboundKey:(NSData *)inboundKey
                sendPayloadType:(uint8_t)sendPayloadType receivePayloadType:(uint8_t)receivePayloadType {
    if (!localSSRC || !remoteSSRC || outboundKey.length != 30 || inboundKey.length != 30 ||
        sendPayloadType > 127 || receivePayloadType > 127)
        return nil;
    self = [super init];
    if (!self) return nil;
    _localSSRC = localSSRC; _remoteSSRC = remoteSSRC;
    _sendPayloadType = sendPayloadType; _receivePayloadType = receivePayloadType;
    _sendKey = [outboundKey mutableCopy]; _receiveKey = [inboundKey mutableCopy];
    uint8_t random[6];
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(random), random) != errSecSuccess) return nil;
    _sequence = ((uint16_t)random[0] << 8) | random[1];
    _timestamp = ((uint32_t)random[2] << 24) | ((uint32_t)random[3] << 16) |
                 ((uint32_t)random[4] << 8) | random[5];
    static dispatch_once_t once;
    static srtp_err_status_t initialization;
    dispatch_once(&once, ^{ initialization = srtp_init(); });
    if (initialization != srtp_err_status_ok) return nil;
    srtp_err_status_t status;
    srtp_policy_t policy = {0};
    srtp_crypto_policy_set_aes_cm_128_hmac_sha1_80(&policy.rtp);
    srtp_crypto_policy_set_rtcp_default(&policy.rtcp);
    policy.ssrc.type = ssrc_specific; policy.ssrc.value = localSSRC;
    policy.key = _sendKey.mutableBytes; policy.window_size = 128;
    status = srtp_create(&_send, &policy);
    if (status != srtp_err_status_ok) { [self stop]; return nil; }
    memset(&policy, 0, sizeof(policy));
    srtp_crypto_policy_set_aes_cm_128_hmac_sha1_80(&policy.rtp);
    srtp_crypto_policy_set_rtcp_default(&policy.rtcp);
    policy.ssrc.type = ssrc_specific; policy.ssrc.value = remoteSSRC;
    policy.key = _receiveKey.mutableBytes; policy.window_size = 128;
    status = srtp_create(&_receive, &policy);
    if (status != srtp_err_status_ok) { [self stop]; return nil; }
    return self;
}
- (NSData *)protectOpus:(NSData *)opus {
    if (!_send || !opus.length || opus.length > 1200) return nil;
    @synchronized (self) {
        uint32_t words[(12 + 1200 + SRTP_MAX_TRAILER_LEN + 3) / 4] = {0};
        uint8_t *bytes = (uint8_t *)words;
        bytes[0] = 0x80; bytes[1] = _sendPayloadType;
        bytes[2] = _sequence >> 8; bytes[3] = _sequence;
        bytes[4] = _timestamp >> 24; bytes[5] = _timestamp >> 16;
        bytes[6] = _timestamp >> 8; bytes[7] = _timestamp;
        bytes[8] = _localSSRC >> 24; bytes[9] = _localSSRC >> 16;
        bytes[10] = _localSSRC >> 8; bytes[11] = _localSSRC;
        memcpy(bytes + 12, opus.bytes, opus.length);
        int count = (int)(12 + opus.length);
        if (srtp_protect(_send, bytes, &count) != srtp_err_status_ok) return nil;
        _sequence++; _timestamp += 960;
        return [NSData dataWithBytes:bytes length:count];
    }
}
- (NSData *)unprotectOpus:(NSData *)packet {
    if (!_receive || packet.length < 22 || packet.length > 1500) return nil;
    @synchronized (self) {
        uint32_t words[(1500 + 3) / 4] = {0};
        uint8_t *bytes = (uint8_t *)words;
        memcpy(bytes, packet.bytes, packet.length);
        int count = (int)packet.length;
        if (srtp_unprotect(_receive, bytes, &count) != srtp_err_status_ok || count < 12) return nil;
        if ((bytes[0] >> 6) != 2 || (bytes[1] & 0x7f) != _receivePayloadType) return nil;
        uint32_t ssrc = ((uint32_t)bytes[8] << 24) | ((uint32_t)bytes[9] << 16) |
                        ((uint32_t)bytes[10] << 8) | bytes[11];
        if (ssrc != _remoteSSRC) return nil;
        NSUInteger offset = 12 + 4 * (bytes[0] & 0x0f);
        if (offset > count) return nil;
        if (bytes[0] & 0x10) {
            if (offset + 4 > count) return nil;
            NSUInteger extensionWords = ((NSUInteger)bytes[offset + 2] << 8) | bytes[offset + 3];
            offset += 4 + extensionWords * 4;
            if (offset > count) return nil;
        }
        if (bytes[0] & 0x20) {
            uint8_t padding = bytes[count - 1];
            if (!padding || padding > count - offset) return nil;
            count -= padding;
        }
        if (offset >= count) return nil;
        return [NSData dataWithBytes:bytes + offset length:count - offset];
    }
}
- (void)stop {
    @synchronized (self) {
        if (_send) { srtp_dealloc(_send); _send = NULL; }
        if (_receive) { srtp_dealloc(_receive); _receive = NULL; }
        if (_sendKey) OPENSSL_cleanse(_sendKey.mutableBytes, _sendKey.length);
        if (_receiveKey) OPENSSL_cleanse(_receiveKey.mutableBytes, _receiveKey.length);
        _sendKey = nil; _receiveKey = nil;
    }
}
- (void)dealloc { [self stop]; }
@end
