#import <Foundation/Foundation.h>

// Wire format used by modern tgcalls/v2/ReflectorPort and RawTcpSocket.
@interface TGCallReflectorProtocol : NSObject
+ (NSArray *)endpoints:(NSArray *)connections;
+ (NSDictionary *)candidate:(NSString *)sdp;
+ (NSData *)hello:(NSData *)peerTag localTag:(uint32_t)localTag tcp:(BOOL)tcp;
+ (NSData *)wrap:(NSData *)payload peerTag:(NSData *)peerTag
      localTag:(uint32_t)localTag remoteTag:(uint32_t)remoteTag;
+ (NSData *)unwrap:(NSData *)packet peerTag:(NSData *)peerTag
        senderTag:(uint32_t *)senderTag valid:(BOOL *)valid;
@end
