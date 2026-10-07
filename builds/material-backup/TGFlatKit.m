#import "RT27TabBar.h"
#import "TGFlatKit.h"
#import "TGTheme.h"
#import "RT27ModernButton.h"
#import "RT27ModernBackToolbarButton.h"
#import "RT27ModernConversationTitleView.h"
#import "RT27TextField.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static RT27ModernButton *TGKitButton(void) {
    RT27ModernButton *button=[[RT27ModernButton alloc] initWithFrame:CGRectZero];
    button.titleLabel.font=RT27SystemFontOfSize(17);
    [button setTitleColor:RT27AccentColor()];
    [button setTitleColor:RT27ColorRGB(0x8e8e93) forState:UIControlStateDisabled];
    return button;
}
@interface TGFlatTextField : RT27TextField
@end
@implementation TGFlatTextField
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];
    if (self) { self.font=[UIFont fontWithName:@"HelveticaNeue" size:17]; self.textColor=[UIColor blackColor];
        self.backgroundColor=[UIColor whiteColor]; self.leftInset=8; self.placeholderColor=RT27ColorRGB(0xc7c7cd); self.placeholderFont=self.font; self.borderStyle=UITextBorderStyleNone; }
    return self;
}
@end
Class TGContactCellClass(void) { return NSClassFromString(TGModernThemeEnabled() ? @"RT27ContactCell" : @"TGContactCell"); }
Class TGTextFieldClass(void) { return TGModernThemeEnabled() ? [TGFlatTextField class] : [UITextField class]; }

#import "FUISwitch.h"
@interface TGFlatSwitch : FUISwitch
@end
@implementation TGFlatSwitch
- (instancetype)init { return [self initWithFrame:CGRectMake(0,0,51,31)]; }
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:CGRectMake(frame.origin.x,frame.origin.y,51,31)];
    if (self) { self.offBackgroundColor=[UIColor colorWithWhite:.9 alpha:1]; self.onBackgroundColor=[UIColor colorWithRed:.3 green:.85 blue:.39 alpha:1]; self.onColor=self.offColor=[UIColor whiteColor]; self.highlightedColor=[UIColor whiteColor]; self.switchCornerRadius=15.5; self.onLabel.text=self.offLabel.text=@""; [self setOn:NO]; }
    return self;
}
@end
Class TGSwitchClass(void) { return TGModernThemeEnabled() ? [TGFlatSwitch class] : [UISwitch class]; }

