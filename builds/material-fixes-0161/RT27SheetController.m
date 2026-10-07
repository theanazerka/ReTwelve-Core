#import "RT27SheetController.h"
#import "../TGFlatKit.h"
#import "../TGTheme.h"
#import <QuartzCore/QuartzCore.h>
@interface RT27SheetController : UIViewController
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIControl *dimmer;
@property(nonatomic,strong) TGThemedNavigationController *contentNavigation;
@property(nonatomic,weak) UINavigationController *originNavigation;
@property(nonatomic) BOOL compact, closing, presenting;
@property(nonatomic,strong) CAShapeLayer *panelMask;
@property(nonatomic) CGSize maskSize;
- (void)close;
- (void)closeWithCompletion:(void (^)(void))completion;
@end
@implementation RT27SheetController
- (void)loadView {
    self.view=[[UIView alloc] initWithFrame:CGRectZero]; self.view.backgroundColor=[UIColor clearColor]; self.view.tag=712027;
    self.dimmer=[[UIControl alloc] init]; self.dimmer.backgroundColor=[UIColor colorWithWhite:0 alpha:.28];
    [self.dimmer addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.dimmer];
    self.panel=[[UIView alloc] init]; self.panel.backgroundColor=TGMaterialCanvas(); [self.view addSubview:self.panel];
    self.panelMask=[[CAShapeLayer alloc] init]; self.panel.layer.cornerRadius=28; self.contentNavigation.view.backgroundColor=[UIColor clearColor]; self.contentNavigation.navigationBar.layer.mask=self.panelMask;
    [self addChildViewController:self.contentNavigation]; [self.panel addSubview:self.contentNavigation.view]; [self.contentNavigation didMoveToParentViewController:self];
    self.contentNavigation.navigationBar.tag=712028; self.contentNavigation.navigationBar.backgroundColor=self.panel.backgroundColor; [self.contentNavigation.navigationBar setNeedsLayout];
    UIViewController *root=self.contentNavigation.viewControllers.firstObject;
    UIButton *close=[UIButton buttonWithType:UIButtonTypeCustom]; close.frame=CGRectMake(0,0,36,36);
    [close setImage:TGMaterialIcon(@"close",24,TGMaterialText()) forState:UIControlStateNormal]; [close setTitleColor:[UIColor blackColor] forState:UIControlStateNormal]; close.titleLabel.font=[UIFont fontWithName:@"HelveticaNeue-Light" size:32];
    close.backgroundColor=TGMaterialSurfaceVariant(); close.layer.cornerRadius=18; close.accessibilityLabel=@"Закрыть";
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside]; root.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:close];
}
- (CGRect)panelFrame {
    CGSize size=self.view.bounds.size; CGFloat top=self.compact ? MIN(80,size.height*.15) : MIN(32,size.height*.06);
    return CGRectMake(0,top,size.width,MAX(0,size.height-top));
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; self.dimmer.frame=self.view.bounds;
    if(self.presenting || self.closing) return;
    CGRect frame=[self panelFrame];
    self.panel.bounds=(CGRect){CGPointZero,frame.size}; self.panel.center=CGPointMake(CGRectGetMidX(frame),CGRectGetMidY(frame));
    if(!CGRectEqualToRect(self.contentNavigation.view.frame,self.panel.bounds)) self.contentNavigation.view.frame=self.panel.bounds;
    if(CGSizeEqualToSize(self.maskSize,self.panel.bounds.size)) return;
    self.maskSize=self.panel.bounds.size;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.panelMask.frame=self.contentNavigation.navigationBar.bounds;
    self.panelMask.path=[UIBezierPath bezierPathWithRoundedRect:self.contentNavigation.navigationBar.bounds byRoundingCorners:UIRectCornerTopLeft|UIRectCornerTopRight cornerRadii:CGSizeMake(28,28)].CGPath;
    [CATransaction commit];
}
- (void)close { [self closeWithCompletion:nil]; }
- (void)closeWithCompletion:(void (^)(void))completion {
    if(self.closing) return; self.closing=YES; [self.view endEditing:YES];
    self.view.userInteractionEnabled=NO;
    [self beginAppearanceTransition:NO animated:YES];
    RT27AnimatePanel(self.panel,self.dimmer,NO,^{
        [self endAppearanceTransition]; [self willMoveToParentViewController:nil]; [self.view removeFromSuperview]; [self removeFromParentViewController];
        if(completion) completion();
    });
}
@end
void RT27AnimatePanel(UIView *panel,UIView *dimmer,BOOL presenting,void (^completion)(void)) {
    TGMaterialSlidePanel(panel,dimmer,presenting,completion);
}
static RT27SheetController *RT27FindSheet(UIViewController *controller) {
    for(UIViewController *p=controller;p;p=p.parentViewController) if([p isKindOfClass:[RT27SheetController class]]) return (id)p;
    UIViewController *root=controller.view.window.rootViewController;
    for(UIViewController *p in root.childViewControllers) if([p isKindOfClass:[RT27SheetController class]]) return (id)p;
    return nil;
}
void RT27PresentSheet(UIViewController *presenter,UIViewController *content,BOOL compact) {
    UIViewController *host=presenter.view.window.rootViewController;
    while(host.presentedViewController) host=host.presentedViewController;
    if(!host || RT27FindSheet(presenter)) return;
    RT27SheetController *sheet=[[RT27SheetController alloc] init]; sheet.compact=compact; sheet.originNavigation=presenter.navigationController;
    sheet.contentNavigation=[[TGThemedNavigationController alloc] initWithRootViewController:content];
    [host addChildViewController:sheet]; sheet.view.frame=host.view.bounds; sheet.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [sheet beginAppearanceTransition:YES animated:YES]; [host.view addSubview:sheet.view]; [sheet didMoveToParentViewController:host]; [sheet.view layoutIfNeeded];
    sheet.presenting=YES; sheet.view.userInteractionEnabled=NO;
    RT27AnimatePanel(sheet.panel,sheet.dimmer,YES,^{ sheet.presenting=NO; sheet.view.userInteractionEnabled=YES; [sheet endAppearanceTransition]; [sheet.view setNeedsLayout]; });
}
void RT27DismissSheet(UIViewController *controller,void (^completion)(void)) {
    RT27SheetController *sheet=RT27FindSheet(controller); if(sheet) [sheet closeWithCompletion:completion]; else if(completion) completion();
}
void RT27NavigateFromSheet(UIViewController *controller,UIViewController *next) {
    RT27SheetController *sheet=RT27FindSheet(controller);
    if(sheet) { UINavigationController *origin=sheet.originNavigation; [sheet closeWithCompletion:^{ [origin pushViewController:next animated:YES]; }]; }
    else [controller.navigationController pushViewController:next animated:YES];
}
