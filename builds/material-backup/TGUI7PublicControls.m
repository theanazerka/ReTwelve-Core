#import "RT27TableRowAdapter.h"
#import "TGFlatKit.h"
#import "TGTheme.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import "FUISwitch.h"
#import "RT27ModernButton.h"
#import "FUISegmentedControl.h"

// FlatUIKit constructor adapters for existing application screens on iOS 6+.
// Private UIKit methods and global UI7Kit patches are not used.
static BOOL TGFlatControls(void) {
    return TGModernThemeEnabled();
}
static void TGControlExchange(Class cls, SEL a, SEL b) {
    Method first=class_getInstanceMethod(cls,a), second=class_getInstanceMethod(cls,b);
    if (!first || !second) return;
    if (class_addMethod(cls,a,method_getImplementation(second),method_getTypeEncoding(second))) {
        class_replaceMethod(cls,b,method_getImplementation(first),method_getTypeEncoding(first));
    } else method_exchangeImplementations(first,second);
}
static UIImage *TGControlTint(UIImage *source, UIColor *color) {
    if (!source) return nil;
    UIGraphicsBeginImageContextWithOptions(source.size,NO,source.scale);
    CGRect rect=(CGRect){CGPointZero,source.size}; [source drawInRect:rect];
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(),kCGBlendModeSourceIn); [color setFill]; CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image;
}
static NSDictionary *TGControlText(UIColor *color, CGFloat size) {
    return @{UITextAttributeTextColor:color,UITextAttributeFont:[UIFont systemFontOfSize:size],UITextAttributeTextShadowColor:[UIColor clearColor],UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetZero]};
}
static UIImage *TGControlTrack(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(3,2),NO,0); [color setFill]; UIRectFill(CGRectMake(0,0,3,2));
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image;
}
static void TGStyleBarItem(UIBarButtonItem *item) {
    UIImage *clear=TGFlatImage([UIColor clearColor]);
    for (NSNumber *state in @[@(UIControlStateNormal),@(UIControlStateHighlighted),@(UIControlStateDisabled)]) {
        UIColor *ink=state.unsignedIntegerValue==UIControlStateDisabled ? TGModernSecondaryText() : TGModernBlue();
        [item setBackgroundImage:clear forState:state.unsignedIntegerValue barMetrics:UIBarMetricsDefault];
        [item setBackgroundImage:clear forState:state.unsignedIntegerValue barMetrics:UIBarMetricsLandscapePhone];
        [item setTitleTextAttributes:TGControlText(ink,17) forState:state.unsignedIntegerValue];
        UIImage *back=TGControlTint([UIImage imageNamed:@"UI7NavigationBarBackButton"],ink);
        [item setBackButtonBackgroundImage:back forState:state.unsignedIntegerValue barMetrics:UIBarMetricsDefault];
        [item setBackButtonBackgroundImage:back forState:state.unsignedIntegerValue barMetrics:UIBarMetricsLandscapePhone];
    }
    item.tintColor=TGModernBlue();
}
@implementation UISwitch (TGPublicFlatControls)
- (instancetype)tg_publicSwitchFrame:(CGRect)frame __attribute__((objc_method_family(init))) {
    if (TGFlatControls() && [self class]==[UISwitch class]) {
        FUISwitch *toggle=[[FUISwitch alloc] initWithFrame:CGRectMake(frame.origin.x,frame.origin.y,51,31)];
        toggle.offBackgroundColor=[UIColor colorWithWhite:.9 alpha:1]; toggle.onBackgroundColor=[UIColor colorWithRed:.3 green:.85 blue:.39 alpha:1];
        toggle.onColor=toggle.offColor=[UIColor whiteColor]; toggle.highlightedColor=[UIColor whiteColor];
        toggle.switchCornerRadius=15.5; toggle.onLabel.text=toggle.offLabel.text=@""; [toggle setOn:NO];
        self=(UISwitch *)toggle;
        return self;
    }
    return [self tg_publicSwitchFrame:frame];
}
@end
@implementation UIButton (TGPublicFlatControls)
+ (instancetype)tg_publicButtonType:(UIButtonType)type {
    BOOL flat=TGFlatControls() && self==[UIButton class] && (type==UIButtonTypeRoundedRect || type==UIButtonTypeCustom);
    UIButton *button=flat ? [[RT27ModernButton alloc] initWithFrame:CGRectZero] : [self tg_publicButtonType:type];
    if (flat) {
        [button setTitleColor:TGModernBlue() forState:UIControlStateNormal];
        [button setTitleColor:[TGModernBlue() colorWithAlphaComponent:.45] forState:UIControlStateHighlighted];
        [button setTitleColor:TGModernSecondaryText() forState:UIControlStateDisabled];
        button.titleLabel.font=[UIFont fontWithName:@"HelveticaNeue" size:17];
    }
    return button;
}
@end
@implementation UISlider (TGPublicFlatControls)
- (instancetype)tg_publicSliderFrame:(CGRect)frame __attribute__((objc_method_family(init))) {
    self=[self tg_publicSliderFrame:frame];
    if (self && TGFlatControls()) {
        UIImage *thumb=[UIImage imageNamed:@"UI7SliderThumb"];
        for (NSNumber *state in @[@(UIControlStateNormal),@(UIControlStateHighlighted),@(UIControlStateDisabled)]) {
            [self setThumbImage:thumb forState:state.unsignedIntegerValue];
            [self setMinimumTrackImage:TGControlTrack(TGModernBlue()) forState:state.unsignedIntegerValue];
            [self setMaximumTrackImage:TGControlTrack(TGModernSeparator()) forState:state.unsignedIntegerValue];
        }
    } return self;
}
@end
@implementation UISegmentedControl (TGPublicFlatControls)
- (instancetype)tg_publicSegments:(NSArray *)items __attribute__((objc_method_family(init))) {
    if (TGFlatControls() && [self class]==[UISegmentedControl class]) {
        FUISegmentedControl *segments=[[FUISegmentedControl alloc] initWithItems:items];
        segments.selectedColor=TGModernBlue(); segments.deselectedColor=[UIColor whiteColor]; segments.highlightedColor=[TGModernBlue() colorWithAlphaComponent:.15];
        segments.selectedFontColor=[UIColor whiteColor]; segments.deselectedFontColor=TGModernBlue(); segments.highlightedFontColor=TGModernBlue();
        segments.selectedFont=segments.deselectedFont=[UIFont fontWithName:@"HelveticaNeue" size:13];
        segments.borderColor=TGModernBlue(); segments.borderWidth=1; segments.cornerRadius=4;
        self=(UISegmentedControl *)segments; return self;
    }
    self=[self tg_publicSegments:items];
    if (self && TGFlatControls()) {
        self.tintColor=TGModernBlue(); self.layer.cornerRadius=4; self.layer.borderWidth=1; self.layer.borderColor=TGModernBlue().CGColor; self.clipsToBounds=YES;
        [self setBackgroundImage:TGFlatImage([UIColor whiteColor]) forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:TGFlatImage(TGModernBlue()) forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:TGFlatImage([TGModernBlue() colorWithAlphaComponent:.18]) forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [self setTitleTextAttributes:TGControlText(TGModernBlue(),13) forState:UIControlStateNormal];
        [self setTitleTextAttributes:TGControlText([UIColor whiteColor],13) forState:UIControlStateSelected];
        [self setDividerImage:TGFlatImage(TGModernBlue()) forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    } return self;
}
@end
@implementation UITextField (TGPublicFlatControls)
- (void)tg_publicBorder:(UITextBorderStyle)style {
    if (TGFlatControls() && style==UITextBorderStyleRoundedRect) {
        [self tg_publicBorder:UITextBorderStyleNone];
        self.backgroundColor=[UIColor whiteColor]; self.layer.cornerRadius=5; self.layer.borderWidth=.5; self.layer.borderColor=TGModernSeparator().CGColor;
    } else [self tg_publicBorder:style];
}
@end
@implementation UITableViewController (TGPublicFlatControls)
- (void)tg_publicTableLoadView {
    [self tg_publicTableLoadView];
    if (!TGFlatControls() || self.tableView.style!=UITableViewStyleGrouped) return;
    UITableView *old=self.tableView;
    UITableView *table=[[UITableView alloc] initWithFrame:old.frame style:UITableViewStylePlain];
    extern void TGUI7RecordGroupedTable(id,BOOL); TGUI7RecordGroupedTable(table,YES);
    table.autoresizingMask=old.autoresizingMask; table.rowHeight=old.rowHeight;
    table.dataSource=old.dataSource; table.delegate=old.delegate;
    table.backgroundColor=TGModernCanvas(); table.separatorColor=TGModernSeparator();
    self.tableView=table;
}
@end
@implementation UITableView (TGPublicFlatControls)
- (instancetype)tg_publicTableFrame:(CGRect)frame style:(UITableViewStyle)style __attribute__((objc_method_family(init))) {
    BOOL flat=TGFlatControls(); self=[self tg_publicTableFrame:frame style:flat ? UITableViewStylePlain : style];
    if (self && flat) {
        extern void TGUI7RecordGroupedTable(id,BOOL); TGUI7RecordGroupedTable(self,style==UITableViewStyleGrouped);
        self.backgroundColor=style==UITableViewStyleGrouped ? TGModernCanvas() : [UIColor whiteColor];
        self.separatorColor=TGModernSeparator();
    } return self;
}
@end
@implementation UITableViewCell (TGPublicFlatControls)
- (instancetype)tg_publicCellStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier __attribute__((objc_method_family(init))) {
    self=[self tg_publicCellStyle:style reuseIdentifier:identifier];
    if (self && TGFlatControls()) {
        self.backgroundColor=[UIColor whiteColor]; self.textLabel.font=[UIFont systemFontOfSize:17];
        self.textLabel.backgroundColor=self.detailTextLabel.backgroundColor=[UIColor clearColor];
        self.textLabel.highlightedTextColor=[UIColor blackColor]; self.detailTextLabel.highlightedTextColor=TGModernSecondaryText();
        UIView *selected=[[UIView alloc] init]; selected.backgroundColor=[UIColor colorWithWhite:.9 alpha:1]; self.selectedBackgroundView=selected;
    } return self;
}
- (void)tg_publicCellLayout {
    [self tg_publicCellLayout];
    RT27LayoutTableRow(self);
}
- (void)tg_publicAccessory:(UITableViewCellAccessoryType)type {
    [self tg_publicAccessory:type];
    if (!TGFlatControls()) return;
    if (type==UITableViewCellAccessoryDisclosureIndicator || type==UITableViewCellAccessoryCheckmark) {
        UIImage *source=[UIImage imageNamed:type==UITableViewCellAccessoryCheckmark ? @"UIAccessoryButtonCheckmark" : @"Telegram27/ModernListsDisclosureIndicator.png"];
        UIImageView *view=[[UIImageView alloc] initWithImage:type==UITableViewCellAccessoryCheckmark ? TGControlTint(source,TGModernBlue()) : source];
        view.tag=712018; self.accessoryView=view;
    } else if (type==UITableViewCellAccessoryNone && self.accessoryView.tag==712018) self.accessoryView=nil;
}
@end
@implementation UIBarButtonItem (TGPublicFlatControls)
- (instancetype)tg_publicBarTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action __attribute__((objc_method_family(init))) {
    self=[self tg_publicBarTitle:title style:style target:target action:action]; if (self && TGFlatControls()) TGStyleBarItem(self); return self;
}
- (instancetype)tg_publicBarImage:(UIImage *)image style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action __attribute__((objc_method_family(init))) {
    self=[self tg_publicBarImage:TGFlatControls() ? TGControlTint(image,TGModernBlue()) : image style:style target:target action:action]; if (self && TGFlatControls()) TGStyleBarItem(self); return self;
}
- (instancetype)tg_publicSystemItem:(UIBarButtonSystemItem)item target:(id)target action:(SEL)action __attribute__((objc_method_family(init))) {
    self=[self tg_publicSystemItem:item target:target action:action];
    if (self && TGFlatControls()) {
        TGStyleBarItem(self);
        NSDictionary *titles=@{@(UIBarButtonSystemItemDone):@"Готово",@(UIBarButtonSystemItemCancel):@"Отмена",@(UIBarButtonSystemItemEdit):@"Изм.",@(UIBarButtonSystemItemSave):@"Сохранить"};
        if (titles[@(item)]) self.title=titles[@(item)];
        NSDictionary *icons=@{@(UIBarButtonSystemItemCompose):@"Compose",@(UIBarButtonSystemItemAdd):@"Add",@(UIBarButtonSystemItemRefresh):@"Refresh",@(UIBarButtonSystemItemTrash):@"Trash",@(UIBarButtonSystemItemSearch):@"Search",@(UIBarButtonSystemItemPlay):@"Play",@(UIBarButtonSystemItemPause):@"Pause",@(UIBarButtonSystemItemAction):@"Action",@(UIBarButtonSystemItemRewind):@"Rewind",@(UIBarButtonSystemItemFastForward):@"FastForward"};
        NSString *name=icons[@(item)]; UIImage *glyph=name ? [UIImage imageNamed:[@"UIButtonBar" stringByAppendingString:name]] : nil;
        if (item==UIBarButtonSystemItemAdd) glyph=[UIImage imageNamed:@"Telegram27/ModernNavigationAddButtonIcon.png"];
        if (item==UIBarButtonSystemItemCompose) glyph=[UIImage imageNamed:@"Telegram27/ModernNavigationComposeButtonIcon.png"];
        if (glyph) self.image=TGControlTint(glyph,TGModernBlue());
    } return self;
}
@end
@implementation UISearchBar (TGPublicFlatControls)
- (instancetype)tg_publicSearchFrame:(CGRect)frame __attribute__((objc_method_family(init))) {
    self=[self tg_publicSearchFrame:frame];
    if (self && TGFlatControls()) {
        self.backgroundImage=TGFlatImage([UIColor whiteColor]);
        [self setSearchFieldBackgroundImage:TGModernSearchImage() forState:UIControlStateNormal];
        self.tintColor=TGModernBlue();
    } return self;
}
@end
@implementation UIProgressView (TGPublicFlatControls)
- (instancetype)tg_publicProgressStyle:(UIProgressViewStyle)style __attribute__((objc_method_family(init))) {
    self=[self tg_publicProgressStyle:style];
    if (self && TGFlatControls()) { self.progressImage=TGControlTrack(TGModernBlue()); self.trackImage=TGControlTrack(TGModernSeparator()); }
    return self;
}
@end
// UIAlertController is resolved at runtime: this binary must still load on iOS 6.
static char TGPresentedDialogKey;
void TGAssociateFlatDialog(id owner,id dialog) { objc_setAssociatedObject(owner,&TGPresentedDialogKey,dialog,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static BOOL TGPresentFlatDialog(id owner, BOOL sheet) {
    Class controllerClass=NSClassFromString(@"UIAlertController"), actionClass=NSClassFromString(@"UIAlertAction");
    if (!TGFlatControls()) return NO;
    if (!controllerClass || !actionClass) return TGPresentLegacyFlatDialog(owner,sheet);
    if (objc_getAssociatedObject(owner,&TGPresentedDialogKey)) return YES;
    UIViewController *presenter=[UIApplication sharedApplication].keyWindow.rootViewController;
    while (presenter.presentedViewController) presenter=presenter.presentedViewController;
    if (!presenter || !presenter.view.window) return NO;
    NSString *message=sheet ? nil : [(UIAlertView *)owner message];
    id controller=((id(*)(id,SEL,id,id,NSInteger))objc_msgSend)(controllerClass,NSSelectorFromString(@"alertControllerWithTitle:message:preferredStyle:"),[owner title],message,sheet ? 0 : 1);
    objc_setAssociatedObject(owner,&TGPresentedDialogKey,controller,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!sheet && [(UIAlertView *)owner alertViewStyle]!=UIAlertViewStyleDefault) {
        NSInteger count=[(UIAlertView *)owner alertViewStyle]==UIAlertViewStyleLoginAndPasswordInput ? 2 : 1;
        for (NSInteger i=0;i<count;i++) {
            UITextField *original=[(UIAlertView *)owner textFieldAtIndex:i];
            ((void(*)(id,SEL,id))objc_msgSend)(controller,NSSelectorFromString(@"addTextFieldWithConfigurationHandler:"),^(UITextField *field) {
                field.text=original.text; field.placeholder=original.placeholder; field.secureTextEntry=original.secureTextEntry; field.keyboardType=original.keyboardType; field.autocapitalizationType=original.autocapitalizationType;
            });
        }
    }
    __weak id weakController=controller;
    NSInteger count=[owner numberOfButtons], cancel=[owner cancelButtonIndex];
    for (NSInteger i=0;i<count;i++) {
        NSInteger style=i==cancel ? 1 : (sheet && i==[(UIActionSheet *)owner destructiveButtonIndex] ? 2 : 0);
        id action=((id(*)(id,SEL,id,NSInteger,id))objc_msgSend)(actionClass,NSSelectorFromString(@"actionWithTitle:style:handler:"),[owner buttonTitleAtIndex:i],style,^(id ignored) {
            if (!sheet && [(UIAlertView *)owner alertViewStyle]!=UIAlertViewStyleDefault) {
                NSArray *fields=[weakController valueForKey:@"textFields"];
                for (NSUInteger j=0;j<fields.count;j++) [(UIAlertView *)owner textFieldAtIndex:j].text=[fields[j] text];
            }
            id delegate=[owner delegate];
            SEL clicked=sheet ? @selector(actionSheet:clickedButtonAtIndex:) : @selector(alertView:clickedButtonAtIndex:);
            SEL will=sheet ? @selector(actionSheet:willDismissWithButtonIndex:) : @selector(alertView:willDismissWithButtonIndex:);
            SEL did=sheet ? @selector(actionSheet:didDismissWithButtonIndex:) : @selector(alertView:didDismissWithButtonIndex:);
            objc_setAssociatedObject(owner,&TGPresentedDialogKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if ([delegate respondsToSelector:clicked]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,clicked,owner,i);
            if ([delegate respondsToSelector:will]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,will,owner,i);
            if ([delegate respondsToSelector:did]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,did,owner,i);
        });
        ((void(*)(id,SEL,id))objc_msgSend)(controller,NSSelectorFromString(@"addAction:"),action);
    }
    SEL willPresent=sheet ? @selector(willPresentActionSheet:) : @selector(willPresentAlertView:);
    id delegate=[owner delegate];
    if ([delegate respondsToSelector:willPresent]) ((void(*)(id,SEL,id))objc_msgSend)(delegate,willPresent,owner);
    [presenter presentViewController:controller animated:YES completion:^{
        SEL didPresent=sheet ? @selector(didPresentActionSheet:) : @selector(didPresentAlertView:);
        if ([delegate respondsToSelector:didPresent]) ((void(*)(id,SEL,id))objc_msgSend)(delegate,didPresent,owner);
    }];
    return YES;
}
static BOOL TGDismissFlatDialog(id owner, NSInteger index, BOOL animated, BOOL sheet) {
    UIViewController *controller=objc_getAssociatedObject(owner,&TGPresentedDialogKey);
    if (!controller) return NO;
    if (TGDismissLegacyFlatDialog(controller,index,animated)) return YES;
    id delegate=[owner delegate];
    SEL will=sheet ? @selector(actionSheet:willDismissWithButtonIndex:) : @selector(alertView:willDismissWithButtonIndex:);
    if ([delegate respondsToSelector:will]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,will,owner,index);
    [controller dismissViewControllerAnimated:animated completion:^{
        objc_setAssociatedObject(owner,&TGPresentedDialogKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SEL did=sheet ? @selector(actionSheet:didDismissWithButtonIndex:) : @selector(alertView:didDismissWithButtonIndex:);
        if ([delegate respondsToSelector:did]) ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(delegate,did,owner,index);
    }]; return YES;
}
@implementation UIAlertView (TGPublicFlatControls)
- (void)tg_publicAlertShow { if (!TGPresentFlatDialog(self,NO)) [self tg_publicAlertShow]; }
- (void)tg_publicAlertDismiss:(NSInteger)index animated:(BOOL)animated { if (!TGDismissFlatDialog(self,index,animated,NO)) [self tg_publicAlertDismiss:index animated:animated]; }
- (BOOL)tg_publicAlertVisible { return objc_getAssociatedObject(self,&TGPresentedDialogKey)!=nil || [self tg_publicAlertVisible]; }
@end
@implementation UIActionSheet (TGPublicFlatControls)
- (void)tg_publicSheetShow:(UIView *)view { if (!TGPresentFlatDialog(self,YES)) [self tg_publicSheetShow:view]; }
- (void)tg_publicSheetDismiss:(NSInteger)index animated:(BOOL)animated { if (!TGDismissFlatDialog(self,index,animated,YES)) [self tg_publicSheetDismiss:index animated:animated]; }
- (BOOL)tg_publicSheetVisible { return objc_getAssociatedObject(self,&TGPresentedDialogKey)!=nil || [self tg_publicSheetVisible]; }
@end
void TGUI7InstallPublicControlAdapters(void) {
    static dispatch_once_t once; dispatch_once(&once, ^{
        TGControlExchange([UITableViewController class],@selector(loadView),@selector(tg_publicTableLoadView));
        TGControlExchange([UIProgressView class],@selector(initWithProgressViewStyle:),@selector(tg_publicProgressStyle:));
        TGControlExchange([UIAlertView class],@selector(show),@selector(tg_publicAlertShow));
        TGControlExchange([UIAlertView class],@selector(dismissWithClickedButtonIndex:animated:),@selector(tg_publicAlertDismiss:animated:));
        TGControlExchange([UIAlertView class],@selector(isVisible),@selector(tg_publicAlertVisible));
        TGControlExchange([UIActionSheet class],@selector(showInView:),@selector(tg_publicSheetShow:));
        TGControlExchange([UIActionSheet class],@selector(dismissWithClickedButtonIndex:animated:),@selector(tg_publicSheetDismiss:animated:));
        TGControlExchange([UIActionSheet class],@selector(isVisible),@selector(tg_publicSheetVisible));
        TGControlExchange([UISwitch class],@selector(initWithFrame:),@selector(tg_publicSwitchFrame:));
        TGControlExchange(object_getClass([UIButton class]),@selector(buttonWithType:),@selector(tg_publicButtonType:));
        TGControlExchange([UISlider class],@selector(initWithFrame:),@selector(tg_publicSliderFrame:));
        TGControlExchange([UISegmentedControl class],@selector(initWithItems:),@selector(tg_publicSegments:));
        TGControlExchange([UITextField class],@selector(setBorderStyle:),@selector(tg_publicBorder:));
        TGControlExchange([UITableView class],@selector(initWithFrame:style:),@selector(tg_publicTableFrame:style:));
        TGControlExchange([UITableViewCell class],@selector(initWithStyle:reuseIdentifier:),@selector(tg_publicCellStyle:reuseIdentifier:));
        TGControlExchange([UITableViewCell class],@selector(layoutSubviews),@selector(tg_publicCellLayout));
        TGControlExchange([UITableViewCell class],@selector(setAccessoryType:),@selector(tg_publicAccessory:));
        TGControlExchange([UIBarButtonItem class],@selector(initWithTitle:style:target:action:),@selector(tg_publicBarTitle:style:target:action:));
        TGControlExchange([UIBarButtonItem class],@selector(initWithImage:style:target:action:),@selector(tg_publicBarImage:style:target:action:));
        TGControlExchange([UIBarButtonItem class],@selector(initWithBarButtonSystemItem:target:action:),@selector(tg_publicSystemItem:target:action:));
        TGControlExchange([UISearchBar class],@selector(initWithFrame:),@selector(tg_publicSearchFrame:));
    });
}
