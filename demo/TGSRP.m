#import "TGSRP.h"
#import <MtProtoKit/MTOutputStream.h>
#import <Security/Security.h>
#import <openssl/bn.h>
#import <openssl/evp.h>
#import <openssl/sha.h>

static NSData *TGHash(NSData *data) {
    uint8_t digest[SHA256_DIGEST_LENGTH];
    SHA256(data.bytes, data.length, digest);
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}
static NSData *TGJoin(NSArray *parts) {
    NSMutableData *result = [NSMutableData data];
    for (NSData *part in parts) [result appendData:part];
    return result;
}
static NSData *TGSalted(NSData *data, NSData *salt) {
    return TGHash(TGJoin(@[salt, data, salt]));
}
static NSData *TGPad(const BIGNUM *n) {
    if (BN_num_bytes(n) > 256) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:256];
    BN_bn2bin(n, (uint8_t *)data.mutableBytes + 256 - BN_num_bytes(n));
    return data;
}

@implementation TGSRP
+ (NSDictionary *)newPasswordSettings:(NSString *)password algorithm:(NSDictionary *)algorithm error:(NSString **)error {
    NSString *type = @"passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow";
    NSData *salt1 = algorithm[@"salt1"], *salt2 = algorithm[@"salt2"], *prime = algorithm[@"p"];
    NSInteger generator = [algorithm[@"g"] integerValue];
    if (![algorithm[@"_"] isEqual:type] || ![salt1 isKindOfClass:[NSData class]] || ![salt2 isKindOfClass:[NSData class]] || prime.length != 256 || generator < 2 || generator > 7 || !password.length) { if (error) *error = @"Неподдерживаемые параметры нового пароля."; return nil; }
    uint8_t random[32], pbkdf[64];
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(random), random) != errSecSuccess) { if (error) *error = @"Не удалось получить случайные данные."; return nil; }
    NSMutableData *nextSalt = [salt1 mutableCopy]; [nextSalt appendBytes:random length:32]; memset(random, 0, sizeof(random));
    NSData *inner = TGSalted(TGSalted([password dataUsingEncoding:NSUTF8StringEncoding], nextSalt), salt2);
    if (PKCS5_PBKDF2_HMAC(inner.bytes, (int)inner.length, nextSalt.bytes, (int)nextSalt.length, 100000, EVP_sha512(), 64, pbkdf) != 1) { if (error) *error = @"Не удалось вычислить новый пароль."; return nil; }
    NSData *xHash = TGSalted([NSData dataWithBytes:pbkdf length:64], salt2); memset(pbkdf, 0, sizeof(pbkdf));
    BN_CTX *context = BN_CTX_new(); BIGNUM *p = BN_bin2bn(prime.bytes, 256, NULL), *g = BN_new(), *q = BN_new(), *x = BN_bin2bn(xHash.bytes, 32, NULL), *verifier = BN_new();
    NSData *hash = nil;
    if (context && p && g && q && x && verifier && BN_num_bits(p) == 2048 && BN_is_odd(p) && BN_copy(q, p) && BN_sub_word(q, 1) && BN_rshift1(q, q) && BN_is_prime_ex(p, 16, context, NULL) == 1 && BN_is_prime_ex(q, 16, context, NULL) == 1) {
        BN_ULONG remainder = BN_mod_word(p, (BN_ULONG)(4 * generator));
        BOOL valid = (generator == 2 && remainder % 8 == 7) || (generator == 3 && remainder % 3 == 2) || generator == 4 || (generator == 5 && (remainder % 5 == 1 || remainder % 5 == 4)) || (generator == 6 && (remainder % 24 == 19 || remainder % 24 == 23)) || (generator == 7 && (remainder % 7 == 3 || remainder % 7 == 5 || remainder % 7 == 6));
        if (valid && BN_set_word(g, generator) && BN_mod_exp(verifier, g, x, p, context)) hash = TGPad(verifier);
    }
    BN_clear_free(p); BN_clear_free(g); BN_clear_free(q); BN_clear_free(x); BN_clear_free(verifier); BN_CTX_free(context);
    if (!hash) { if (error) *error = @"Не удалось проверить параметры нового пароля."; return nil; }
    NSMutableDictionary *nextAlgorithm = [algorithm mutableCopy]; nextAlgorithm[@"salt1"] = nextSalt;
    return @{ @"algo": nextAlgorithm, @"hash": hash };
}
+ (NSData *)proofForPassword:(NSString *)password configuration:(NSDictionary *)configuration error:(NSString **)error {
    NSDictionary *algo = configuration[@"current_algo"];
    NSData *salt1 = algo[@"salt1"], *salt2 = algo[@"salt2"];
    NSData *pBytes = algo[@"p"], *bBytes = configuration[@"srp_B"];
    NSNumber *gValue = algo[@"g"], *srpId = configuration[@"srp_id"];
    if (![algo[@"_"] isEqual:@"passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow"] ||
        ![salt1 isKindOfClass:[NSData class]] || ![salt2 isKindOfClass:[NSData class]] ||
        pBytes.length != 256 || bBytes.length != 256 || !gValue || !srpId) {
        if (error) *error = @"Telegram прислал неподдерживаемые параметры 2FA.";
        return nil;
    }
    int gInt = gValue.intValue;
    if (gInt < 2 || gInt > 7) { if (error) *error = @"Неверный генератор SRP."; return nil; }
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *p = BN_bin2bn(pBytes.bytes, (int)pBytes.length, NULL);
    BIGNUM *g = BN_new(), *b = BN_bin2bn(bBytes.bytes, (int)bBytes.length, NULL);
    BIGNUM *q = BN_new(), *a = BN_new(), *A = BN_new(), *k = BN_new(), *u = BN_new();
    BIGNUM *x = BN_new(), *v = BN_new(), *kv = BN_new(), *t = BN_new(), *exp = BN_new(), *s = BN_new();
    NSData *result = nil;
    NSData *aBytes = nil, *gBytes = nil, *kHash = nil, *uHash = nil;
    NSData *passwordBytes = nil, *first = nil, *xHash = nil, *key = nil;
    NSData *hp = nil, *hg = nil, *m1 = nil;
    MTOutputStream *stream = nil;
    uint8_t randomness[256] = {0}, pbkdf[64] = {0}, xorHash[32] = {0};
    BN_set_word(g, (BN_ULONG)gInt);
    if (!ctx || BN_num_bits(p) != 2048 || BN_is_odd(p) == 0 ||
        !BN_copy(q, p) || !BN_sub_word(q, 1) || !BN_rshift1(q, q) ||
        BN_is_prime_ex(p, 16, ctx, NULL) != 1 || BN_is_prime_ex(q, 16, ctx, NULL) != 1) goto done;
    BN_ULONG remainder = BN_mod_word(p, (BN_ULONG)(4 * gInt));
    BOOL generatorOK = (gInt == 2 && remainder % 8 == 7) || (gInt == 3 && remainder % 3 == 2) ||
        (gInt == 4) || (gInt == 5 && (remainder % 5 == 1 || remainder % 5 == 4)) ||
        (gInt == 6 && (remainder % 24 == 19 || remainder % 24 == 23)) ||
        (gInt == 7 && (remainder % 7 == 3 || remainder % 7 == 5 || remainder % 7 == 6));
    if (!generatorOK || BN_is_zero(b) || BN_is_one(b) || BN_cmp(b, p) >= 0) goto done;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomness), randomness) != errSecSuccess) goto done;
    BN_bin2bn(randomness, sizeof(randomness), a);
    memset(randomness, 0, sizeof(randomness));
    if (!BN_mod_exp(A, g, a, p, ctx)) goto done;
    aBytes = TGPad(A); gBytes = TGPad(g);
    if (!aBytes || !gBytes || BN_is_one(A)) goto done;
    kHash = TGHash(TGJoin(@[pBytes, gBytes]));
    uHash = TGHash(TGJoin(@[aBytes, bBytes]));
    BN_bin2bn(kHash.bytes, (int)kHash.length, k);
    BN_bin2bn(uHash.bytes, (int)uHash.length, u);
    if (BN_is_zero(u)) goto done;
    passwordBytes = [password dataUsingEncoding:NSUTF8StringEncoding];
    first = TGSalted(TGSalted(passwordBytes, salt1), salt2);
    if (PKCS5_PBKDF2_HMAC(first.bytes, (int)first.length, salt1.bytes, (int)salt1.length,
                          100000, EVP_sha512(), sizeof(pbkdf), pbkdf) != 1) goto done;
    xHash = TGSalted([NSData dataWithBytes:pbkdf length:sizeof(pbkdf)], salt2);
    memset(pbkdf, 0, sizeof(pbkdf));
    BN_bin2bn(xHash.bytes, (int)xHash.length, x);
    if (!BN_mod_exp(v, g, x, p, ctx) || !BN_mod_mul(kv, k, v, p, ctx) ||
        !BN_mod_sub(t, b, kv, p, ctx) || BN_is_zero(t) ||
        !BN_mul(exp, u, x, ctx) || !BN_add(exp, exp, a) || !BN_mod_exp(s, t, exp, p, ctx)) goto done;
    key = TGHash(TGPad(s));
    hp = TGHash(pBytes); hg = TGHash(gBytes);
    for (NSUInteger i = 0; i < 32; i++) xorHash[i] = ((const uint8_t *)hp.bytes)[i] ^ ((const uint8_t *)hg.bytes)[i];
    m1 = TGHash(TGJoin(@[[NSData dataWithBytes:xorHash length:32], TGHash(salt1), TGHash(salt2), aBytes, bBytes, key]));
    stream = [[MTOutputStream alloc] init];
    [stream writeInt32:(int32_t)0xd27ff082];
    [stream writeInt64:srpId.longLongValue];
    [stream writeBytes:aBytes];
    [stream writeBytes:m1];
    result = [stream currentBytes];
done:
    if (!result && error) *error = @"Не удалось вычислить безопасное доказательство SRP.";
    BN_clear_free(p); BN_clear_free(g); BN_clear_free(b); BN_clear_free(q); BN_clear_free(a);
    BN_clear_free(A); BN_clear_free(k); BN_clear_free(u); BN_clear_free(x); BN_clear_free(v);
    BN_clear_free(kv); BN_clear_free(t); BN_clear_free(exp); BN_clear_free(s); BN_CTX_free(ctx);
    return result;
}
@end
