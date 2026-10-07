#import <Foundation/Foundation.h>
#import <MtProtoKit/MTKeychain.h>

@interface TGDeviceKeychain : NSObject <MTKeychain>
- (instancetype)initWithNamespace:(NSString *)namespaceName;
@end
