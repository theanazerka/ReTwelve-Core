#import <Foundation/Foundation.h>

@interface TGIOS3Handshake : NSObject
// Starts auth-key negotiation and validates the resPQ response. Blocking call.
- (NSDictionary *)requestPQAtHost:(NSString *)host port:(NSUInteger)port
    timeout:(NSTimeInterval)timeout error:(NSError **)error;
@end
