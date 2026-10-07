#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#ifdef __cplusplus
extern "C" {
#endif

// One presentation system for every screen, including iOS 6 / armv7.
UIColor *TGMaterialPrimary(void);
UIColor *TGMaterialOnPrimary(void);
UIColor *TGMaterialPrimaryContainer(void);
UIColor *TGMaterialSurface(void);
UIColor *TGMaterialCanvas(void);
UIColor *TGMaterialSurfaceVariant(void);
UIColor *TGMaterialText(void);
UIColor *TGMaterialSecondaryText(void);
UIColor *TGMaterialOutline(void);
UIColor *TGMaterialError(void);
UIColor *TGMaterialBubbleColor(NSInteger index);
UIImage *TGMaterialWallpaper(NSInteger index);
UIFont *TGMaterialFont(CGFloat size, BOOL medium);
UIImage *TGMaterialShape(CGSize size, UIColor *color, CGFloat radius);
UIImage *TGMaterialIcon(NSString *name, CGFloat size, UIColor *color);
UIImage *TGMaterialAsset(NSString *name, UIImage *original);
void TGMaterialConfigureSlider(UISlider *slider);
void TGMaterialAnimate(CALayer *layer, NSString *key, id from, id to, NSTimeInterval duration);
void TGMaterialSlidePanel(UIView *panel, UIView *scrim, BOOL show, void (^completion)(void));
void TGMaterialPrepareScreen(UIViewController *controller);

#ifdef __cplusplus
}
#endif

@interface TGMaterialButton : UIButton
@end
@interface TGMaterialTextField : UITextField
@end
@interface TGMaterialSwitch : UIControl
@property(nonatomic,getter=isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

// A single real table cell, with direct controls and vector card geometry.
@interface TGMaterialListCell : UITableViewCell
@property(nonatomic) BOOL firstInGroup,lastInGroup;
@property(nonatomic) CGFloat cardInset;
@end
