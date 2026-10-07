#import <Foundation/Foundation.h>

// JSON payloads of tgcalls 7.0.0 ExternalSignalingConnection.
@interface TGCallSignal : NSObject
+ (NSData *)initialSetupWithUfrag:(NSString *)ufrag password:(NSString *)password
                       fingerprint:(NSString *)fingerprint caller:(BOOL)caller;
+ (BOOL)iceCredentialsFromDescription:(NSString *)description
                              ufrag:(NSString **)ufrag password:(NSString **)password;
+ (NSData *)candidates:(NSArray *)candidates;
+ (NSData *)audioChannelsWithSSRC:(uint32_t)ssrc exchangeId:(uint32_t)exchangeId;
+ (BOOL)exchangeIdFromChannels:(NSDictionary *)channels value:(uint32_t *)exchangeId;
+ (BOOL)remoteAudioFromChannels:(NSDictionary *)channels ssrc:(uint32_t *)ssrc payloadType:(uint8_t *)payloadType;
+ (NSDictionary *)parse:(NSData *)data;
@end
