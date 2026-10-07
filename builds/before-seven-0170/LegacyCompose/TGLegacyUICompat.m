#import "TGLegacyUICompat.h"
#import "TGUser.h"
#import "TGRemoteImageView.h"
#import "TGToolbarButton.h"
#import "../TGClient.h"
NSString *TGLegacyLocalized(NSString *key) {
    static NSDictionary *strings;
    if (!strings) strings = @{ @"Compose.NewGroup": @"Новая группа", @"Compose.NewMessage": @"Новое сообщение",
        @"Compose.TokenListPlaceholder": @"Кому:", @"Common.Next": @"Далее", @"Compose.Create": @"Создать",
        @"Common.Cancel": @"Отмена", @"Common.Done": @"Готово", @"Common.ListDelete": @"Удалить", @"Common.OK": @"ОК",
        @"DialogList.SearchLabel": @"Поиск", @"ConversationProfile.GroupName": @"Название группы",
        @"Presence.online": @"в сети", @"Presence.offline": @"не в сети", @"Presence.invisible": @"был(а) недавно",
        @"Presence.lastSeen": @"был(а)", @"Contacts.Title": @"Контакты" };
    return strings[key] ?: key;
}
NSString *TGEncodeText(NSString *text, int shift) {
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i=0; i<text.length; i++) [result appendFormat:@"%C", (unichar)([text characterAtIndex:i]+shift)];
    return result;
}
@implementation ASHandle
- (instancetype)initWithDelegate:(id)delegate releaseOnMainThread:(BOOL)mainThread { if ((self=[super init])) _delegate=delegate; return self; }
- (void)requestAction:(NSString *)action options:(NSDictionary *)options {
    if ([self.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
        [self.delegate performSelector:@selector(actionStageActionRequested:options:) withObject:action withObject:options];
}
- (void)reset { self.delegate=nil; }
@end
@implementation TGUser
- (NSString *)displayName {
    NSString *firstName=self.firstName, *lastName=self.lastName;
    if (firstName.length && lastName.length) return [[NSString alloc] initWithFormat:@"%@ %@",firstName,lastName];
    else if (firstName.length) return firstName;
    else if (lastName.length) return lastName;
    return @"";
}
- (NSString *)displayFirstName { return self.firstName.length ? self.firstName : self.lastName; }
@end
@interface TGViewController ()
@property (nonatomic) CGFloat legacyKeyboardHeight;
@end
@interface TGViewController (TGLegacyContactLayout)
- (void)updateTableFrame:(bool)animated collapseSearch:(bool)collapseSearch;
@end
@implementation TGViewController
- (void)loadView {
    self.view=[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    if ([self respondsToSelector:NSSelectorFromString(@"setEdgesForExtendedLayout:")])
        [(id)self setEdgesForExtendedLayout:0];
    if ([self respondsToSelector:NSSelectorFromString(@"setAutomaticallyAdjustsScrollViewInsets:")])
        [(id)self setAutomaticallyAdjustsScrollViewInsets:NO];
}
- (NSString *)titleText { return self.title; }
- (void)setTitleText:(NSString *)titleText { self.title=titleText; }
- (void)setBackAction:(SEL)action { [self setBackAction:action animated:NO]; }
- (void)setBackAction:(SEL)action animated:(BOOL)animated {
    _backAction=action;
    TGToolbarButton *back=[[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeBack];
    back.text=@"Назад"; [back sizeToFit]; [back addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithCustomView:back] animated:animated];
}
- (UIEdgeInsets)controllerCleanInset { return UIEdgeInsetsZero; }
- (UIEdgeInsets)controllerInset { return UIEdgeInsetsMake(0,0,self.legacyKeyboardHeight,0); }
- (BOOL)navigationBarShouldBeHidden { return self.navigationController.navigationBarHidden; }
- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated { [self.navigationController setNavigationBarHidden:hidden animated:animated]; }
- (void)setExplicitTableInset:(UIEdgeInsets)inset scrollIndicatorInset:(UIEdgeInsets)indicator {
    UITableView *table=[self valueForKey:@"tableView"];
    inset.bottom+=self.legacyKeyboardHeight; indicator.bottom+=self.legacyKeyboardHeight;
    table.contentInset=inset; table.scrollIndicatorInsets=indicator;
}
- (BOOL)_updateControllerInset:(BOOL)animated { return NO; }
- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset {
    for (UIScrollView *scrollView in self.scrollViewsForAutomaticInsetsAdjustment) {
        UIEdgeInsets inset=scrollView.contentInset;
        inset.bottom=self.legacyKeyboardHeight;
        scrollView.contentInset=inset;
        scrollView.scrollIndicatorInsets=inset;
    }
}
+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation {
    CGSize size=[UIScreen mainScreen].bounds.size;
    if (UIInterfaceOrientationIsLandscape(orientation)) size=CGSizeMake(MAX(size.width,size.height),MIN(size.width,size.height));
    return size;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(legacyKeyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)legacyKeyboardChanged:(NSNotification *)notification {
    CGRect frame=[self.view convertRect:[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGRect overlap=CGRectIntersection(self.view.bounds,frame);
    self.legacyKeyboardHeight=CGRectIsNull(overlap) || CGRectIsEmpty(overlap) ? 0 : overlap.size.height;
    [self controllerInsetUpdated:UIEdgeInsetsZero];
    if ([self respondsToSelector:@selector(updateTableFrame:collapseSearch:)]) [(id)self updateTableFrame:YES collapseSearch:NO];
}
@end
@implementation TGDateUtils
+ (NSString *)stringForRelativeLastSeen:(int)timestamp {
    NSDateFormatter *formatter=[[NSDateFormatter alloc] init]; formatter.dateFormat=@"dd.MM в HH:mm";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}
@end
@implementation TGHacks
+ (void)setTextFieldClearOffset:(UITextField *)field offset:(CGFloat)offset {}
+ (void)setTextFieldPlaceholderColor:(UITextField *)field color:(UIColor *)color {
    if ([field respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        field.attributedPlaceholder=[[NSAttributedString alloc] initWithString:field.placeholder ?: @"" attributes:@{NSForegroundColorAttributeName:color}];
    }
}
@end
@implementation TGInterfaceAssets
+ (instancetype)instance { static TGInterfaceAssets *assets; if (!assets) assets=[[self alloc] init]; return assets; }
- (UIColor *)linesBackground { return [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/SettingsBackground.png"]]; }
- (UIImage *)dialogListSearchIcon { return [UIImage imageNamed:@"OriginalTelegram/SearchBarIcon.png"]; }
- (UIImage *)smallAvatarPlaceholderGeneric { return [UIImage imageNamed:@"OriginalTelegram/DialogListAvatarPlaceholderSmall.png"]; }
- (UIImage *)avatarPlaceholderGeneric { return [UIImage imageNamed:@"OriginalTelegram/DialogListAvatarPlaceholder.png"]; }
- (UIImage *)smallAvatarPlaceholder:(int64_t)uid { return [self smallAvatarPlaceholderGeneric]; }
+ (UIImage *)groupedImage:(NSString *)name {
    UIImage *raw=[UIImage imageNamed:[@"OriginalTelegram/" stringByAppendingString:name]];
    return [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width/2) topCapHeight:(int)(raw.size.height/2)];
}
+ (UIImage *)groupedCellSingle { return [self groupedImage:@"GroupedCellSingle.png"]; }
+ (UIImage *)groupedCellSingleHighlighted { return [self groupedImage:@"GroupedCellSingle_Selected.png"]; }
+ (UIImage *)groupedCellTop { return [self groupedImage:@"GroupedCellTop.png"]; }
+ (UIImage *)groupedCellTopHighlighted { return [self groupedImage:@"GroupedCellTop_Selected.png"]; }
+ (UIImage *)groupedCellMiddle { return [self groupedImage:@"GroupedCellMiddle.png"]; }
+ (UIImage *)groupedCellMiddleHighlighted { return [self groupedImage:@"GroupedCellMiddle_Selected.png"]; }
+ (UIImage *)groupedCellBottom { return [self groupedImage:@"GroupedCellBottom.png"]; }
+ (UIImage *)groupedCellBottomHighlighted { return [self groupedImage:@"GroupedCellBottom_Selected.png"]; }
@end
@interface TGLegacyContactStore ()
@property (nonatomic, strong) NSCache *images;
@end
@implementation TGLegacyContactStore
+ (instancetype)shared { static TGLegacyContactStore *store; if (!store) { store=[[self alloc] init]; store.images=[[NSCache alloc] init]; store.images.countLimit=100; } return store; }
- (TGUser *)userForId:(int64_t)uid { for (TGUser *user in self.users) if (user.uid==uid) return user; return nil; }
- (void)loadContacts:(void (^)(NSArray *,NSString *))completion {
    void (^apply)(NSDictionary *)=^(NSDictionary *result) {
        if (![result[@"users"] isKindOfClass:[NSArray class]]) return;
        NSMutableDictionary *byId=[NSMutableDictionary dictionary];
        for (NSDictionary *raw in result[@"users"]) if (raw[@"id"]) byId[raw[@"id"]]=raw;
        NSMutableArray *users=[NSMutableArray array];
        for (NSDictionary *contact in result[@"contacts"]) {
            NSDictionary *raw=byId[contact[@"user_id"]];
            if (!raw[@"id"] || !raw[@"access_hash"] || [raw[@"self"] boolValue]) continue;
            TGUser *user=[[TGUser alloc] init]; user.uid=[raw[@"id"] longLongValue]; user.rawUser=raw;
            user.firstName=raw[@"first_name"] ?: @""; user.lastName=raw[@"last_name"] ?: @"";
            if (raw[@"photo"][@"photo_id"]) user.photoUrlSmall=[NSString stringWithFormat:@"tglegacy-avatar://%lld",user.uid];
            NSDictionary *status=raw[@"status"];
            TGUserPresence presence={NO,0};
            presence.online=[status[@"_"] isEqual:@"userStatusOnline"];
            presence.lastSeen=[status[@"was_online"] intValue];
            if (!presence.online && !presence.lastSeen && ![status[@"_"] isEqual:@"userStatusEmpty"]) presence.lastSeen=-1;
            user.presence=presence; [users addObject:user];
        }
        self.users=users; completion(users,nil);
    };
    NSDictionary *cached=[self.client cachedContacts]; if (cached) apply(cached);
    [self.client getContacts:^(NSDictionary *result,NSString *error) { if (error) { if (!cached) completion(nil,error); } else apply(result); }];
}
- (void)avatarForURL:(NSString *)url completion:(void (^)(UIImage *))completion {
    UIImage *cached=[self.images objectForKey:url]; if (cached) { completion(cached); return; }
    TGUser *user=[self userForId:[[[NSURL URLWithString:url] host] longLongValue]];
    if (!user) { completion(nil); return; }
    NSDictionary *peer=@{ @"_":@"inputPeerUser", @"user_id":user.rawUser[@"id"], @"access_hash":user.rawUser[@"access_hash"] };
    [self.client getAvatarForPeer:peer photo:user.rawUser[@"photo"] completion:^(NSData *data,NSString *error) {
        UIImage *image=data.length ? [UIImage imageWithData:data] : nil;
        if (image) [self.images setObject:image forKey:url]; completion(image);
    }];
}
@end
@implementation TGRemoteImageView
- (UIImage *)currentImage { return self.image; }
- (void)loadImage:(id)image { self.currentUrl=nil; self.image=[image isKindOfClass:[UIImage class]] ? image : nil; }
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder { [self loadImage:url filter:filter placeholder:placeholder forceFade:NO]; }
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(BOOL)fade {
    self.currentUrl=url; self.image=placeholder; self.contentMode=UIViewContentModeScaleAspectFill;
    self.clipsToBounds=YES; self.layer.cornerRadius=4;
    __weak TGRemoteImageView *weakSelf=self;
    [[TGLegacyContactStore shared] avatarForURL:url completion:^(UIImage *image) {
        TGRemoteImageView *view=weakSelf;
        if (image && [view.currentUrl isEqual:url]) {
            if (fade && view.fadeTransition) [UIView transitionWithView:view duration:view.fadeTransitionDuration ?: 0.14 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{view.image=image;} completion:nil];
            else view.image=image;
        }
    }];
}
@end
