#import <Foundation/Foundation.h>

// Native ICE transport for the WebRTC-style endpoints in phoneCall.connections.
@interface TGCallICE : NSObject
@property (nonatomic, copy) void (^stateHandler)(NSString *state);
@property (nonatomic, copy) void (^candidateHandler)(NSString *candidate);
@property (nonatomic, copy) void (^packetHandler)(NSData *packet);
- (instancetype)initWithConnections:(NSArray *)connections caller:(BOOL)caller;
- (BOOL)start:(NSString **)error;
- (NSString *)localDescription;
- (NSString *)transportDiagnostics;
- (BOOL)setRemoteDescription:(NSString *)description;
- (BOOL)addRemoteCandidate:(NSString *)candidate;
- (BOOL)sendPacket:(NSData *)packet;
- (void)stop;
@end
