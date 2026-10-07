#import <Foundation/Foundation.h>

// Opus RTP over DTLS-SRTP. Keys must come from a verified DTLS peer.
@interface TGCallRTP : NSObject
@property (nonatomic, readonly) uint32_t localSSRC;
@property (nonatomic, readonly) uint32_t remoteSSRC;
- (instancetype)initWithLocalSSRC:(uint32_t)localSSRC remoteSSRC:(uint32_t)remoteSSRC
                    outboundKey:(NSData *)outboundKey inboundKey:(NSData *)inboundKey
                sendPayloadType:(uint8_t)sendPayloadType receivePayloadType:(uint8_t)receivePayloadType;
- (NSData *)protectOpus:(NSData *)opus;
- (NSData *)unprotectOpus:(NSData *)packet;
- (void)stop;
@end
