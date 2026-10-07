#import "RT27SheetController.h"
#import "../TGFlatKit.h"
#import "../Seven/RT7UIKit.h"
@interface RT7ModalNavigation : TGThemedNavigationController
@property(nonatomic,weak) UINavigationController *originNavigation;
@property(nonatomic) BOOL closing;
- (void)close;
@end
@implementation RT7ModalNavigation
- (void)close { if(self.closing)return; self.closing=YES; [self.view endEditing:YES]; [self.presentingViewController dismissViewControllerAnimated:YES completion:nil]; }
@end
static RT7ModalNavigation *RT7ModalForController(UIViewController *controller) {
    if([controller isKindOfClass:[RT7ModalNavigation class]])return (id)controller;
    if([controller.navigationController isKindOfClass:[RT7ModalNavigation class]])return (id)controller.navigationController;
    return nil;
}
void RT27PresentSheet(UIViewController *presenter,UIViewController *content,BOOL compact) {
    (void)compact; UIViewController *host=presenter.view.window.rootViewController; while(host.presentedViewController)host=host.presentedViewController; if(!host)return;
    RT7ModalNavigation *navigation=[[RT7ModalNavigation alloc] initWithRootViewController:content]; navigation.originNavigation=presenter.navigationController;
    navigation.modalPresentationStyle=UIModalPresentationFullScreen; navigation.modalTransitionStyle=UIModalTransitionStyleCoverVertical;
    content.navigationItem.leftBarButtonItem=[[RT7BarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStylePlain target:navigation action:@selector(close)];
    [host presentViewController:navigation animated:YES completion:nil];
}
void RT27DismissSheet(UIViewController *controller,void (^completion)(void)) {
    RT7ModalNavigation *navigation=RT7ModalForController(controller); if(!navigation) { if(completion)completion(); return; }
    if(navigation.closing)return; navigation.closing=YES; [navigation.view endEditing:YES]; [navigation.presentingViewController dismissViewControllerAnimated:YES completion:completion];
}
void RT27NavigateFromSheet(UIViewController *controller,UIViewController *next) {
    RT7ModalNavigation *navigation=RT7ModalForController(controller);
    if(navigation) { UINavigationController *origin=navigation.originNavigation; RT27DismissSheet(controller,^{ [origin pushViewController:next animated:YES]; }); }
    else [controller.navigationController pushViewController:next animated:YES];
}
void RT27AnimatePanel(UIView *panel,UIView *dimmer,BOOL presenting,void (^completion)(void)) { RT7SlidePanel(panel,dimmer,presenting,completion); }
