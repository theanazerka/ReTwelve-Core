#import <UIKit/UIKit.h>
@interface TGInlinePollView : UIView
@property (nonatomic, copy) void (^vote)(NSArray *options);
+ (CGFloat)heightForMedia:(NSDictionary *)media width:(CGFloat)width;
- (void)configureMedia:(NSDictionary *)media;
@end
