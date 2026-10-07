#import <UIKit/UIKit.h>

@interface TGInlineAnimationView : UIView
- (instancetype)initWithFrame:(CGRect)frame resourceName:(NSString *)resourceName;
- (void)play;
- (void)pause;
@end
