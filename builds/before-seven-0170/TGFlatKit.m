#import "TGFlatKit.h"
#import "TGTheme.h"
#import "Material/TGMaterialKit.h"
#import <objc/runtime.h>
Class TGTextFieldClass(void) { return [TGMaterialTextField class]; }
Class TGContactCellClass(void) { return NSClassFromString(@"RT27ContactCell"); }
Class TGSwitchClass(void) { return [TGMaterialSwitch class]; }
@interface TGMaterialNavigationBar : UINavigationBar
@end
@implementation TGMaterialNavigationBar
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:frame])) { self.translucent=NO; self.tintColor=TGMaterialPrimary(); [self setBackgroundImage:TGFlatImage(TGMaterialCanvas()) forBarMetrics:UIBarMetricsDefault]; } return self; }
@end
@implementation TGThemedNavigationController
- (instancetype)initWithRootViewController:(UIViewController *)root {
    if((self=[super initWithNavigationBarClass:[TGMaterialNavigationBar class] toolbarClass:nil])) self.viewControllers=@[root]; return self;
}
- (void)pushViewController:(UIViewController *)controller animated:(BOOL)animated {
    if(self.viewControllers.count && !controller.navigationItem.leftBarButtonItem) {
        UIButton *back=[[TGMaterialButton alloc] initWithFrame:CGRectMake(0,0,40,40)];
        [back setImage:TGMaterialIcon(@"back",24,TGMaterialText()) forState:UIControlStateNormal]; back.accessibilityLabel=@"Назад";
        [back addTarget:self action:@selector(materialBack) forControlEvents:UIControlEventTouchUpInside];
        controller.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:back];
    }
    [super pushViewController:controller animated:animated];
}
- (void)materialBack { [self popViewControllerAnimated:YES]; }
@end
// Own containment and layout: no UIKit tab bar container or private subviews.
@interface TGMaterialRootController ()
@property(nonatomic,strong,readwrite) UIView *contentView;
@property(nonatomic,strong,readwrite) UIView *tabBar;
@end
@implementation TGMaterialRootController
- (BOOL)shouldAutomaticallyForwardAppearanceMethods { return NO; }
- (UIViewController *)selectedViewController { return self.selectedIndex<self.viewControllers.count ? self.viewControllers[self.selectedIndex] : nil; }
- (void)loadView {
    self.view=[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame]; self.view.backgroundColor=TGMaterialCanvas();
    self.contentView=[[UIView alloc] initWithFrame:self.view.bounds]; [self.view addSubview:self.contentView];
    self.tabBar=[[UIView alloc] initWithFrame:CGRectZero]; self.tabBar.backgroundColor=TGMaterialSurfaceVariant(); [self.view addSubview:self.tabBar];
    UIViewController *selected=self.selectedViewController; selected.view.frame=self.contentView.bounds; selected.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.contentView addSubview:selected.view];
}
- (void)setViewControllers:(NSArray *)controllers {
    for(UIViewController *controller in _viewControllers) { [controller willMoveToParentViewController:nil]; if(controller.isViewLoaded)[controller.view removeFromSuperview]; [controller removeFromParentViewController]; }
    _viewControllers=[controllers copy]; _selectedIndex=MIN(_selectedIndex,MAX(1,controllers.count)-1);
    for(UIViewController *controller in controllers) { [self addChildViewController:controller]; [controller didMoveToParentViewController:self]; }
    if(self.isViewLoaded) { UIViewController *selected=self.selectedViewController; selected.view.frame=self.contentView.bounds; [self.contentView addSubview:selected.view]; }
}
- (void)setSelectedIndex:(NSUInteger)index {
    if(index>=self.viewControllers.count || index==_selectedIndex)return;
    UIViewController *old=self.selectedViewController; _selectedIndex=index; UIViewController *next=self.selectedViewController;
    if(!self.isViewLoaded)return;
    BOOL visible=self.view.window!=nil;
    if(visible) { [old beginAppearanceTransition:NO animated:NO]; [next beginAppearanceTransition:YES animated:NO]; }
    [old.view removeFromSuperview]; next.view.frame=self.contentView.bounds; next.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.contentView addSubview:next.view];
    if(visible) { [old endAppearanceTransition]; [next endAppearanceTransition]; }
    if([self.delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)]) [self.delegate tabBarController:(id)self didSelectViewController:next];
    TGUpdateFlatTabBar(self); [self.view setNeedsLayout];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.selectedViewController beginAppearanceTransition:YES animated:animated]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self.selectedViewController endAppearanceTransition]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.selectedViewController beginAppearanceTransition:NO animated:animated]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [self.selectedViewController endAppearanceTransition]; }
