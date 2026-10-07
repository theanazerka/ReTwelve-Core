#import <UIKit/UIKit.h>
@class TGClient;

@interface TGDeviceQRController : UIViewController
- (instancetype)initWithClient:(TGClient *)client linked:(void (^)(NSDictionary *session))linked;
@end
