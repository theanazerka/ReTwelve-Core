#import <UIKit/UIKit.h>
@interface TGMaterialRootController : UIViewController
@property(nonatomic,copy) NSArray *viewControllers;
@property(nonatomic) NSUInteger selectedIndex;
@property(nonatomic,readonly) UIViewController *selectedViewController;
@property(nonatomic,strong,readonly) UIView *contentView;
@property(nonatomic,strong,readonly) UIView *tabBar;
@property(nonatomic,weak) id delegate;
@end
TGMaterialRootController *TGMaterialRootForController(UIViewController *controller);

@interface TGThemedNavigationController : UINavigationController
@end
#ifdef __cplusplus
extern "C" {
#endif
Class TGTextFieldClass(void);
Class TGContactCellClass(void);
void TGInstallFlatTabBar(TGMaterialRootController *controller);
void TGUpdateFlatTabBar(TGMaterialRootController *controller);
BOOL TGPresentLegacyFlatDialog(id owner, BOOL sheet);
BOOL TGDismissLegacyFlatDialog(id dialog, NSInteger index, BOOL animated);

Class TGSwitchClass(void);
#ifdef __cplusplus
}
#endif
