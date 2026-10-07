#import <Foundation/Foundation.h>

// Raw packet encryption used by modern Telegram calls. One instance per call
// and channel; media still needs Telegram's message/ack framing before use.
@interface TGCallCipher : NSObject
- (instancetype)initWithKey:(NSData *)key caller:(BOOL)caller signaling:(BOOL)signaling;
- (NSData *)encrypt:(NSData *)payload;
- (NSData *)decrypt:(NSData *)packet;
@end
