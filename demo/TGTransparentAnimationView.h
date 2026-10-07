#import <UIKit/UIKit.h>

@interface TGTransparentAnimationView : UIView
- (instancetype)initWithFrame:(CGRect)frame resourceName:(NSString *)resourceName;
- (void)play;
- (void)pause;
@end