// Navigation items belong to UINavigationBar during push/pop transitions. Render
// independent controls; never reparent the live item/title views into our panel.
@interface TGFlatItemProxy : UIControl
@property(nonatomic,weak) UIView *source;
@property(nonatomic,copy) NSString *renderKey;
@property(nonatomic) BOOL titleContent;
- (void)refresh;
@end
@implementation TGFlatItemProxy
- (instancetype)initWithSource:(UIView *)source {
    self=[super initWithFrame:source.bounds];
    if(self) { self.source=source; self.clipsToBounds=YES; self.exclusiveTouch=YES; self.accessibilityLabel=source.accessibilityLabel; [self addTarget:self action:@selector(activate) forControlEvents:UIControlEventTouchUpInside]; }
    return self;
}
- (void)activate {
    if ([self.source isKindOfClass:[UIControl class]]) [(UIControl *)self.source sendActionsForControlEvents:UIControlEventTouchUpInside];
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha=self.enabled ? (highlighted ? .4 : 1) : .45;
}
- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alpha=enabled ? (self.highlighted ? .4 : 1) : .45;
}
- (void)refresh {
    UIView *source=self.source;
    UIButton *button=[source isKindOfClass:[UIButton class]] ? (UIButton *)source : nil;
    NSMutableString *key=[NSMutableString stringWithFormat:@"%@:%@:%d",NSStringFromCGRect(self.bounds),NSStringFromCGRect(source.bounds),self.titleContent];
    if (button) [key appendFormat:@"%p:%@:%@:%@",button.currentImage,button.currentTitle,NSStringFromUIEdgeInsets(button.imageEdgeInsets),NSStringFromUIEdgeInsets(button.contentEdgeInsets)];
    for (UIView *child in source.subviews) {
        [key appendFormat:@"%@:%d",NSStringFromCGRect(child.frame),child.hidden];
        if ([child isKindOfClass:[UILabel class]]) [key appendFormat:@"%@:%@:%@",((UILabel *)child).text,((UILabel *)child).font,((UILabel *)child).textColor];
        if ([child isKindOfClass:[UIImageView class]]) [key appendFormat:@"%p",((UIImageView *)child).image];
    }
    self.enabled=![self.source isKindOfClass:[UIControl class]] || ((UIControl *)self.source).enabled;
    if ([self.renderKey isEqual:key]) return;
    self.renderKey=key;
    for (UIView *child in [self.subviews copy]) [child removeFromSuperview];
    if (button.currentImage) {
        UIImageView *view=[[UIImageView alloc] initWithImage:button.currentImage];
        CGRect area=UIEdgeInsetsInsetRect(self.bounds,button.contentEdgeInsets);
        area=UIEdgeInsetsInsetRect(area,button.imageEdgeInsets);
        CGSize size=button.currentImage.size;
        CGFloat scale=MIN(1,MIN(MAX(0,area.size.width)/MAX(1,size.width),MAX(0,area.size.height)/MAX(1,size.height)));
        size=CGSizeMake(size.width*scale,size.height*scale);
        view.frame=CGRectMake(RT27RetinaFloor(CGRectGetMidX(area)-size.width/2),RT27RetinaFloor(CGRectGetMidY(area)-size.height/2),size.width,size.height);
        view.contentMode=UIViewContentModeScaleAspectFit; [self addSubview:view];
    }
    if (button.currentTitle.length) {
        UILabel *label=[[UILabel alloc] initWithFrame:UIEdgeInsetsInsetRect(self.bounds,button.contentEdgeInsets)];
        label.text=button.currentTitle; label.font=button.titleLabel.font ?: RT27SystemFontOfSize(17);
        label.textAlignment=NSTextAlignmentCenter; label.lineBreakMode=NSLineBreakByTruncatingTail;
        label.backgroundColor=[UIColor clearColor]; label.textColor=button.currentTitleColor ?: RT27AccentColor(); [self addSubview:label];
    }
    CGFloat dx=(self.bounds.size.width-source.bounds.size.width)/2,dy=(self.bounds.size.height-source.bounds.size.height)/2;
    for (UIView *child in source.subviews) {
        // UIButton's public image/title have already been copied above. Copying
        // the internal views again used to stretch each icon across the item.
        if (button && (child==button.imageView || child==button.titleLabel)) continue;
        if ([child isKindOfClass:[UILabel class]] && !child.hidden) {
            UILabel *original=(UILabel *)child; CGRect frame=CGRectOffset(child.frame,dx,dy);
            if (self.titleContent) frame=CGRectMake(0,frame.origin.y,self.bounds.size.width,frame.size.height);
            UILabel *label=[[UILabel alloc] initWithFrame:frame];
            label.text=original.text; label.font=original.font; label.textAlignment=original.textAlignment; label.lineBreakMode=original.lineBreakMode;
            label.backgroundColor=[UIColor clearColor]; label.textColor=self.titleContent ? (child.frame.origin.y<20 ? [UIColor blackColor] : TGModernSecondaryText()) : RT27AccentColor(); [self addSubview:label];
        } else if ([child isKindOfClass:[UIImageView class]] && !child.hidden) {
            UIImageView *original=(UIImageView *)child;
            UIImageView *view=[[UIImageView alloc] initWithImage:original.image]; view.frame=CGRectOffset(original.frame,dx,dy);
            view.contentMode=original.contentMode; view.clipsToBounds=original.clipsToBounds; view.layer.cornerRadius=original.layer.cornerRadius; [self addSubview:view];
        }
    }
    self.enabled=![source isKindOfClass:[UIControl class]] || ((UIControl *)source).enabled;
}
@end

