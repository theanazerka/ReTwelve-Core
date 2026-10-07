#import "TGTheme.h"
#import "Material/TGMaterialKit.h"
#import <objc/runtime.h>
static void TGExchange(Class cls,SEL a,SEL b) { Method x=class_getInstanceMethod(cls,a),y=class_getInstanceMethod(cls,b); if(x&&y)method_exchangeImplementations(x,y); }
@implementation UIImage (TGMaterialResources)
+ (UIImage *)tg_resourceImageNamed:(NSString *)name {
    if(!name.length)return [self tg_resourceImageNamed:name];
    static NSCache *cache; static dispatch_once_t once; dispatch_once(&once,^{cache=[[NSCache alloc] init]; cache.countLimit=300;});
    UIImage *cached=[cache objectForKey:name]; if(cached)return cached;
    UIImage *image=TGMaterialAsset(name,[self tg_resourceImageNamed:name]); if(image)[cache setObject:image forKey:name]; return image;
}
@end
@implementation UILabel (TGMaterialResources)
- (void)tg_flatShadow:(UIColor *)color { [self tg_flatShadow:nil]; }
@end
@implementation UIButton (TGMaterialResources)
- (void)tg_flatButtonShadow:(UIColor *)color forState:(UIControlState)state { [self tg_flatButtonShadow:nil forState:state]; }
@end
@implementation UIColor (TGMaterialResources)
+ (UIColor *)tg_flatPattern:(UIImage *)image { return TGMaterialCanvas(); }
@end
@implementation UINavigationBar (TGMaterialResources)
- (void)tg_flatBackground:(UIImage *)image forBarMetrics:(UIBarMetrics)metrics { self.translucent=NO; [self tg_flatBackground:TGFlatImage(TGMaterialCanvas()) forBarMetrics:metrics]; }
- (void)tg_flatTitleAttributes:(NSDictionary *)attributes { [self tg_flatTitleAttributes:@{UITextAttributeTextColor:TGMaterialText(),UITextAttributeFont:TGMaterialFont(20,YES),UITextAttributeTextShadowColor:[UIColor clearColor],UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetZero]}]; }
@end
UIColor *TGUI7ButtonTitleColor(UIButton *button,UIColor *color,UIControlState state) { return color; }
void TGUI7InstallResourceAdapters(void) { static dispatch_once_t once; dispatch_once(&once,^{
 TGExchange(object_getClass([UIImage class]),@selector(imageNamed:),@selector(tg_resourceImageNamed:));
 TGExchange([UILabel class],@selector(setShadowColor:),@selector(tg_flatShadow:));
 TGExchange([UIButton class],@selector(setTitleShadowColor:forState:),@selector(tg_flatButtonShadow:forState:));
 TGExchange(object_getClass([UIColor class]),@selector(colorWithPatternImage:),@selector(tg_flatPattern:));
 TGExchange([UINavigationBar class],@selector(setBackgroundImage:forBarMetrics:),@selector(tg_flatBackground:forBarMetrics:));
 TGExchange([UINavigationBar class],@selector(setTitleTextAttributes:),@selector(tg_flatTitleAttributes:));
}); }
