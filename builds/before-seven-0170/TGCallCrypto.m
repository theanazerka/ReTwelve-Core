#import "TGCallCrypto.h"
#import <Security/Security.h>
#import <openssl/bn.h>
#import <openssl/crypto.h>
#import <openssl/sha.h>

static NSData *TGCallPad(const BIGNUM *number) {
    int count = BN_num_bytes(number);
    if (count < 1 || count > 256) return nil;
    NSMutableData *result = [NSMutableData dataWithLength:256];
    BN_bn2bin(number, (uint8_t *)result.mutableBytes + 256 - count);
    return result;
}

static BOOL TGCallValidPublic(const BIGNUM *value, const BIGNUM *prime, BN_CTX *context) {
    if (!value || !prime || !context || BN_is_negative(value) || BN_is_zero(value) || BN_is_one(value)) return NO;
    BIGNUM *bound = BN_new(), *upper = BN_new();
    BOOL valid = bound && upper && BN_one(bound) && BN_lshift(bound, bound, 1984) &&
        BN_sub(upper, prime, bound) && BN_cmp(value, bound) > 0 && BN_cmp(value, upper) < 0;
    BN_clear_free(bound); BN_clear_free(upper);
    return valid;
}

@implementation TGCallCrypto {
    BIGNUM *_secret;
    NSData *_prime;
}
- (instancetype)initWithPrime:(NSData *)prime generator:(int32_t)generator error:(NSString **)error {
    self = [super init];
    if (!self) return nil;
    BOOL valid = NO;
    BN_CTX *context = BN_CTX_new();
    BIGNUM *p = prime.length == 256 ? BN_bin2bn(prime.bytes, (int)prime.length, NULL) : NULL;
    BIGNUM *q = BN_new(), *g = BN_new(), *public = BN_new();
    uint8_t random[256] = {0};
    if (!context || !p || !q || !g || !public || generator < 2 || generator > 7 ||
        BN_num_bits(p) != 2048 || !BN_is_odd(p) || !BN_copy(q, p) ||
        !BN_sub_word(q, 1) || !BN_rshift1(q, q) ||
        BN_is_prime_ex(p, 32, context, NULL) != 1 || BN_is_prime_ex(q, 32, context, NULL) != 1 ||
        !BN_set_word(g, (BN_ULONG)generator)) goto done;
    BN_ULONG residue = BN_mod_word(p, (BN_ULONG)(4 * generator));
    BOOL generatorValid = (generator == 2 && residue % 8 == 7) ||
        (generator == 3 && residue % 3 == 2) || generator == 4 ||
        (generator == 5 && (residue % 5 == 1 || residue % 5 == 4)) ||
        (generator == 6 && (residue % 24 == 19 || residue % 24 == 23)) ||
        (generator == 7 && (residue % 7 == 3 || residue % 7 == 5 || residue % 7 == 6));
    if (!generatorValid || SecRandomCopyBytes(kSecRandomDefault, sizeof(random), random) != errSecSuccess) goto done;
    _secret = BN_bin2bn(random, sizeof(random), NULL);
    memset(random, 0, sizeof(random));
    if (!_secret || !BN_mod(_secret, _secret, q, context) || BN_is_zero(_secret) || BN_is_one(_secret) ||
        !BN_mod_exp(public, g, _secret, p, context) || !TGCallValidPublic(public, p, context)) goto done;
    _publicValue = TGCallPad(public);
    if (!_publicValue) goto done;
    uint8_t digest[SHA256_DIGEST_LENGTH];
    SHA256(_publicValue.bytes, _publicValue.length, digest);
    _publicHash = [NSData dataWithBytes:digest length:sizeof(digest)];
    _prime = [prime copy];
    valid = YES;
done:
    memset(random, 0, sizeof(random));
    BN_clear_free(p); BN_clear_free(q); BN_clear_free(g); BN_clear_free(public); BN_CTX_free(context);
    if (!valid) {
        BN_clear_free(_secret); _secret = NULL;
        if (error) *error = @"Небезопасные параметры обмена ключом звонка.";
        return nil;
    }
    return self;
}
- (BOOL)finishWithPeerValue:(NSData *)peerValue expectedHash:(NSData *)expectedHash
                   fingerprint:(NSNumber *)fingerprint error:(NSString **)error {
    if (_key || !_secret || peerValue.length != 256 || (expectedHash && expectedHash.length != 32)) {
        if (error) *error = @"Некорректное состояние ключа звонка.";
        return NO;
    }
    if (expectedHash) {
        uint8_t hash[SHA256_DIGEST_LENGTH];
        SHA256(peerValue.bytes, peerValue.length, hash);
        unsigned int mismatch = 0;
        const uint8_t *expected = expectedHash.bytes;
        for (NSUInteger i = 0; i < sizeof(hash); i++) mismatch |= hash[i] ^ expected[i];
        if (mismatch) { if (error) *error = @"Ключ собеседника не совпал с подтверждением."; return NO; }
    }
    BN_CTX *context = BN_CTX_new();
    BIGNUM *p = BN_bin2bn(_prime.bytes, (int)_prime.length, NULL);
    BIGNUM *peer = BN_bin2bn(peerValue.bytes, (int)peerValue.length, NULL);
    BIGNUM *shared = BN_new();
    BOOL valid = context && p && peer && shared && TGCallValidPublic(peer, p, context) &&
        BN_mod_exp(shared, peer, _secret, p, context) && BN_cmp(shared, BN_value_one()) > 0;
    NSData *key = valid ? TGCallPad(shared) : nil;
    uint8_t digest[SHA_DIGEST_LENGTH] = {0};
    if (key) {
        SHA1(key.bytes, key.length, digest);
        uint64_t value = 0;
        for (NSUInteger i = 0; i < 8; i++) value |= ((uint64_t)digest[12 + i]) << (8 * i);
        if (fingerprint && value != (uint64_t)[fingerprint longLongValue]) valid = NO;
        else { _key = key; _keyFingerprint = (int64_t)value; }
    } else valid = NO;
    memset(digest, 0, sizeof(digest));
    BN_clear_free(p); BN_clear_free(peer); BN_clear_free(shared); BN_CTX_free(context);
    if (valid) { BN_clear_free(_secret); _secret = NULL; }
    else if (key) OPENSSL_cleanse(((NSMutableData *)key).mutableBytes, key.length);
    if (!valid && error) *error = @"Не прошла проверка ключа звонка.";
    return valid;
}
- (void)dealloc {
    BN_clear_free(_secret);
    if (_key) OPENSSL_cleanse(((NSMutableData *)_key).mutableBytes, _key.length);
}
@end
