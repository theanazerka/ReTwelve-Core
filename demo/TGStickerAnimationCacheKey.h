#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

// rlottie caches parsed models by this key, including across decoder calls.
static inline NSString *TGStickerAnimationCacheKey(const void *bytes, NSUInteger length) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes, (CC_LONG)length, digest);
    NSMutableString *key = [NSMutableString stringWithString:@"ios6-sticker-"];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [key appendFormat:@"%02x", digest[i]];
    return key;
}
