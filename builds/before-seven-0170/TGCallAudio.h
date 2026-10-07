#import <Foundation/Foundation.h>

// Duplex 48 kHz mono Opus audio for a call transport. packetHandler runs on
// the codec queue, so callers must dispatch network work as needed.
@interface TGCallAudio : NSObject
@property (nonatomic, copy) void (^packetHandler)(NSData *packet);
- (BOOL)start:(NSString **)error;
- (void)stop;
- (void)receivePacket:(NSData *)packet;
@end
