#import <Foundation/Foundation.h>

// DTLS-SRTP key exchange over an ICE datagram channel. Incoming fingerprint
// must come from the authenticated Telegram call signaling message.
@interface TGCallDTLS : NSObject
@property (nonatomic, readonly) NSString *localFingerprint;
@property (nonatomic, readonly) NSData *outboundSRTPKey;
@property (nonatomic, readonly) NSData *inboundSRTPKey;
@property (nonatomic, copy) void (^packetHandler)(NSData *packet);
@property (nonatomic, copy) void (^readyHandler)(BOOL ready, NSString *error);
- (instancetype)initWithCaller:(BOOL)caller;
- (BOOL)prepareWithError:(NSString **)error;
- (BOOL)startWithPeerFingerprint:(NSString *)fingerprint error:(NSString **)error;
- (BOOL)startWithPeerFingerprint:(NSString *)fingerprint setup:(NSString *)setup error:(NSString **)error;
- (NSString *)diagnostics;
- (void)receivePacket:(NSData *)packet;
- (void)stop;
@end
