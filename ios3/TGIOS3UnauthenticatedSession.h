#import <Foundation/Foundation.h>

@class TGIOS3Transport;

// First MTProto 2.0 exchange, before an auth key exists. Blocking calls.
@interface TGIOS3UnauthenticatedSession : NSObject {
@private
    TGIOS3Transport *_transport;
    uint64_t _lastMessageId;
}
- (BOOL)connectToHost:(NSString *)host port:(NSUInteger)port timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)sendTLBody:(NSData *)body timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSData *)readTLBodyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (void)close;
@end
