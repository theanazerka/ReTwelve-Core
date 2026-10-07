#import "TGTheme.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// Retain resource names through resizing, so cached original Telegram artwork can
// be styled at display time without poisoning the classic theme's image cache.
static char TGResourceNameKey, TGFlatButtonKey, TGDestructiveButtonKey;
static void TGCopyResourceName(UIImage *from, UIImage *to) {
    if (to && from != to) objc_setAssociatedObject(to, &TGResourceNameKey,
        objc_getAssociatedObject(from, &TGResourceNameKey), OBJC_ASSOCIATION_COPY_NONATOMIC);
}
static BOOL TGHasAnyPrefix(NSString *name, NSArray *prefixes) {
    for (NSString *prefix in prefixes) if ([name hasPrefix:prefix]) return YES;
    return NO;
}
static NSInteger TGFlatResourceKind(UIImage *image) {
    NSString *name = objc_getAssociatedObject(image, &TGResourceNameKey);
    if (!name) return 0;
    if (TGHasAnyPrefix(name, @[@"TokenFieldShadow", @"InputFieldShadow", @"LoginShadow", @"NavigationBar_Corners", @"Header_Corners", @"HomeShadow", @"TableShadow", @"TabBarSelected", @"LoginInputDivider"])) return 5;
    if (TGHasAnyPrefix(name, @[@"BackButton", @"HeaderButton", @"ImagePickerBlueButton", @"ImagePickerGrayButton", @"LoginButton", @"GalleryDoneButton", @"SearchCancelButton", @"SearchDarkCancelButton", @"LoginGreenButton", @"LoginCountry", @"MenuGrayButton", @"MenuRedButton", @"GroupedActionButton", @"ActionMenuButton", @"SendButton", @"GalleryCloseButton", @"ListDeleteButton"])) return 5;
    if (TGHasAnyPrefix(name, @[@"SettingsBackground", @"LoginBackground", @"DarkLinen", @"Linen"])) return 1;
    if (TGHasAnyPrefix(name, @[@"GalleryTopPanel", @"GalleryBottomPanel"])) return 15;
    if (TGHasAnyPrefix(name, @[@"Header", @"LoginHeader", @"TabBarBackground", @"ConversationInputPanel", @"ImagePickerPanel", @"SearchBarBackground", @"ToolbarBackground", @"GalleryTopPanel", @"GalleryBottomPanel", @"TokenFieldBackground"])) return 2;
    if (TGHasAnyPrefix(name, @[@"GroupedCell", @"TableCell", @"ContactCell", @"ActionCell", @"Cell88", @"CellHighlighted", @"Cell96", @"Cell102", @"ContactListCell"])) return ([name rangeOfString:@"Selected" options:NSCaseInsensitiveSearch].location != NSNotFound || [name rangeOfString:@"Highlighted"].location != NSNotFound) ? 3 : 4;
    if (TGHasAnyPrefix(name, @[@"LoginInput", @"SearchInputField", @"ConversationInputField"])) return 6;
    if ([name hasPrefix:@"ProfilePhotoPlaceholder"]) return 7;
    if (TGHasAnyPrefix(name, @[@"MessageCheckFull", @"MessageCheckHalf"])) return 8;
    if (TGHasAnyPrefix(name, @[@"ImagePickerSelect", @"ImagePickerThumbnalSelect"])) return [name rangeOfString:@"Checked"].location == NSNotFound ? 9 : 10;
    if ([name hasPrefix:@"ImagePickerCountBadge"]) return 11;
    if ([name hasPrefix:@"TokenBackground"]) return [name rangeOfString:@"Highlighted"].location == NSNotFound ? 12 : 13;
    if ([name hasPrefix:@"MenuDisclosureIndicator"]) return 14;
    if ([name hasPrefix:@"AddButton"]) return 16;
    if ([name hasPrefix:@"PlayButtonBig"]) return 17;
    return 0;
}
static UIImage *TGDisplayedImage(UIImage *image) {
    if (!TGModernThemeEnabled() || !image) return image;
    NSInteger kind = TGFlatResourceKind(image); if (!kind) return image;
    static NSCache *cache; if (!cache) { cache = [[NSCache alloc] init]; cache.countLimit = 80; }
    NSString *key = [NSString stringWithFormat:@"%@:%.1f:%.1f:%.1f:%@", objc_getAssociatedObject(image, &TGResourceNameKey),image.size.width,image.size.height,image.scale,NSStringFromUIEdgeInsets(image.capInsets)];
    UIImage *flat = [cache objectForKey:key]; if (flat) return flat;
    // Same dimensions preserve legacy cap insets and intrinsic control sizes.
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    UIColor *color = kind == 1 ? TGModernCanvas() : kind == 2 ? [UIColor colorWithWhite:.98 alpha:1] : kind == 3 ? [UIColor colorWithWhite:.9 alpha:1] : kind == 4 ? [UIColor whiteColor] : [UIColor clearColor];
    CGRect rect = (CGRect){CGPointZero,image.size};
    if (kind <= 5) { [color setFill]; UIRectFill(rect); }
    else if (kind == 6) {
        [[UIColor whiteColor] setFill]; [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect,.5,.5) cornerRadius:6] fill];
        [TGModernSeparator() setStroke]; UIBezierPath *outline = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect,.5,.5) cornerRadius:6]; outline.lineWidth=.5; [outline stroke];
    } else if (kind == 7) { [TGModernCanvas() setFill]; UIRectFill(rect); }
    else if (kind == 8) {
        [image drawInRect:rect]; CGContextSetBlendMode(UIGraphicsGetCurrentContext(), kCGBlendModeSourceIn); [TGModernBlue() setFill]; CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
    } else if (kind == 9 || kind == 10 || kind == 11) {
        CGFloat diameter = MIN(28, MIN(rect.size.width,rect.size.height)-4);
        CGRect circle = CGRectMake((rect.size.width-diameter)/2,(rect.size.height-diameter)/2,diameter,diameter);
        UIBezierPath *outline = [UIBezierPath bezierPathWithOvalInRect:circle];
        if (kind != 9) { [TGModernBlue() setFill]; [outline fill]; }
        [[UIColor whiteColor] setStroke]; outline.lineWidth=2; [outline stroke];
        if (kind == 10) { UIImage *check = [UIImage imageNamed:@"UIAccessoryButtonCheckmark"]; [check drawInRect:CGRectInset(circle,6,6)]; }
    } else if (kind == 12 || kind == 13) {
        [kind == 12 ? TGModernCanvas() : TGModernBlue() setFill];
        [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:MIN(6,rect.size.height/2)] fill];
    } else if (kind == 14) {
        UIImage *arrow = [UIImage imageNamed:@"Telegram27/ModernListsDisclosureIndicator.png"];
        CGSize size = CGSizeMake(MIN(rect.size.width,arrow.size.width),MIN(rect.size.height,arrow.size.height));
        [arrow drawInRect:CGRectMake((rect.size.width-size.width)/2,(rect.size.height-size.height)/2,size.width,size.height)];
    } else if (kind == 16 || kind == 17) {
        UIImage *glyph = [UIImage imageNamed:kind == 16 ? @"UIAccessoryButtonPlus" : @"UI7Theme/MusicPlayerControlPlay"];
        CGSize size = CGSizeMake(MIN(rect.size.width,glyph.size.width),MIN(rect.size.height,glyph.size.height));
        CGRect iconRect = CGRectMake((rect.size.width-size.width)/2,(rect.size.height-size.height)/2,size.width,size.height);
        [glyph drawInRect:iconRect];
        CGContextSetBlendMode(UIGraphicsGetCurrentContext(),kCGBlendModeSourceIn);
        [TGModernBlue() setFill]; CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
    } else if (kind == 15) { [[UIColor colorWithWhite:.12 alpha:1] setFill]; UIRectFill(rect); }
    flat = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    if (flat && !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero)) flat = [flat resizableImageWithCapInsets:image.capInsets];
    if (flat) [cache setObject:flat forKey:key]; return flat ?: image;
}
static void TGExchange(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original), b = class_getInstanceMethod(cls, replacement);
    if (a && b) method_exchangeImplementations(a,b);
}
@interface UIImage (TGFlatResources)
@end
@implementation UIImage (TGFlatResources)
+ (UIImage *)tg_resourceImageNamed:(NSString *)name {
    UIImage *image = [self tg_resourceImageNamed:name];
    if (image) objc_setAssociatedObject(image, &TGResourceNameKey, [name hasPrefix:@"Telegram27/"] ? name : name.lastPathComponent.stringByDeletingPathExtension, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return image;
}
- (UIImage *)tg_resourceStretch:(NSInteger)left topCapHeight:(NSInteger)top {
    UIImage *result = [self tg_resourceStretch:left topCapHeight:top]; TGCopyResourceName(self,result); return result;
}
- (UIImage *)tg_resourceResizeMode:(UIEdgeInsets)insets resizingMode:(UIImageResizingMode)mode {
    UIImage *result = [self tg_resourceResizeMode:insets resizingMode:mode]; TGCopyResourceName(self,result); return result;
}
- (UIImage *)tg_resourceResize:(UIEdgeInsets)insets {
    UIImage *result = [self tg_resourceResize:insets]; TGCopyResourceName(self,result); return result;
}
@end
@interface UIImageView (TGFlatResources)
- (instancetype)tg_flatInitWithImage:(UIImage *)image __attribute__((objc_method_family(init)));
- (instancetype)tg_flatInitWithImage:(UIImage *)image highlightedImage:(UIImage *)highlight __attribute__((objc_method_family(init)));
@end
@implementation UIImageView (TGFlatResources)
- (void)tg_flatHighlightedImage:(UIImage *)image { [self tg_flatHighlightedImage:TGDisplayedImage(image)]; }
- (instancetype)tg_flatInitWithImage:(UIImage *)image highlightedImage:(UIImage *)highlight { return [self tg_flatInitWithImage:TGDisplayedImage(image) highlightedImage:TGDisplayedImage(highlight)]; }
- (void)tg_flatSetImage:(UIImage *)image { [self tg_flatSetImage:TGDisplayedImage(image)]; }
- (instancetype)tg_flatInitWithImage:(UIImage *)image { self = [self tg_flatInitWithImage:TGDisplayedImage(image)]; return self; }
@end
@implementation UIColor (TGFlatResources)
+ (UIColor *)tg_flatPattern:(UIImage *)image {
    if (TGModernThemeEnabled() && TGFlatResourceKind(image) == 1) return TGModernCanvas();
    return [self tg_flatPattern:image];
}
@end
@implementation UINavigationBar (TGFlatResources)
- (void)tg_flatBackground:(UIImage *)image forBarMetrics:(UIBarMetrics)metrics {
    self.translucent = NO;
    [self tg_flatBackground:TGModernThemeEnabled() ? TGFlatImage([UIColor colorWithWhite:.98 alpha:1]) : image forBarMetrics:metrics];
}
- (void)tg_flatTitleAttributes:(NSDictionary *)attributes {
    if (TGModernThemeEnabled()) attributes = @{UITextAttributeTextColor:[UIColor blackColor], UITextAttributeFont:[UIFont boldSystemFontOfSize:17], UITextAttributeTextShadowColor:[UIColor clearColor],UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetZero]};
    [self tg_flatTitleAttributes:attributes];
}
@end
@implementation UILabel (TGFlatResources)
- (void)tg_flatFont:(UIFont *)font {
    if (TGModernThemeEnabled() && [self.superview isKindOfClass:[UIButton class]] && [objc_getAssociatedObject(self.superview,&TGFlatButtonKey) boolValue]) font = [UIFont systemFontOfSize:MAX(15,font.pointSize)];
    [self tg_flatFont:font];
}
- (void)tg_flatHighlightedText:(UIColor *)color { [self tg_flatHighlightedText:TGModernThemeEnabled() ? (self.textColor ?: [UIColor blackColor]) : color]; }
- (void)tg_flatShadow:(UIColor *)color { [self tg_flatShadow:TGModernThemeEnabled() ? nil : color]; }
@end
@implementation UITextField (TGFlatResources)
- (void)tg_flatFieldBackground:(UIImage *)image { [self tg_flatFieldBackground:TGDisplayedImage(image)]; }
@end
@implementation UIButton (TGFlatResources)
- (void)tg_flatButtonImage:(UIImage *)image forState:(UIControlState)state { [self tg_flatButtonImage:TGDisplayedImage(image) forState:state]; }
- (void)tg_flatButtonShadow:(UIColor *)color forState:(UIControlState)state { [self tg_flatButtonShadow:TGModernThemeEnabled() ? [UIColor clearColor] : color forState:state]; }
- (void)tg_flatButtonBackground:(UIImage *)image forState:(UIControlState)state {
    BOOL flat = TGModernThemeEnabled() && TGFlatResourceKind(image) == 5;
    if (TGModernThemeEnabled() && TGFlatResourceKind(image) == 12) [self setTitleColor:TGModernBlue() forState:UIControlStateNormal];
    if (flat) {
        objc_setAssociatedObject(self,&TGFlatButtonKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSString *name = objc_getAssociatedObject(image,&TGResourceNameKey);
        if ([name hasPrefix:@"MenuRedButton"] || [name hasPrefix:@"ListDeleteButton"]) objc_setAssociatedObject(self,&TGDestructiveButtonKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [self tg_flatButtonBackground:TGDisplayedImage(image) forState:state];
    if (flat) {
        [self setTitleColor:TGModernBlue() forState:UIControlStateNormal];
        [self setTitleShadowColor:[UIColor clearColor] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:17];
    }
}
- (void)tg_flatTitleColor:(UIColor *)color forState:(UIControlState)state {
    if (TGModernThemeEnabled() && [objc_getAssociatedObject(self,&TGFlatButtonKey) boolValue]) color = (state & UIControlStateDisabled) ? TGModernSecondaryText() : [objc_getAssociatedObject(self,&TGDestructiveButtonKey) boolValue] ? [UIColor colorWithRed:1 green:.23 blue:.19 alpha:1] : TGModernBlue();
    [self tg_flatTitleColor:color forState:state];
}
@end
UIColor *TGUI7ButtonTitleColor(UIButton *button, UIColor *color, UIControlState state) {
    if (!TGModernThemeEnabled() || ![objc_getAssociatedObject(button,&TGFlatButtonKey) boolValue]) return color;
    if (state & UIControlStateDisabled) return TGModernSecondaryText();
    return [objc_getAssociatedObject(button,&TGDestructiveButtonKey) boolValue] ? [UIColor colorWithRed:1 green:.23 blue:.19 alpha:1] : TGModernBlue();
}
void TGUI7InstallResourceAdapters(void) {
    static dispatch_once_t once; dispatch_once(&once, ^{
        TGExchange(object_getClass([UIImage class]), @selector(imageNamed:), @selector(tg_resourceImageNamed:));
        TGExchange([UIImage class], @selector(stretchableImageWithLeftCapWidth:topCapHeight:), @selector(tg_resourceStretch:topCapHeight:));
        TGExchange([UIImage class], @selector(resizableImageWithCapInsets:resizingMode:), @selector(tg_resourceResizeMode:resizingMode:));
        TGExchange([UIImage class], @selector(resizableImageWithCapInsets:), @selector(tg_resourceResize:));
        TGExchange([UILabel class], @selector(setFont:), @selector(tg_flatFont:));
        TGExchange([UILabel class], @selector(setHighlightedTextColor:), @selector(tg_flatHighlightedText:));
        TGExchange([UILabel class], @selector(setShadowColor:), @selector(tg_flatShadow:));
        TGExchange([UITextField class], @selector(setBackground:), @selector(tg_flatFieldBackground:));
        TGExchange([UIImageView class], @selector(setHighlightedImage:), @selector(tg_flatHighlightedImage:));
        TGExchange([UIImageView class], @selector(initWithImage:highlightedImage:), @selector(tg_flatInitWithImage:highlightedImage:));
        TGExchange([UIImageView class], @selector(setImage:), @selector(tg_flatSetImage:));
        TGExchange([UIImageView class], @selector(initWithImage:), @selector(tg_flatInitWithImage:));
        TGExchange(object_getClass([UIColor class]), @selector(colorWithPatternImage:), @selector(tg_flatPattern:));
        TGExchange([UINavigationBar class], @selector(setBackgroundImage:forBarMetrics:), @selector(tg_flatBackground:forBarMetrics:));
        TGExchange([UINavigationBar class], @selector(setTitleTextAttributes:), @selector(tg_flatTitleAttributes:));
        TGExchange([UIButton class], @selector(setBackgroundImage:forState:), @selector(tg_flatButtonBackground:forState:));
        TGExchange([UIButton class], @selector(setImage:forState:), @selector(tg_flatButtonImage:forState:));
        TGExchange([UIButton class], @selector(setTitleShadowColor:forState:), @selector(tg_flatButtonShadow:forState:));
        TGExchange([UIButton class], @selector(setTitleColor:forState:), @selector(tg_flatTitleColor:forState:));
    });
}
