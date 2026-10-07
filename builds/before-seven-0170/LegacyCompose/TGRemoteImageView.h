#import "TGLegacyUICompat.h"
@interface TGRemoteImageView : UIImageView
@property (nonatomic) BOOL fadeTransition;
@property (nonatomic) NSTimeInterval fadeTransitionDuration;
@property (nonatomic, copy) NSString *currentUrl;
- (UIImage *)currentImage;
- (void)loadImage:(id)image;
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder;
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(BOOL)fade;
@end
