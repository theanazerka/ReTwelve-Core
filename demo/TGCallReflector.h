#import <Foundation/Foundation.h>

@interface TGCallReflector : NSObject
@property (nonatomic, copy) void (^candidateHandler)(NSString *candidate);
@property (nonatomic, copy) void (^stateHandler)(NSString *state);
@property (nonatomic, copy) void (^packetHandler)(NSData *packet);
- (instancetype)initWithEndpoint:(NSDictionary *)endpoint localDescription:(NSString *)description caller:(BOOL)caller;
- (BOOL)start;
// Counters only: no addresses, credentials or call keys.
- (NSDictionary *)diagnostics;
- (BOOL)setRemoteDescription:(NSString *)description;
- (BOOL)addRemoteCandidate:(NSString *)candidate;
- (BOOL)sendPacket:(NSData *)packet;
- (void)stop;
@end
