#import <Foundation/Foundation.h>

@interface TGSRP : NSObject
+ (NSDictionary *)newPasswordSettings:(NSString *)password algorithm:(NSDictionary *)algorithm error:(NSString **)error;
+ (NSData *)proofForPassword:(NSString *)password configuration:(NSDictionary *)configuration error:(NSString **)error;
@end
