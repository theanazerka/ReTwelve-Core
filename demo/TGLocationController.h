#import <UIKit/UIKit.h>
@interface TGLocationController : UIViewController
@property (nonatomic, copy) void (^selection)(double latitude, double longitude);
@end