@interface TGFlatBackButton : RT27ModernBackToolbarButton
@end
@implementation TGFlatBackButton
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect frame=self.buttonTitleLabel.frame;
    frame.origin.y=RT27RetinaFloor((self.bounds.size.height-frame.size.height)/2);
    self.buttonTitleLabel.frame=frame;
}
@end

// Telegram 2.7 lays its title/status around a zero-height center anchor.
// The container supplies that anchor and bounds both rendering and taps to the
// free space between the navigation buttons on narrow phones.
@interface TGFlatConversationTitleContainer : UIView
@property(nonatomic,strong) RT27ModernConversationTitleView *replica;
@end
@implementation TGFlatConversationTitleContainer
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];
    if (self) { self.clipsToBounds=YES; self.replica=[[RT27ModernConversationTitleView alloc] initWithFrame:CGRectZero]; [self addSubview:self.replica]; }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.replica.frame=CGRectMake(0,RT27RetinaFloor(self.bounds.size.height/2),self.bounds.size.width,0);
    [self.replica setNeedsLayout]; [self.replica layoutIfNeeded];
    CGFloat typingX=0,typingY=0;
    for (UIView *view in self.replica.subviews) if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label=(UILabel *)view; CGRect frame=label.frame;
        BOOL typingStatus=self.replica.typingStatus.length>0 && label.font.pointSize<15;
        CGFloat width=MIN(frame.size.width,MAX(0,self.bounds.size.width-(typingStatus ? 24 : 4)));
        frame.origin.x=RT27RetinaFloor((self.bounds.size.width-width)/2)+(typingStatus ? 10 : 0); frame.size.width=width;
        label.lineBreakMode=NSLineBreakByTruncatingTail; label.frame=frame;
        if (typingStatus) { typingX=frame.origin.x-24; typingY=frame.origin.y; }
    }
    if (self.replica.typingStatus.length>0) for (UIView *view in self.replica.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"RT27ModernConversationTitleActivityIndicator"]) view.frame=CGRectMake(typingX,typingY,24,16);
    }
}
@end