@end
TGMaterialRootController *TGMaterialRootForController(UIViewController *controller) { for(UIViewController *node=controller;node;node=node.parentViewController) if([node isKindOfClass:[TGMaterialRootController class]])return (id)node; return nil; }
@interface TGMaterialTabStrip : UIView
@property(nonatomic,weak) TGMaterialRootController *controller;
@property(nonatomic,strong) NSArray *buttons,*icons,*labels;
@property(nonatomic,strong) UIView *indicator;
@property(nonatomic,strong) UILabel *badge;
@property(nonatomic) NSInteger renderedIndex;
@end
@implementation TGMaterialTabStrip
- (instancetype)initWithController:(TGMaterialRootController *)controller {
    if((self=[super initWithFrame:controller.tabBar.bounds])) {
        self.controller=controller; self.backgroundColor=TGMaterialSurfaceVariant(); self.renderedIndex=-1;
        self.indicator=[[UIView alloc] init]; self.indicator.backgroundColor=TGMaterialPrimaryContainer(); self.indicator.layer.cornerRadius=16; [self addSubview:self.indicator];
        NSMutableArray *buttons=[NSMutableArray array],*icons=[NSMutableArray array],*labels=[NSMutableArray array];
        NSArray *names=@[@"contacts",@"chat",@"settings"],*titles=@[@"Контакты",@"Чаты",@"Настройки"];
        for(NSInteger i=0;i<3;i++) { UIButton *button=[[TGMaterialButton alloc] initWithFrame:CGRectZero]; button.tag=i; button.accessibilityLabel=titles[i]; [button addTarget:self action:@selector(select:) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:button]; [buttons addObject:button];
            UIImageView *icon=[[UIImageView alloc] initWithImage:TGMaterialIcon(names[i],24,TGMaterialSecondaryText())]; icon.userInteractionEnabled=NO; [button addSubview:icon]; [icons addObject:icon];
            UILabel *label=[[UILabel alloc] init]; label.backgroundColor=[UIColor clearColor]; label.font=TGMaterialFont(10,YES); label.text=titles[i]; label.textAlignment=NSTextAlignmentCenter; [button addSubview:label]; [labels addObject:label]; }
        self.buttons=buttons; self.icons=icons; self.labels=labels;
        self.badge=[[UILabel alloc] init]; self.badge.backgroundColor=TGMaterialError(); self.badge.textColor=[UIColor whiteColor]; self.badge.font=TGMaterialFont(9,YES); self.badge.textAlignment=NSTextAlignmentCenter; self.badge.layer.cornerRadius=8; self.badge.clipsToBounds=YES; [self addSubview:self.badge];
    } return self;
}
- (void)select:(UIButton *)button { self.controller.selectedIndex=button.tag; [self setNeedsLayout]; }
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat w=self.bounds.size.width/3,h=self.bounds.size.height; NSInteger selected=self.controller.selectedIndex;
    CGPoint before=self.indicator.layer.position; CGRect indicator=CGRectMake(selected*w+(w-64)/2,4,64,28);
    [CATransaction begin]; [CATransaction setDisableActions:YES]; self.indicator.frame=indicator; [CATransaction commit];
    if(self.renderedIndex>=0 && self.renderedIndex!=selected) TGMaterialAnimate(self.indicator.layer,@"position",[NSValue valueWithCGPoint:before],[NSValue valueWithCGPoint:self.indicator.layer.position],.2);
    self.renderedIndex=selected;
    for(NSInteger i=0;i<3;i++) { ((UIButton *)self.buttons[i]).frame=CGRectMake(i*w,0,w,h); ((UIImageView *)self.icons[i]).frame=CGRectMake((w-24)/2,6,24,24); ((UILabel *)self.labels[i]).frame=CGRectMake(0,33,w,MAX(12,h-34)); ((UILabel *)self.labels[i]).textColor=i==selected ? TGMaterialText() : TGMaterialSecondaryText(); }
    NSString *badge=self.controller.viewControllers.count>1 ? [self.controller.viewControllers[1] tabBarItem].badgeValue : nil;
    self.badge.hidden=!badge.length || badge.intValue==0; self.badge.text=badge.intValue>99 ? @"99+" : badge; self.badge.frame=CGRectMake(w*1.5+10,3,MAX(16,MIN(30,ceil([badge sizeWithFont:self.badge.font].width)+8)),16);
}
@end
static char TGMaterialTabKey;
void TGInstallFlatTabBar(TGMaterialRootController *controller) {
    TGMaterialTabStrip *strip=objc_getAssociatedObject(controller,&TGMaterialTabKey);
    if(!strip) { strip=[[TGMaterialTabStrip alloc] initWithController:controller]; objc_setAssociatedObject(controller,&TGMaterialTabKey,strip,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    for(UIView *view in controller.tabBar.subviews) if(view!=strip)view.hidden=YES;
    if(strip.superview!=controller.tabBar)[controller.tabBar addSubview:strip];
    strip.frame=controller.tabBar.bounds; strip.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [strip setNeedsLayout];
}
void TGUpdateFlatTabBar(TGMaterialRootController *controller) { TGInstallFlatTabBar(controller); }
#import <objc/message.h>
extern void TGAssociateFlatDialog(id,id);
static void TGDialogDelegate(id owner,NSInteger index,BOOL sheet) {
 id delegate=[owner delegate]; NSArray *selectors=sheet ? @[@"actionSheet:clickedButtonAtIndex:",@"actionSheet:willDismissWithButtonIndex:",@"actionSheet:didDismissWithButtonIndex:"] : @[@"alertView:clickedButtonAtIndex:",@"alertView:willDismissWithButtonIndex:",@"alertView:didDismissWithButtonIndex:"];
 for(NSString *name in selectors) { SEL sel=NSSelectorFromString(name); if([delegate respondsToSelector:sel])((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,sel,owner,index); }
}
@interface TGMaterialDialog : UIView
@property(nonatomic,strong) id owner;
@property(nonatomic,strong) UIView *card;
@property(nonatomic,strong) UIControl *scrim;
@property(nonatomic,strong) UILabel *title,*message;
@property(nonatomic,strong) NSArray *buttons,*fields;
@property(nonatomic) BOOL sheet,closing;
- (instancetype)initWithOwner:(id)owner sheet:(BOOL)sheet;
- (void)dismiss:(NSInteger)index animated:(BOOL)animated;
@end
@implementation TGMaterialDialog
- (instancetype)initWithOwner:(id)owner sheet:(BOOL)sheet {
 if((self=[super initWithFrame:[UIApplication sharedApplication].keyWindow.bounds])) {
  self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; self.owner=owner; self.sheet=sheet;
  self.scrim=[[UIControl alloc] initWithFrame:self.bounds]; self.scrim.autoresizingMask=self.autoresizingMask; self.scrim.backgroundColor=[TGMaterialText() colorWithAlphaComponent:.38]; [self.scrim addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:self.scrim];
  self.card=[[UIScrollView alloc] init]; self.card.clipsToBounds=YES; ((UIScrollView *)self.card).showsVerticalScrollIndicator=NO; self.card.backgroundColor=TGMaterialCanvas(); self.card.layer.cornerRadius=28; [self addSubview:self.card];
  self.title=[[UILabel alloc] init]; self.title.text=[owner title]; self.title.font=TGMaterialFont(20,YES); self.title.textColor=TGMaterialText(); self.title.numberOfLines=0; self.title.backgroundColor=[UIColor clearColor]; [self.card addSubview:self.title];
  self.message=[[UILabel alloc] init]; self.message.text=sheet ? nil : [(UIAlertView *)owner message]; self.message.font=TGMaterialFont(14,NO); self.message.textColor=TGMaterialSecondaryText(); self.message.numberOfLines=0; self.message.backgroundColor=[UIColor clearColor]; [self.card addSubview:self.message];
  NSMutableArray *fields=[NSMutableArray array]; NSInteger count=sheet || [(UIAlertView *)owner alertViewStyle]==UIAlertViewStyleDefault ? 0 : [(UIAlertView *)owner alertViewStyle]==UIAlertViewStyleLoginAndPasswordInput ? 2 : 1;
  for(NSInteger i=0;i<count;i++) { UITextField *source=[owner textFieldAtIndex:i]; UITextField *field=[[TGMaterialTextField alloc] initWithFrame:CGRectZero]; field.text=source.text; field.placeholder=source.placeholder; field.secureTextEntry=source.secureTextEntry; field.keyboardType=source.keyboardType; [self.card addSubview:field]; [fields addObject:field]; } self.fields=fields;
  NSMutableArray *buttons=[NSMutableArray array];
  for(NSInteger i=0;i<[owner numberOfButtons];i++) { UIButton *button=[[TGMaterialButton alloc] initWithFrame:CGRectZero]; button.tag=i; [button setTitle:[owner buttonTitleAtIndex:i] forState:UIControlStateNormal]; if(sheet && i==[(UIActionSheet *)owner destructiveButtonIndex])[button setTitleColor:TGMaterialError() forState:UIControlStateNormal]; button.contentHorizontalAlignment=sheet ? UIControlContentHorizontalAlignmentLeft : UIControlContentHorizontalAlignmentCenter; button.contentEdgeInsets=UIEdgeInsetsMake(0,16,0,16); [button addTarget:self action:@selector(chosen:) forControlEvents:UIControlEventTouchUpInside]; [self.card addSubview:button]; [buttons addObject:button]; } self.buttons=buttons;
 }
 return self;
}
- (void)layoutSubviews {
 [super layoutSubviews]; CGFloat width=MIN(360,self.bounds.size.width-32),inside=width-48;
 CGFloat titleH=self.title.text.length ? ceil([self.title.text sizeWithFont:self.title.font constrainedToSize:CGSizeMake(inside,1000) lineBreakMode:NSLineBreakByWordWrapping].height) : 0;
 CGFloat messageH=self.message.text.length ? ceil([self.message.text sizeWithFont:self.message.font constrainedToSize:CGSizeMake(inside,1000) lineBreakMode:NSLineBreakByWordWrapping].height) : 0;
 CGFloat y=24; self.title.frame=CGRectMake(24,y,inside,titleH); y+=titleH+(titleH ? 12 : 0); self.message.frame=CGRectMake(24,y,inside,messageH); y+=messageH+(messageH ? 16 : 0);
 for(UITextField *field in self.fields) { field.frame=CGRectMake(24,y,inside,44); y+=52; }
 if(self.sheet) { for(UIButton *button in self.buttons) { button.frame=CGRectMake(8,y,width-16,48); y+=48; } }
 else { CGFloat buttonWidth=(width-32)/MAX(1,self.buttons.count); for(NSUInteger i=0;i<self.buttons.count;i++)((UIButton *)self.buttons[i]).frame=CGRectMake(16+i*buttonWidth,y,buttonWidth,44); y+=44; }
 CGFloat height=MIN(y+12,MAX(120,self.bounds.size.height-(self.fields.count ? 230 : 48))); ((UIScrollView *)self.card).contentSize=CGSizeMake(width,y+12); self.card.frame=CGRectMake((self.bounds.size.width-width)/2,self.sheet ? self.bounds.size.height-height-12 : MAX(24,(self.bounds.size.height-height)/2-(self.fields.count ? 70 : 0)),width,height);
}
- (void)cancel { NSInteger index=self.sheet ? [(UIActionSheet *)self.owner cancelButtonIndex] : [(UIAlertView *)self.owner cancelButtonIndex]; if(index>=0)[self dismiss:index animated:YES]; }
- (void)chosen:(UIButton *)button { [self dismiss:button.tag animated:YES]; }
- (void)dismiss:(NSInteger)index animated:(BOOL)animated {
 if(self.closing)return; self.closing=YES; self.userInteractionEnabled=NO; [self endEditing:YES];
 for(NSUInteger i=0;i<self.fields.count;i++) [self.owner textFieldAtIndex:i].text=[self.fields[i] text];
 void (^finish)(void)=^{ id owner=self.owner; BOOL sheet=self.sheet; [self removeFromSuperview]; TGAssociateFlatDialog(owner,nil); self.owner=nil; TGDialogDelegate(owner,index,sheet); };
 if(animated) { [CATransaction begin]; [CATransaction setDisableActions:YES]; [CATransaction setCompletionBlock:finish]; self.layer.opacity=0; TGMaterialAnimate(self.layer,@"opacity",@1,@0,.16); [CATransaction commit]; } else finish();
}
@end
BOOL TGPresentLegacyFlatDialog(id owner,BOOL sheet) {
 UIWindow *window=[UIApplication sharedApplication].keyWindow; if(!window)return NO;
 TGMaterialDialog *dialog=[[TGMaterialDialog alloc] initWithOwner:owner sheet:sheet]; TGAssociateFlatDialog(owner,dialog); [window addSubview:dialog]; [dialog layoutIfNeeded];
 if(sheet) TGMaterialSlidePanel(dialog.card,dialog.scrim,YES,nil);
 else { TGMaterialAnimate(dialog.card.layer,@"transform.scale",@.92,@1,.2); TGMaterialAnimate(dialog.scrim.layer,@"opacity",@0,@1,.2); }
 return YES;
}
BOOL TGDismissLegacyFlatDialog(id dialog,NSInteger index,BOOL animated) { if(![dialog isKindOfClass:[TGMaterialDialog class]])return NO; [dialog dismiss:index animated:animated]; return YES; }
