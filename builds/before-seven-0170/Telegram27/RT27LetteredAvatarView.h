#import "RT27Compat.h"
// Image loading belongs to ReTwelve's existing disk/memory cache. The original
// UI class consumes cached images through this bridge without ActionStage.
@interface RT27LetteredAvatarView : UIImageView
@property(nonatomic) BOOL fadeTransition;
@property(nonatomic) NSInteger contentHints;
- (void)loadImage:(UIImage *)image;
@property(nonatomic) NSTimeInterval fadeTransitionDuration;
@property(nonatomic,copy) NSString *currentUrl;
@property(nonatomic,readonly) UIImage *currentImage;
- (void)setSingleFontSize:(CGFloat)single doubleFontSize:(CGFloat)dual useBoldFont:(BOOL)bold;
- (void)cancelLoading;
- (void)setTitle:(NSString *)title;
- (void)setFirstName:(NSString *)first lastName:(NSString *)last;
- (void)tryFillCache:(NSMutableDictionary *)cache;
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(BOOL)fade;
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder;
- (void)loadUserPlaceholderWithSize:(CGSize)size uid:(int32_t)uid firstName:(NSString *)first lastName:(NSString *)last placeholder:(UIImage *)placeholder;
- (void)loadGroupPlaceholderWithSize:(CGSize)size conversationId:(int64_t)cid title:(NSString *)title placeholder:(UIImage *)placeholder;
@end
