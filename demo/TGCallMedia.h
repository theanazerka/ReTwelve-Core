#import <Foundation/Foundation.h>
@class TGClient;

// One audio-only call media session. Must be created after Telegram DH verification.
@interface TGCallMedia : NSObject
@property (nonatomic, copy) void (^stateHandler)(NSString *state, NSString *error);
- (instancetype)initWithClient:(TGClient *)client call:(NSDictionary *)call
                           key:(NSData *)key caller:(BOOL)caller;
- (BOOL)start:(NSString **)error;
- (void)receiveSignalingPacket:(NSData *)data;
- (void)stop;
@end
