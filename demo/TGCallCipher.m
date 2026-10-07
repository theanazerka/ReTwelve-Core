#import "TGCallCipher.h"
#import <openssl/evp.h>
#import <openssl/sha.h>
#import <openssl/crypto.h>

static void TGCallSHA256(NSData *first, NSData *second, uint8_t digest[32]) {
    SHA256_CTX context;
    SHA256_Init(&context);
    SHA256_Update(&context, first.bytes, first.length);
    SHA256_Update(&context, second.bytes, second.length);
    SHA256_Final(digest, &context);
}

static void TGCallAESParameters(const uint8_t *key, const uint8_t *messageKey, int x,
                                uint8_t aesKey[32], uint8_t iv[16]) {
    uint8_t a[32], b[32];
    TGCallSHA256([NSData dataWithBytesNoCopy:(void *)messageKey length:16 freeWhenDone:NO],
                 [NSData dataWithBytesNoCopy:(void *)(key + x) length:36 freeWhenDone:NO], a);
    TGCallSHA256([NSData dataWithBytesNoCopy:(void *)(key + 40 + x) length:36 freeWhenDone:NO],
                 [NSData dataWithBytesNoCopy:(void *)messageKey length:16 freeWhenDone:NO], b);
    memcpy(aesKey, a, 8); memcpy(aesKey + 8, b + 8, 16); memcpy(aesKey + 24, a + 24, 8);
    memcpy(iv, b, 4); memcpy(iv + 4, a + 8, 8); memcpy(iv + 12, b + 24, 4);
    OPENSSL_cleanse(a, sizeof(a)); OPENSSL_cleanse(b, sizeof(b));
}

static NSData *TGCallAESCTR(NSData *bytes, const uint8_t key[32], const uint8_t iv[16]) {
    EVP_CIPHER_CTX *context = EVP_CIPHER_CTX_new();
    if (!context) return nil;
    NSMutableData *output = [NSMutableData dataWithLength:bytes.length];
    int count = 0, finalCount = 0;
    BOOL valid = EVP_EncryptInit_ex(context, EVP_aes_256_ctr(), NULL, key, iv) == 1 &&
        EVP_EncryptUpdate(context, output.mutableBytes, &count, bytes.bytes, (int)bytes.length) == 1 &&
        EVP_EncryptFinal_ex(context, (uint8_t *)output.mutableBytes + count, &finalCount) == 1 &&
        count + finalCount == bytes.length;
    EVP_CIPHER_CTX_free(context);
    return valid ? output : nil;
}

@implementation TGCallCipher {
    NSMutableData *_key;
    int _outX, _inX;
    uint32_t _sendSequence;
    uint32_t _highestReceived;
    uint64_t _receivedWindow;
}
- (instancetype)initWithKey:(NSData *)key caller:(BOOL)caller signaling:(BOOL)signaling {
    if (key.length != 256) return nil;
    self = [super init];
    if (self) {
        _key = [key mutableCopy];
        _outX = (caller ? 0 : 8) + (signaling ? 128 : 0);
        _inX = (caller ? 8 : 0) + (signaling ? 128 : 0);
    }
    return self;
}
- (NSData *)encrypt:(NSData *)payload {
    if (!payload || payload.length > 65536) return nil;
    @synchronized (self) {
        if (_sendSequence >= 0x3fffffff) return nil;
        uint32_t sequence = ++_sendSequence;
        uint8_t prefix[4] = { (uint8_t)(sequence >> 24), (uint8_t)(sequence >> 16),
                              (uint8_t)(sequence >> 8), (uint8_t)sequence };
        NSMutableData *plaintext = [NSMutableData dataWithBytes:prefix length:4];
        [plaintext appendData:payload];
        uint8_t hash[32], aesKey[32], iv[16];
        const uint8_t *key = _key.bytes;
        TGCallSHA256([NSData dataWithBytesNoCopy:(void *)(key + 88 + _outX) length:32 freeWhenDone:NO], plaintext, hash);
        TGCallAESParameters(key, hash + 8, _outX, aesKey, iv);
        NSData *encrypted = TGCallAESCTR(plaintext, aesKey, iv);
        NSMutableData *packet = encrypted ? [NSMutableData dataWithBytes:hash + 8 length:16] : nil;
        if (packet) [packet appendData:encrypted];
        OPENSSL_cleanse(hash, sizeof(hash)); OPENSSL_cleanse(aesKey, sizeof(aesKey));
        OPENSSL_cleanse(iv, sizeof(iv));
        return packet;
    }
}
- (NSData *)decrypt:(NSData *)packet {
    if (packet.length < 20 || packet.length > 65556) return nil;
    @synchronized (self) {
        const uint8_t *bytes = packet.bytes, *key = _key.bytes;
        uint8_t aesKey[32], iv[16], hash[32];
        TGCallAESParameters(key, bytes, _inX, aesKey, iv);
        NSData *ciphertext = [packet subdataWithRange:NSMakeRange(16, packet.length - 16)];
        NSData *plaintext = TGCallAESCTR(ciphertext, aesKey, iv);
        OPENSSL_cleanse(aesKey, sizeof(aesKey)); OPENSSL_cleanse(iv, sizeof(iv));
        if (!plaintext || plaintext.length < 4) return nil;
        TGCallSHA256([NSData dataWithBytesNoCopy:(void *)(key + 88 + _inX) length:32 freeWhenDone:NO], plaintext, hash);
        BOOL authentic = CRYPTO_memcmp(hash + 8, bytes, 16) == 0;
        OPENSSL_cleanse(hash, sizeof(hash));
        if (!authentic) return nil;
        const uint8_t *plain = plaintext.bytes;
        uint32_t sequence = ((uint32_t)plain[0] << 24) | ((uint32_t)plain[1] << 16) |
                            ((uint32_t)plain[2] << 8) | plain[3];
        if (sequence == 0 || sequence >= 0x40000000) return nil;
        if (sequence > _highestReceived) {
            uint32_t shift = sequence - _highestReceived;
            _receivedWindow = shift >= 64 ? 1 : (_receivedWindow << shift) | 1;
            _highestReceived = sequence;
        } else {
            uint32_t distance = _highestReceived - sequence;
            if (distance >= 64 || (_receivedWindow & ((uint64_t)1 << distance))) return nil;
            _receivedWindow |= (uint64_t)1 << distance;
        }
        return [plaintext subdataWithRange:NSMakeRange(4, plaintext.length - 4)];
    }
}
- (void)dealloc { if (_key) OPENSSL_cleanse(_key.mutableBytes, _key.length); }
@end
