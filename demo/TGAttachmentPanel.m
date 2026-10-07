#import "TGFlatKit.h"
#import "TGTheme.h"
#import "Seven/RT7UIKit.h"
#import "TGAttachmentPanel.h"
#import "TGClassicMediaPicker.h"
#import "Telegram27/RT27SheetController.h"

@interface TGAttachmentPanel ()
@property (nonatomic, strong) TGClassicMediaPicker *picker;
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) UIView *sheet;
@property (nonatomic, strong) UIButton *shade;
@property (nonatomic, strong) UIScrollView *categories;
@property (nonatomic, copy) void (^action)(NSInteger);
@property (nonatomic) BOOL closing;
@end
@implementation TGAttachmentPanel
- (instancetype)initWithPicker:(TGClassicMediaPicker *)picker action:(void (^)(NSInteger))action {
    if ((self=[super init])) { _picker=picker; _action=[action copy]; }
    return self;
}
- (void)loadView {
    self.view=[[UIView alloc] initWithFrame:CGRectZero]; self.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.shade=[RT7Button buttonWithType:UIButtonTypeCustom]; self.shade.backgroundColor=[UIColor colorWithWhite:0 alpha:TGModernThemeEnabled() ? .28 : .42]; [self.shade addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.shade];
    self.sheet=[[UIView alloc] initWithFrame:CGRectZero]; self.sheet.backgroundColor=RT7Canvas();
    if (TGModernThemeEnabled()) { self.sheet.layer.cornerRadius=0; self.sheet.clipsToBounds=YES; }
    [self.view addSubview:self.sheet];
    self.picker.opensRecentPhotos=YES;
    __weak TGAttachmentPanel *weakSelf=self; self.picker.cancelAction=^{ [weakSelf cancel]; };
    self.navigation=[[TGThemedNavigationController alloc] initWithRootViewController:self.picker];
    if ([self.navigation respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.navigation.edgesForExtendedLayout=0;
    [self addChildViewController:self.navigation]; [self.sheet addSubview:self.navigation.view]; [self.navigation didMoveToParentViewController:self];
    self.categories=[[UIScrollView alloc] initWithFrame:CGRectZero]; self.categories.showsHorizontalScrollIndicator=NO;
    UIImage *art=RT7ImageNamed(@"OriginalTelegram/ImagePickerPanel");
    UIImageView *background=[[UIImageView alloc] initWithImage:[art stretchableImageWithLeftCapWidth:1 topCapHeight:20]]; background.tag=77;
    background.hidden=TGModernThemeEnabled(); [self.sheet addSubview:background]; [self.sheet addSubview:self.categories];
    NSArray *titles=@[@"Галерея",@"Интернет",@"Файл",@"Кружок",@"GIF",@"Опрос",@"Контакт",@"Геопозиция",@"Эмодзи"];
    for (NSUInteger i=0;i<titles.count;i++) {
        UIButton *button=[RT7Button buttonWithType:UIButtonTypeCustom]; button.tag=i;
        if (TGModernThemeEnabled()) {
            CGFloat itemWidth=72;
            button.frame=CGRectMake(i*itemWidth,2,itemWidth,60);
            UIImageView *icon=[[UIImageView alloc] initWithImage:RT7Icon(@[@"gallery",@"search",@"file",@"camera",@"gallery",@"chat",@"person",@"location",@"emoji"][i],24,RT7Primary())];
            icon.frame=CGRectMake(24,5,24,24); icon.contentMode=UIViewContentModeScaleAspectFit; icon.userInteractionEnabled=NO; [button addSubview:icon];
            UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(1,33,itemWidth-2,19)];
            label.text=titles[i]; label.textAlignment=NSTextAlignmentCenter; label.font=[UIFont systemFontOfSize:10];
            label.textColor=i==0 ? TGModernBlue() : TGModernSecondaryText(); label.backgroundColor=[UIColor clearColor]; label.userInteractionEnabled=NO; [button addSubview:label];
            button.accessibilityLabel=titles[i];
        } else {
            button.frame=CGRectMake(6+i*96,8,90,44);
            UIImage *bg=RT7ImageNamed(i==0 ? @"OriginalTelegram/ImagePickerBlueButton" : @"OriginalTelegram/ImagePickerGrayButton");
            [button setBackgroundImage:[bg stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateNormal];
            [button setTitle:titles[i] forState:UIControlStateNormal]; button.titleLabel.font=[UIFont boldSystemFontOfSize:13]; button.titleLabel.shadowOffset=CGSizeMake(0,-1);
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        [button addTarget:self action:@selector(category:) forControlEvents:UIControlEventTouchUpInside]; [self.categories addSubview:button];
    }
    self.categories.backgroundColor=TGModernThemeEnabled() ? RT7SurfaceVariant() : [UIColor clearColor];
    self.categories.contentSize=CGSizeMake(titles.count*(TGModernThemeEnabled()?72:96)+12,60);
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGRect b=self.view.bounds; CGFloat h=MAX(0,MIN(b.size.height-24,MAX(220,floor(b.size.height*.76))));
    self.shade.frame=b;
    // Bounds and center remain valid while the sheet has an animation transform.
    self.sheet.bounds=CGRectMake(0,0,b.size.width,h); self.sheet.center=CGPointMake(b.size.width/2,b.size.height-h/2);
    self.navigation.view.frame=CGRectMake(0,0,b.size.width,MAX(0,h-60)); self.categories.frame=CGRectMake(0,MAX(0,h-60),b.size.width,60); [self.sheet viewWithTag:77].frame=self.categories.frame;
}
- (void)showInController:(UIViewController *)controller {
    [controller addChildViewController:self]; self.view.frame=controller.view.bounds; [controller.view addSubview:self.view]; [self didMoveToParentViewController:controller];
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    if (TGModernThemeEnabled()) RT27AnimatePanel(self.sheet,self.shade,YES,nil);
    else {
        self.sheet.transform=CGAffineTransformMakeTranslation(0,self.sheet.bounds.size.height); self.shade.alpha=0;
        [UIView animateWithDuration:.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{self.sheet.transform=CGAffineTransformIdentity;self.shade.alpha=1;} completion:nil];
    }
}
- (void)cancel { [self close:nil]; }
- (void)category:(UIButton *)button { if (!button.tag) return; NSInteger index=button.tag; [self close:^{if(self.action) self.action(index);}]; }
- (void)close:(void (^)(void))completion {
    if (self.closing) return; self.closing=YES; self.view.userInteractionEnabled=NO;
    void (^finish)(void)=^{[self willMoveToParentViewController:nil];[self.view removeFromSuperview];[self removeFromParentViewController];if(completion)completion();};
    if (TGModernThemeEnabled()) RT27AnimatePanel(self.sheet,self.shade,NO,finish);
    else [UIView animateWithDuration:.22 animations:^{self.sheet.transform=CGAffineTransformMakeTranslation(0,self.sheet.bounds.size.height);self.shade.alpha=0;} completion:^(BOOL finished){finish();}];
}
@end