@interface TGFlatNavigationBar : UINavigationBar
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UILabel *heading;
@property(nonatomic,strong) RT27ModernButton *back;
@property(nonatomic,strong) UIView *line;
@property(nonatomic,strong) NSMutableArray *itemButtons;
@property(nonatomic,strong) NSArray *renderedItems;
@property(nonatomic,weak) UINavigationController *navigation;
@property(nonatomic,weak) UIView *embeddedTitle;
@property(nonatomic,strong) RT27ModernConversationTitleView *titleReplica;
@property(nonatomic,strong) TGFlatConversationTitleContainer *titleContainer;
@end
@implementation TGFlatNavigationBar
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];
    if (self) {
        self.translucent=NO; self.backgroundColor=[UIColor whiteColor];
        [self setBackgroundImage:TGFlatImage([UIColor whiteColor]) forBarMetrics:UIBarMetricsDefault];
        self.panel=[[UIView alloc] init]; self.panel.backgroundColor=[UIColor whiteColor]; [self addSubview:self.panel];
        self.heading=[[UILabel alloc] init]; self.heading.font=[UIFont fontWithName:@"HelveticaNeue-Medium" size:17];
        self.heading.textColor=[UIColor blackColor]; self.heading.backgroundColor=[UIColor clearColor];
        self.heading.textAlignment=NSTextAlignmentCenter; self.heading.lineBreakMode=NSLineBreakByTruncatingTail; [self.panel addSubview:self.heading];
        self.back=[[TGFlatBackButton alloc] initWithLightMode];
        self.back.imageView.contentMode=UIViewContentModeScaleAspectFit;
        [self.back addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside]; [self.panel addSubview:self.back];
        self.itemButtons=[NSMutableArray array]; self.line=[[UIView alloc] init]; self.line.backgroundColor=TGModernSeparator(); [self.panel addSubview:self.line];
    } return self;
}
- (void)goBack { [self.navigation popViewControllerAnimated:YES]; }
- (void)invokeItem:(UIButton *)button {
    if (button.tag>=self.renderedItems.count) return;
    UIBarButtonItem *item=self.renderedItems[button.tag];
    if (item.enabled && item.action) [[UIApplication sharedApplication] sendAction:item.action to:item.target from:item forEvent:nil];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    for (UIView *view in self.subviews) if (view!=self.panel) view.hidden=YES;
    if (self.subviews.lastObject!=self.panel) [self bringSubviewToFront:self.panel]; self.panel.frame=self.bounds;
    self.panel.backgroundColor=self.backgroundColor ?: [UIColor whiteColor]; self.line.hidden=self.tag==712028;
    CGFloat width=self.bounds.size.width,height=self.bounds.size.height;
    UINavigationItem *item=self.topItem; BOOL hasBack=self.navigation.viewControllers.count>1;
    NSArray *left=item.leftBarButtonItems ?: (item.leftBarButtonItem ? @[item.leftBarButtonItem] : @[]);
    NSArray *right=item.rightBarButtonItems ?: (item.rightBarButtonItem ? @[item.rightBarButtonItem] : @[]);
    NSArray *items=[left arrayByAddingObjectsFromArray:right];
    if (![self.renderedItems isEqual:items]) {
        for (UIView *view in self.itemButtons) [view removeFromSuperview]; [self.itemButtons removeAllObjects]; self.renderedItems=items;
        for (NSUInteger i=0;i<items.count;i++) {
            UIBarButtonItem *barItem=items[i]; UIView *view=barItem.customView ? [[TGFlatItemProxy alloc] initWithSource:barItem.customView] : nil;
            if (!view) { RT27ModernButton *button=TGKitButton(); button.tag=i;
                [button addTarget:self action:@selector(invokeItem:) forControlEvents:UIControlEventTouchUpInside]; view=button; }
            [self.itemButtons addObject:view]; [self.panel addSubview:view];
        }
    }
    CGFloat leftEdge=8,rightEdge=width-8;
    self.back.hidden=!hasBack || left.count>0;
    if (!self.back.hidden) { self.back.frame=CGRectMake(4,0,68,height); leftEdge=76; }
    for (NSUInteger i=0;i<items.count;i++) {
        UIBarButtonItem *barItem=items[i]; UIView *view=self.itemButtons[i]; CGFloat desired=44;
        if (!barItem.customView) {
            RT27ModernButton *button=(RT27ModernButton *)view; [button setTitle:barItem.title forState:UIControlStateNormal]; [button setImage:barItem.image forState:UIControlStateNormal]; button.enabled=barItem.enabled;
            if (barItem.title.length) desired=MAX(44,ceil([barItem.title sizeWithFont:button.titleLabel.font].width)+12);
        } else desired=MAX(44,barItem.customView.bounds.size.width);
        desired=MIN(desired,width*.3);
        if (i<left.count) { view.frame=CGRectMake(leftEdge,(height-MIN(height,44))/2,desired,MIN(height,44)); leftEdge+=desired+4; }
        else { rightEdge-=desired; view.frame=CGRectMake(rightEdge,(height-MIN(height,44))/2,desired,MIN(height,44)); rightEdge-=4; }
        if ([view isKindOfClass:[TGFlatItemProxy class]]) { ((TGFlatItemProxy *)view).source=barItem.customView; [(TGFlatItemProxy *)view refresh]; ((UIControl *)view).enabled=barItem.enabled && ((UIControl *)view).enabled; }
    }
    CGFloat titleInset=MAX(leftEdge,width-rightEdge);
    CGFloat available=MAX(0,width-titleInset*2); CGRect titleFrame=CGRectMake(titleInset,0,available,height);
    UIView *title=item.titleView;
    BOOL originalTitle=[title isKindOfClass:[RT27ModernConversationTitleView class]];
    TGFlatItemProxy *proxy=(TGFlatItemProxy *)self.embeddedTitle;
    if (proxy.source!=title || originalTitle) {
        [proxy removeFromSuperview]; proxy=nil;
        if(title && !originalTitle) { proxy=[[TGFlatItemProxy alloc] initWithSource:title]; proxy.titleContent=YES; [self.panel addSubview:proxy]; }
        self.embeddedTitle=proxy;
    }
    self.heading.hidden=title!=nil; self.heading.text=item.title; self.heading.frame=titleFrame;
    if (proxy) { proxy.frame=titleFrame; [proxy refresh]; }
    if(originalTitle) {
        if(!self.titleReplica) { self.titleContainer=[[TGFlatConversationTitleContainer alloc] initWithFrame:titleFrame]; self.titleReplica=self.titleContainer.replica; [self.panel addSubview:self.titleContainer]; }
        RT27ModernConversationTitleView *source=(RT27ModernConversationTitleView *)title;
        self.titleContainer.hidden=NO; self.titleContainer.frame=titleFrame;
        self.titleReplica.delegate=source.delegate; self.titleReplica.title=source.title;
        self.titleReplica.status=source.status; self.titleReplica.statusHasAccentColor=source.statusHasAccentColor;
        self.titleReplica.typingStatus=source.typingStatus;
        [self.titleReplica setOrientation:UIInterfaceOrientationPortrait];
        [self.titleContainer setNeedsLayout];
    } else self.titleContainer.hidden=YES;
    self.line.frame=CGRectMake(0,height-RT27RetinaPixel,width,RT27RetinaPixel);
}
@end
@implementation TGThemedNavigationController
- (instancetype)initWithRootViewController:(UIViewController *)root {
    if (!TGModernThemeEnabled()) return [super initWithRootViewController:root];
    self=[super initWithNavigationBarClass:[TGFlatNavigationBar class] toolbarClass:nil];
    if (self) { ((TGFlatNavigationBar *)self.navigationBar).navigation=self; self.viewControllers=@[root]; }
    return self;
}
@end

