#import "TGFlatKit.h"
#import "TGTheme.h"
#import "Seven/RT7UIKit.h"
#import <objc/runtime.h>
Class TGTextFieldClass(void) { return [RT7TextField class]; }
Class TGContactCellClass(void) { return NSClassFromString(@"RT27ContactCell"); }
Class TGSwitchClass(void) { return [RT7Switch class]; }
@implementation TGThemedNavigationController
- (instancetype)initWithRootViewController:(UIViewController *)root { if((self=[super initWithRootViewController:root])) { RT7PrepareScreen(root); self.navigationBar.translucent=NO; } return self; }
- (void)pushViewController:(UIViewController *)controller animated:(BOOL)animated {
    if(self.viewControllers.count && !controller.navigationItem.leftBarButtonItem) {
        RT7Button *back=[[RT7Button alloc] initWithFrame:CGRectMake(0,0,76,40)]; back.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
        [back setImage:RT7Icon(@"back",24,RT7Primary()) forState:UIControlStateNormal]; [back setTitle:@"Назад" forState:UIControlStateNormal]; back.titleEdgeInsets=UIEdgeInsetsMake(0,2,0,0); back.accessibilityLabel=@"Назад"; [back addTarget:self action:@selector(sevenBack) forControlEvents:UIControlEventTouchUpInside];
        controller.navigationItem.leftBarButtonItem=[[RT7BarButtonItem alloc] initWithCustomView:back];
    }
    [super pushViewController:controller animated:animated]; RT7PrepareScreen(controller);
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; RT7PrepareScreen(self.topViewController); }
- (void)sevenBack { [self popViewControllerAnimated:YES]; }
@end
@implementation RT7RootController { NSMutableArray *_badges; }
- (void)viewDidLoad { [super viewDidLoad]; _badges=[NSMutableArray array]; for(NSUInteger i=0;i<self.viewControllers.count;i++) { UILabel *badge=[[UILabel alloc] init]; badge.backgroundColor=RT7Error(); badge.textColor=[UIColor whiteColor]; badge.font=RT7Font(12,NO); badge.textAlignment=NSTextAlignmentCenter; badge.layer.cornerRadius=9; badge.clipsToBounds=YES; badge.userInteractionEnabled=NO; [self.tabBar addSubview:badge]; [_badges addObject:badge]; } [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSevenBadges) name:@"RT7TabBadgeChanged" object:nil]; [self updateSevenBadges]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self updateSevenBadges]; }
- (void)updateSevenBadges { CGFloat slot=self.tabBar.bounds.size.width/MAX(1,self.viewControllers.count); for(NSUInteger i=0;i<_badges.count;i++) { UILabel *badge=_badges[i]; NSString *text=[self.viewControllers[i] tabBarItem].badgeValue; badge.hidden=!text.length || text.integerValue==0; badge.text=text.integerValue>99 ? @"99+" : text; CGFloat width=MAX(18,ceil([badge.text sizeWithFont:badge.font].width)+8); badge.frame=CGRectMake((i+.5)*slot+7,3,width,18); [self.tabBar bringSubviewToFront:badge]; } }
- (UIView *)contentView { return self.selectedViewController.view; }
@end
RT7RootController *RT7RootForController(UIViewController *controller) { for(UIViewController *node=controller;node;node=node.parentViewController)if([node isKindOfClass:[RT7RootController class]])return (id)node; return nil; }
void TGInstallFlatTabBar(RT7RootController *controller) {
    UITabBar *bar=controller.tabBar; bar.tintColor=RT7Primary();
    bar.backgroundImage=RT7Shape(CGSizeMake(2,2),[UIColor colorWithWhite:.98 alpha:1],0); bar.selectionIndicatorImage=RT7Shape(CGSizeMake(2,2),[UIColor clearColor],0);
    if([bar respondsToSelector:@selector(setShadowImage:)])bar.shadowImage=RT7Shape(CGSizeMake(1,1),RT7Outline(),0);
    NSArray *icons=@[@"contacts",@"chat",@"settings"];
    for(NSUInteger i=0;i<controller.viewControllers.count;i++) {
        UITabBarItem *item=[controller.viewControllers[i] tabBarItem]; UIImage *normal=RT7Icon(icons[MIN(i,2)],26,RT7SecondaryText()),*selected=RT7Icon(icons[MIN(i,2)],26,RT7Primary());
        [item setFinishedSelectedImage:selected withFinishedUnselectedImage:normal];
        [item setTitleTextAttributes:@{UITextAttributeFont:RT7Font(10,NO),UITextAttributeTextColor:RT7SecondaryText(),UITextAttributeTextShadowColor:[UIColor clearColor]} forState:UIControlStateNormal];
        [item setTitleTextAttributes:@{UITextAttributeTextColor:RT7Primary()} forState:UIControlStateSelected];
    }
}
void TGUpdateFlatTabBar(RT7RootController *controller) { (void)controller; }
#import <objc/message.h>
extern void TGAssociateFlatDialog(id,id);
static void TGDialogDelegate(id owner,NSInteger index,BOOL sheet) {
 id delegate=[owner delegate]; NSArray *selectors=sheet ? @[@"actionSheet:clickedButtonAtIndex:",@"actionSheet:willDismissWithButtonIndex:",@"actionSheet:didDismissWithButtonIndex:"] : @[@"alertView:clickedButtonAtIndex:",@"alertView:willDismissWithButtonIndex:",@"alertView:didDismissWithButtonIndex:"];
 for(NSString *name in selectors) { SEL sel=NSSelectorFromString(name); if([delegate respondsToSelector:sel])((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,sel,owner,index); }
}
@interface RT7Dialog : UIView
@property(nonatomic,strong) id owner;
@property(nonatomic,strong) UIView *card;
@property(nonatomic,strong) UIControl *scrim;
@property(nonatomic,strong) UILabel *title,*message;
@property(nonatomic,strong) NSArray *buttons,*fields;
@property(nonatomic) BOOL sheet,closing;
- (instancetype)initWithOwner:(id)owner sheet:(BOOL)sheet;
- (void)dismiss:(NSInteger)index animated:(BOOL)animated;
@end
@implementation RT7Dialog
- (instancetype)initWithOwner:(id)owner sheet:(BOOL)sheet {
 if((self=[super initWithFrame:[UIApplication sharedApplication].keyWindow.bounds])) {
  self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; self.owner=owner; self.sheet=sheet;
  self.scrim=[[UIControl alloc] initWithFrame:self.bounds]; self.scrim.autoresizingMask=self.autoresizingMask; self.scrim.backgroundColor=[RT7Text() colorWithAlphaComponent:.38]; [self.scrim addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:self.scrim];
  self.card=[[UIScrollView alloc] init]; self.card.clipsToBounds=YES; ((UIScrollView *)self.card).showsVerticalScrollIndicator=NO; self.card.backgroundColor=RT7Canvas(); self.card.layer.cornerRadius=13; [self addSubview:self.card];
  self.title=[[UILabel alloc] init]; self.title.text=[owner title]; self.title.font=RT7Font(17,YES); self.title.textColor=RT7Text(); self.title.numberOfLines=0; self.title.backgroundColor=[UIColor clearColor]; [self.card addSubview:self.title];
  self.message=[[UILabel alloc] init]; self.message.text=sheet ? nil : [(UIAlertView *)owner message]; self.message.font=RT7Font(14,NO); self.message.textColor=RT7SecondaryText(); self.message.numberOfLines=0; self.message.backgroundColor=[UIColor clearColor]; [self.card addSubview:self.message];
  NSMutableArray *fields=[NSMutableArray array]; NSInteger count=sheet || [(UIAlertView *)owner alertViewStyle]==UIAlertViewStyleDefault ? 0 : [(UIAlertView *)owner alertViewStyle]==UIAlertViewStyleLoginAndPasswordInput ? 2 : 1;
  for(NSInteger i=0;i<count;i++) { UITextField *source=[owner textFieldAtIndex:i]; UITextField *field=[[RT7TextField alloc] initWithFrame:CGRectZero]; field.text=source.text; field.placeholder=source.placeholder; field.secureTextEntry=source.secureTextEntry; field.keyboardType=source.keyboardType; [self.card addSubview:field]; [fields addObject:field]; } self.fields=fields;
  NSMutableArray *buttons=[NSMutableArray array];
  for(NSInteger i=0;i<[owner numberOfButtons];i++) { UIButton *button=[[RT7Button alloc] initWithFrame:CGRectZero]; button.tag=i; [button setTitle:[owner buttonTitleAtIndex:i] forState:UIControlStateNormal]; if(sheet && i==[(UIActionSheet *)owner destructiveButtonIndex])[button setTitleColor:RT7Error() forState:UIControlStateNormal]; button.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter; button.contentEdgeInsets=UIEdgeInsetsMake(0,16,0,16); [button addTarget:self action:@selector(chosen:) forControlEvents:UIControlEventTouchUpInside]; [self.card addSubview:button]; [buttons addObject:button]; } self.buttons=buttons;
 }
 return self;
}
- (void)layoutSubviews {
 [super layoutSubviews]; CGFloat width=self.sheet ? self.bounds.size.width-16 : MIN(270,self.bounds.size.width-32),inside=width-48;
 CGFloat titleH=self.title.text.length ? ceil([self.title.text sizeWithFont:self.title.font constrainedToSize:CGSizeMake(inside,1000) lineBreakMode:NSLineBreakByWordWrapping].height) : 0;
 CGFloat messageH=self.message.text.length ? ceil([self.message.text sizeWithFont:self.message.font constrainedToSize:CGSizeMake(inside,1000) lineBreakMode:NSLineBreakByWordWrapping].height) : 0;
 CGFloat y=24; self.title.frame=CGRectMake(24,y,inside,titleH); y+=titleH+(titleH ? 12 : 0); self.message.frame=CGRectMake(24,y,inside,messageH); y+=messageH+(messageH ? 16 : 0);
 for(UITextField *field in self.fields) { field.frame=CGRectMake(24,y,inside,44); y+=52; }
 if(self.sheet) { for(UIButton *button in self.buttons) { button.frame=CGRectMake(8,y,width-16,44); y+=44; } }
 else { CGFloat buttonWidth=(width-32)/MAX(1,self.buttons.count); for(NSUInteger i=0;i<self.buttons.count;i++)((UIButton *)self.buttons[i]).frame=CGRectMake(16+i*buttonWidth,y,buttonWidth,44); y+=44; }
 CGFloat height=MIN(y+12,MAX(120,self.bounds.size.height-(self.fields.count ? 230 : 48))); ((UIScrollView *)self.card).contentSize=CGSizeMake(width,y+12); self.card.frame=CGRectMake((self.bounds.size.width-width)/2,self.sheet ? self.bounds.size.height-height-12 : MAX(24,(self.bounds.size.height-height)/2-(self.fields.count ? 70 : 0)),width,height);
}
- (void)cancel { NSInteger index=self.sheet ? [(UIActionSheet *)self.owner cancelButtonIndex] : [(UIAlertView *)self.owner cancelButtonIndex]; if(index>=0)[self dismiss:index animated:YES]; }
- (void)chosen:(UIButton *)button { [self dismiss:button.tag animated:YES]; }
- (void)dismiss:(NSInteger)index animated:(BOOL)animated {
 if(self.closing)return; self.closing=YES; self.userInteractionEnabled=NO; [self endEditing:YES];
 for(NSUInteger i=0;i<self.fields.count;i++) [self.owner textFieldAtIndex:i].text=[self.fields[i] text];
 void (^finish)(void)=^{ id owner=self.owner; BOOL sheet=self.sheet; [self removeFromSuperview]; TGAssociateFlatDialog(owner,nil); self.owner=nil; TGDialogDelegate(owner,index,sheet); };
 if(animated) { [CATransaction begin]; [CATransaction setDisableActions:YES]; [CATransaction setCompletionBlock:finish]; self.layer.opacity=0; RT7Animate(self.layer,@"opacity",@1,@0,.16); [CATransaction commit]; } else finish();
}
@end
BOOL TGPresentLegacyFlatDialog(id owner,BOOL sheet) {
 UIWindow *window=[UIApplication sharedApplication].keyWindow; if(!window)return NO;
 RT7Dialog *dialog=[[RT7Dialog alloc] initWithOwner:owner sheet:sheet]; TGAssociateFlatDialog(owner,dialog); [window addSubview:dialog]; [dialog layoutIfNeeded];
 if(sheet) RT7SlidePanel(dialog.card,dialog.scrim,YES,nil);
 else { RT7Animate(dialog.card.layer,@"transform.scale",@.92,@1,.2); RT7Animate(dialog.scrim.layer,@"opacity",@0,@1,.2); }
 return YES;
}
BOOL TGDismissLegacyFlatDialog(id dialog,NSInteger index,BOOL animated) { if(![dialog isKindOfClass:[RT7Dialog class]])return NO; [dialog dismiss:index animated:animated]; return YES; }
