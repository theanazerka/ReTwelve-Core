#import <Foundation/Foundation.h>

// Blocking MTProto abridged TCP transport. Use from a dedicated worker thread.
@interface TGIOS3Transport : NSObject {
@private
    int _socket;
}
- (BOOL)connectToHost:(NSString *)host port:(NSUInteger)port timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)sendPayload:(NSData *)payload timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSData *)readPayloadWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (void)close;
@end
