#import <Foundation/Foundation.h>

// One ephemeral Diffie-Hellman exchange for a Telegram phone call.
// Keep this object only in memory for the lifetime of the call.
@interface TGCallCrypto : NSObject
@property (nonatomic, readonly) NSData *publicValue;
@property (nonatomic, readonly) NSData *publicHash;
@property (nonatomic, readonly) NSData *key;
@property (nonatomic, readonly) int64_t keyFingerprint;
- (instancetype)initWithPrime:(NSData *)prime generator:(int32_t)generator error:(NSString **)error;
- (BOOL)finishWithPeerValue:(NSData *)peerValue expectedHash:(NSData *)expectedHash
                   fingerprint:(NSNumber *)fingerprint error:(NSString **)error;
@end