@interface TGFlatTabStrip : RT27TabBar <RT27TabBarDelegate>
@property(nonatomic,weak) UITabBarController *controller;
@property(nonatomic,copy) NSString *lastBadge;
- (instancetype)initWithController:(UITabBarController *)controller;
@end
@implementation TGFlatTabStrip
- (instancetype)initWithController:(UITabBarController *)controller {
    self=[super initWithFrame:controller.tabBar.bounds];
    if(self) { self.controller=controller; self.tabDelegate=self; self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; }
    return self;
}
- (void)tabBarSelectedItem:(int)index {
    if (index<0 || index>=(int)self.controller.viewControllers.count) return;
    self.controller.selectedIndex=index;
    if([self.controller.delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)]) [self.controller.delegate tabBarController:self.controller didSelectViewController:self.controller.selectedViewController];
}
- (void)layoutSubviews {
    if(self.selectedIndex!=(int)self.controller.selectedIndex) self.selectedIndex=(int)self.controller.selectedIndex;
    NSString *badge=self.controller.viewControllers.count>1 ? [self.controller.viewControllers[1] tabBarItem].badgeValue ?: @"" : @"";
    if(![self.lastBadge isEqual:badge]) { self.lastBadge=badge ?: @""; [self setUnreadCount:badge.intValue]; }
    [super layoutSubviews];
}
@end
static char TGFlatTabKey;
void TGInstallFlatTabBar(UITabBarController *controller) {
    TGFlatTabStrip *strip=objc_getAssociatedObject(controller,&TGFlatTabKey);
    if (!TGModernThemeEnabled()) { [strip removeFromSuperview]; objc_setAssociatedObject(controller,&TGFlatTabKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
    if (!strip) { strip=[[TGFlatTabStrip alloc] initWithController:controller]; objc_setAssociatedObject(controller,&TGFlatTabKey,strip,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    for (UIView *view in controller.tabBar.subviews) if (view!=strip) view.hidden=YES;
    if (strip.superview!=controller.tabBar) [controller.tabBar addSubview:strip];
    else if (controller.tabBar.subviews.lastObject!=strip) [controller.tabBar bringSubviewToFront:strip];
    strip.frame=controller.tabBar.bounds; [strip setNeedsLayout];
}
void TGUpdateFlatTabBar(UITabBarController *controller) { TGInstallFlatTabBar(controller); }

#import "FUIAlertView.h"
#import <objc/message.h>
extern void TGAssociateFlatDialog(id,id);
static void TGDialogDelegate(id owner, NSInteger index, BOOL sheet, BOOL clicked) {
    id delegate=[owner delegate];
    SEL click=sheet ? @selector(actionSheet:clickedButtonAtIndex:) : @selector(alertView:clickedButtonAtIndex:);
    SEL will=sheet ? @selector(actionSheet:willDismissWithButtonIndex:) : @selector(alertView:willDismissWithButtonIndex:);
    SEL did=sheet ? @selector(actionSheet:didDismissWithButtonIndex:) : @selector(alertView:didDismissWithButtonIndex:);
    if (clicked && [delegate respondsToSelector:click]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,click,owner,index);
    if ([delegate respondsToSelector:will]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,will,owner,index);
    if ([delegate respondsToSelector:did]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,did,owner,index);
}
@interface TGFlatSheet : UIView
@property(nonatomic,strong) UIActionSheet *owner;
@property(nonatomic,strong) UIView *card;
@property(nonatomic,strong) UILabel *heading;
@property(nonatomic,strong) NSArray *buttons;
- (void)dismiss:(NSInteger)index animated:(BOOL)animated clicked:(BOOL)clicked;
@end
@implementation TGFlatSheet
- (instancetype)initWithOwner:(UIActionSheet *)owner {
    self=[super initWithFrame:[UIApplication sharedApplication].keyWindow.bounds];
    if (self) { self.owner=owner; self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.backgroundColor=[UIColor colorWithWhite:0 alpha:.35]; self.card=[[UIView alloc] init]; self.card.backgroundColor=[UIColor clearColor]; [self addSubview:self.card];
        self.heading=[[UILabel alloc] init]; self.heading.text=owner.title; self.heading.font=[UIFont fontWithName:@"HelveticaNeue" size:13]; self.heading.textColor=TGModernSecondaryText(); self.heading.textAlignment=NSTextAlignmentCenter; self.heading.backgroundColor=[UIColor whiteColor]; self.heading.numberOfLines=0; [self.card addSubview:self.heading];
        NSMutableArray *buttons=[NSMutableArray array];
        for (NSInteger i=0;i<owner.numberOfButtons;i++) { RT27ModernButton *button=TGKitButton(); button.tag=i; button.backgroundColor=[UIColor whiteColor]; button.layer.cornerRadius=6; [button setTitle:[owner buttonTitleAtIndex:i] forState:UIControlStateNormal];
            if (i==owner.destructiveButtonIndex) [button setTitleColor:[UIColor colorWithRed:1 green:.23 blue:.19 alpha:1] forState:UIControlStateNormal];
            [button addTarget:self action:@selector(chosen:) forControlEvents:UIControlEventTouchUpInside]; [self.card addSubview:button]; [buttons addObject:button]; }
        self.buttons=buttons;
    } return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat width=self.bounds.size.width-16;
    CGFloat title=self.owner.title.length ? TGModernSectionHeight(self.owner.title,width,NO) : 0;
    CGFloat height=title+self.buttons.count*50+8;
    self.card.frame=CGRectMake(8,MAX(8,self.bounds.size.height-height-8),width,height);
    self.heading.frame=CGRectMake(0,0,width,title);
    CGFloat y=title;
    for (UIButton *button in self.buttons) if (button.tag!=self.owner.cancelButtonIndex) { button.frame=CGRectMake(0,y,width,49.5); y+=50; }
    for (UIButton *button in self.buttons) if (button.tag==self.owner.cancelButtonIndex) button.frame=CGRectMake(0,y+8,width,50);
}
- (void)chosen:(UIButton *)button { [self dismiss:button.tag animated:YES clicked:YES]; }
- (void)dismiss:(NSInteger)index animated:(BOOL)animated clicked:(BOOL)clicked {
    [UIView animateWithDuration:animated ? .2 : 0 animations:^{ self.alpha=0; } completion:^(BOOL finished) {
        [self removeFromSuperview]; TGAssociateFlatDialog(self.owner,nil); TGDialogDelegate(self.owner,index,YES,clicked); self.owner=nil;
    }];
}
@end
BOOL TGPresentLegacyFlatDialog(id owner, BOOL sheet) {
    UIWindow *window=[UIApplication sharedApplication].keyWindow; if (!window) return NO;
    extern void TGAssociateFlatDialog(id,id);
    if (sheet) { TGFlatSheet *view=[[TGFlatSheet alloc] initWithOwner:owner]; TGAssociateFlatDialog(owner,view); [window addSubview:view]; return YES; }
    UIAlertView *original=owner;
    FUIAlertView *alert=[[FUIAlertView alloc] initWithTitle:original.title message:original.message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    for (NSInteger i=0;i<original.numberOfButtons;i++) [alert addButtonWithTitle:[original buttonTitleAtIndex:i]];
    alert.cancelButtonIndex=original.cancelButtonIndex; alert.alertViewStyle=(FUIAlertViewStyle)original.alertViewStyle;
    alert.backgroundOverlay.backgroundColor=[UIColor colorWithWhite:0 alpha:.35]; alert.alertContainer.backgroundColor=[UIColor whiteColor]; alert.alertContainer.layer.cornerRadius=12;
    alert.titleLabel.font=[UIFont fontWithName:@"HelveticaNeue-Medium" size:17]; alert.titleLabel.textColor=[UIColor blackColor]; alert.messageLabel.font=[UIFont fontWithName:@"HelveticaNeue" size:14]; alert.messageLabel.textColor=TGModernSecondaryText();
    alert.defaultButtonFont=[UIFont fontWithName:@"HelveticaNeue" size:17]; alert.defaultButtonColor=[UIColor whiteColor]; alert.defaultButtonTitleColor=TGModernBlue(); alert.defaultButtonShadowColor=[UIColor clearColor]; alert.defaultButtonShadowHeight=0; alert.defaultButtonCornerRadius=0; alert.buttonSpacing=0;
    NSUInteger count=original.alertViewStyle==UIAlertViewStyleDefault ? 0 : original.alertViewStyle==UIAlertViewStyleLoginAndPasswordInput ? 2 : 1;
    for (NSUInteger i=0;i<count;i++) { UITextField *from=[original textFieldAtIndex:i],*to=[alert textFieldAtIndex:i]; to.text=from.text; to.placeholder=from.placeholder; to.keyboardType=from.keyboardType; }
    __weak FUIAlertView *weakAlert=alert;
    alert.onDismissAction=^{
        FUIAlertView *current=weakAlert;
        for (NSUInteger i=0;i<count;i++) [original textFieldAtIndex:i].text=[current textFieldAtIndex:i].text;
        TGAssociateFlatDialog(original,nil); TGDialogDelegate(original,current.dismissButtonIndex,NO,YES);
    };
    TGAssociateFlatDialog(owner,alert); [alert show]; return YES;
}
BOOL TGDismissLegacyFlatDialog(id dialog, NSInteger index, BOOL animated) {
    if ([dialog isKindOfClass:[TGFlatSheet class]]) { [(TGFlatSheet *)dialog dismiss:index animated:animated clicked:NO]; return YES; }
    if ([dialog isKindOfClass:[FUIAlertView class]]) { [(FUIAlertView *)dialog dismissWithClickedButtonIndex:index animated:animated]; return YES; }
    return NO;
}
