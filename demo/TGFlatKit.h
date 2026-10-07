#import <UIKit/UIKit.h>
@interface RT7RootController : UITabBarController
@property(nonatomic,strong,readonly) UIView *contentView;
@end
RT7RootController *RT7RootForController(UIViewController *controller);

@interface TGThemedNavigationController : UINavigationController
@end
#ifdef __cplusplus
extern "C" {
#endif
Class TGTextFieldClass(void);
Class TGContactCellClass(void);
void TGInstallFlatTabBar(RT7RootController *controller);
void TGUpdateFlatTabBar(RT7RootController *controller);
BOOL TGPresentLegacyFlatDialog(id owner, BOOL sheet);
BOOL TGDismissLegacyFlatDialog(id dialog, NSInteger index, BOOL animated);

Class TGSwitchClass(void);
#ifdef __cplusplus
}
#endif
