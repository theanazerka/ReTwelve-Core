#import "../LegacyCompose/TGLegacyUICompat.h"
#import "RT27LetteredAvatarView.h"
@implementation RT27LetteredAvatarView
- (instancetype)initWithFrame:(CGRect)frame { self=[super initWithFrame:frame]; if(self) { self.contentMode=UIViewContentModeScaleAspectFill; self.clipsToBounds=YES; self.layer.cornerRadius=frame.size.width/2; } return self; }
- (void)loadImage:(UIImage *)image { self.image=image; }
- (void)cancelLoading { self.currentUrl=nil; }
- (void)setTitle:(NSString *)title {}
- (void)setFirstName:(NSString *)first lastName:(NSString *)last {}
- (UIImage *)currentImage { return self.image; }
- (void)setSingleFontSize:(CGFloat)single doubleFontSize:(CGFloat)dual useBoldFont:(BOOL)bold {}
- (void)tryFillCache:(NSMutableDictionary *)cache { if(self.currentUrl && self.image) cache[self.currentUrl]=self.image; }
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder { [self loadImage:url filter:filter placeholder:placeholder forceFade:NO]; }
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(BOOL)fade {
    self.currentUrl=url; if(placeholder)self.image=placeholder;
    if([url hasPrefix:@"tglegacy-avatar:"]) {
        __weak RT27LetteredAvatarView *weakSelf=self;
        [[TGLegacyContactStore shared] avatarForURL:url completion:^(UIImage *image) {
            RT27LetteredAvatarView *view=weakSelf;
            if(image && [view.currentUrl isEqual:url]) view.image=image;
        }];
    }
}
- (void)loadUserPlaceholderWithSize:(CGSize)size uid:(int32_t)uid firstName:(NSString *)first lastName:(NSString *)last placeholder:(UIImage *)placeholder { self.currentUrl=nil; self.image=placeholder; }
- (void)loadGroupPlaceholderWithSize:(CGSize)size conversationId:(int64_t)cid title:(NSString *)title placeholder:(UIImage *)placeholder { self.currentUrl=nil; self.image=placeholder; }
@end
