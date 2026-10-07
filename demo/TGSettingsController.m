#import "RT27UserInfoCollectionItemView.h"
#import "RT27CardCell.h"
#import "TGFlatKit.h"
#import "TGClassicTableController.h"
#import "TGSettingsController.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "Seven/RT7UIKit.h"
#import "TGProfileMusicController.h"
#import "TGMusicPlayer.h"
#import "TGDevicesController.h"
#import "TGFeatureForms.h"
#import "TGStickerCatalogController.h"
#import "TGAccountsController.h"
#import "TGLocalPasscode.h"
#import <QuartzCore/QuartzCore.h>

static UIImage *TGSettingsArt(NSString *name) {
    return RT7ImageNamed([@"OriginalTelegram/" stringByAppendingString:name]);
}
static UIImage *TGSettingsStretch(NSString *name) {
    UIImage *image = TGSettingsArt(name);
    return [image stretchableImageWithLeftCapWidth:(NSInteger)image.size.width / 2
                                 topCapHeight:(NSInteger)image.size.height / 2];
}
static void TGSettingsBackground(UITableViewCell *cell, NSInteger row, NSInteger count) {
    if (TGModernThemeEnabled()) {
        cell.backgroundView = nil; cell.backgroundColor = RT7Surface();
        UIView *selected = [[UIView alloc] init]; selected.backgroundColor = [UIColor colorWithWhite:.9 alpha:1]; cell.selectedBackgroundView = selected;
        return;
    }
    NSString *name = count == 1 ? @"GroupedCellSingle" :
        row == 0 ? @"GroupedCellTop" : row == count - 1 ? @"GroupedCellBottom" : @"GroupedCellMiddle";
    UIImageView *normal = [[UIImageView alloc] initWithImage:TGSettingsStretch(name)];
    UIImageView *selected = [[UIImageView alloc] initWithImage:
        TGSettingsStretch([name stringByAppendingString:@"_Selected"])];
    cell.backgroundView = normal;
    cell.selectedBackgroundView = selected;
    cell.backgroundColor = [UIColor clearColor];
}
static void TGSettingsTable(UITableView *table) {
    table.separatorStyle = TGModernThemeEnabled() ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    table.backgroundColor = TGModernThemeEnabled() ? TGModernCanvas() :
        [UIColor colorWithPatternImage:TGSettingsArt(@"SettingsBackground")];
    table.backgroundView = nil;
    table.sectionHeaderHeight = 0;
    table.sectionFooterHeight = 0;
}
static UITableViewCell *TGSettingsRow(UITableView *table, NSString *title, NSInteger row,
                                    NSInteger count, BOOL arrow) {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"legacy-settings-row"];
    if (!cell) cell = [[RT7ListCell alloc] initWithStyle:UITableViewCellStyleDefault
                                            reuseIdentifier:@"legacy-settings-row"];
    TGSettingsBackground(cell, row, count);
    cell.textLabel.text = title;
    cell.textLabel.font = TGModernThemeEnabled() ? RT7Font(16,NO) : RT7Font(17,YES);
    cell.textLabel.textColor = RT7Text();
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.accessoryView = arrow && !TGModernThemeEnabled() ? [[UIImageView alloc] initWithImage:TGSettingsArt(@"MenuDisclosureIndicator")] : nil;
    cell.accessoryType = arrow && TGModernThemeEnabled() ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = arrow ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
    return cell;
}
static void TGSettingsAlert(NSString *title, NSString *message) {
    [[[RT7AlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"ОК"
                      otherButtonTitles:nil] show];
}
static UIImage *TGSettingsWallpaper(NSInteger index) { return RT7Wallpaper(index); }
static NSInteger TGSettingsSelectedWallpaper(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"TGChatWallpaper"] ? [defaults integerForKey:@"TGChatWallpaper"] :
        0;
}
static void TGSettingsSetWallpaper(NSInteger index) {
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"TGChatWallpaper"];
}

@interface TGWallpaperCell : RT7ListCell
@property (nonatomic,strong) UIImageView *thumbnail;
@property (nonatomic,strong) UILabel *caption;
@end
@implementation TGWallpaperCell
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat height = self.contentView.bounds.size.height;
    self.thumbnail.frame = CGRectMake(12,8,64,MAX(0,height-16));
    self.caption.frame = CGRectMake(88,0,MAX(0,self.contentView.bounds.size.width-100),height);
}
@end
@interface TGSettingsFieldCell : RT7ListCell
@property (nonatomic,strong) UITextField *field;
@end
@implementation TGSettingsFieldCell
- (void)layoutSubviews { [super layoutSubviews]; self.field.frame = CGRectInset(self.contentView.bounds,12,6); }
@end

typedef NS_ENUM(NSInteger, TGSettingsPage) {
    TGSettingsPageNotifications, TGSettingsPageBlocked, TGSettingsPageChats, TGSettingsPageWallpapers
};

@interface TGSettingsDetailController : TGClassicTableController <UIActionSheetDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic) TGSettingsPage page;
@property (nonatomic, strong) NSDictionary *blockedResult;
@property (nonatomic, strong) NSMutableArray *blockedRows;
@property (nonatomic, strong) NSMutableDictionary *notificationStates;
- (instancetype)initWithClient:(TGClient *)client page:(TGSettingsPage)page;
@end

@implementation TGSettingsDetailController
- (instancetype)initWithClient:(TGClient *)client page:(TGSettingsPage)page {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _client = client; _page = page; _notificationStates = [NSMutableDictionary dictionary];
        self.title = page == TGSettingsPageNotifications ? @"Уведомления и звуки" :
            page == TGSettingsPageBlocked ? @"Заблокированные" :
            page == TGSettingsPageChats ? @"Настройки чатов" : @"Фон чата";
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    TGSettingsTable(self.tableView);
    if (self.page == TGSettingsPageNotifications) {
        for (NSInteger kind = 0; kind < 3; kind++) {
            __weak TGSettingsDetailController *weakSelf = self;
            [self.client getGlobalNotificationsForKind:kind completion:^(NSDictionary *result, __unused NSString *error) {
                TGSettingsDetailController *current = weakSelf;
                if (!current || !result) return;
                NSInteger mutedUntil = [result[@"mute_until"] integerValue];
                current.notificationStates[@(kind)] = @(mutedUntil <= [[NSDate date] timeIntervalSince1970]);
                [current.tableView reloadData];
            }];
        }
    } else if (self.page == TGSettingsPageBlocked) [self reloadBlocked];
}
- (void)reloadBlocked {
    __weak TGSettingsDetailController *weakSelf = self;
    [self.client getBlockedPeers:^(NSDictionary *result, NSString *error) {
        TGSettingsDetailController *current = weakSelf;
        if (!current) return;
        if (error) { TGSettingsAlert(@"Заблокированные", error); return; }
        current.blockedResult = result;
        current.blockedRows = [result[@"blocked"] mutableCopy] ?: [NSMutableArray array];
        [current.tableView reloadData];
    }];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.page == TGSettingsPageWallpapers ? 2 : self.page == TGSettingsPageChats ? 2 : 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.page == TGSettingsPageNotifications) return 3;
    if (self.page == TGSettingsPageWallpapers) return section == 0 ? 3 : section == 1 ? 7 : 0;
    if (self.page == TGSettingsPageBlocked) return self.blockedRows.count;
    return section == 0 ? 1 : 2;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return [super tableView:tableView heightForHeaderInSection:section]; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    return self.page == TGSettingsPageWallpapers ? (path.section == 0 ? 86 : 46) : 44;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.page == TGSettingsPageWallpapers) return section == 0 ? @"Фон чата" : @"Цвет исходящих сообщений";
    if (self.page == TGSettingsPageChats) return section == 0 ? @"Вид сообщений" : @"Загрузка медиа";
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (self.page == TGSettingsPageNotifications) {
        NSArray *titles = @[@"Личные чаты", @"Группы", @"Каналы"];
        UITableViewCell *cell = TGSettingsRow(tableView, titles[path.row], path.row, 3, NO);
        UISwitch *toggle = [[TGSwitchClass() alloc] init];
        toggle.tag = path.row;
        NSNumber *state = self.notificationStates[@(path.row)];
        toggle.on = state ? state.boolValue : YES;
        toggle.enabled = state != nil;
        [toggle addTarget:self action:@selector(notificationChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }
    if (self.page == TGSettingsPageBlocked) {
        NSDictionary *blocked = self.blockedRows[path.row];
        NSNumber *identifier = blocked[@"peer_id"][@"user_id"];
        NSDictionary *user = nil;
        for (NSDictionary *candidate in self.blockedResult[@"users"])
            if ([candidate[@"id"] isEqual:identifier]) { user = candidate; break; }
        NSString *name = [[@[user[@"first_name"] ?: @"", user[@"last_name"] ?: @""]
            componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        UITableViewCell *cell = TGSettingsRow(tableView, name.length ? name : @"Пользователь",
            path.row, self.blockedRows.count, NO);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    if (self.page == TGSettingsPageWallpapers) {
        if (path.section == 1) {
            NSArray *names = @[@"Классический", @"Зелёный", @"Синий", @"Розовый", @"Фиолетовый", @"Жёлтый", @"Оранжевый"];
            UITableViewCell *cell = TGSettingsRow(tableView, names[path.row], path.row, names.count, NO);
            UIImageView *sample=[[UIImageView alloc] initWithFrame:CGRectMake(0,0,52,28)];
            sample.image=RT7Shape(CGSizeMake(52,28),RT7BubbleColor(path.row),14);
            sample.contentMode = UIViewContentModeScaleToFill;
            cell.accessoryView = sample;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            if ([[NSUserDefaults standardUserDefaults] integerForKey:@"TGBubbleColor"] == path.row)
                cell.textLabel.text = [@"✓  " stringByAppendingString:names[path.row]];
            return cell;
        }
        NSArray *titles = @[@"Однотонный", @"Светлый", @"Геометрия"];
        TGWallpaperCell *cell = [[TGWallpaperCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        TGSettingsBackground(cell, path.row, 3);
        UIImageView *thumbnail = [[UIImageView alloc] initWithFrame:CGRectMake(15, 7, 68, 72)];
        thumbnail.image = TGSettingsWallpaper(path.row);
        thumbnail.contentMode = UIViewContentModeScaleAspectFill;
        thumbnail.clipsToBounds = YES;
        thumbnail.layer.cornerRadius = 5;
        thumbnail.layer.borderWidth = 0.5;
        thumbnail.layer.borderColor = [UIColor colorWithWhite:0.6 alpha:0.55].CGColor;
        cell.thumbnail = thumbnail; [cell.contentView addSubview:thumbnail];
        UILabel *wallpaperTitle = [[UILabel alloc] initWithFrame:CGRectMake(95, 0, tableView.bounds.size.width - 132, 86)];
        wallpaperTitle.backgroundColor = [UIColor clearColor];
        wallpaperTitle.font = RT7Font(17,YES);
        wallpaperTitle.text = titles[path.row];
        wallpaperTitle.numberOfLines = 2; cell.caption = wallpaperTitle; [cell.contentView addSubview:wallpaperTitle];
        cell.accessoryType = TGSettingsSelectedWallpaper() == path.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        return cell;
    }
    if (path.section == 0) {
        UITableViewCell *cell = TGSettingsRow(tableView, @"Размер текста", 0, 1, YES);
        NSInteger fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"TGChatFontSize"];
        UILabel *value = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 48, 24)];
        value.backgroundColor = [UIColor clearColor]; value.textColor = RT7SecondaryText();
        value.font = RT7Font(15,NO); value.text = [NSString stringWithFormat:@"%ld pt", (long)(fontSize ?: 16)];
        cell.accessoryView = value;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        return cell;
    }
    NSArray *titles = @[@"Фотографии", @"Стикеры"];
    NSString *key = path.row == 0 ? @"TGAutoDownloadPhotos" : @"TGAutoDownloadStickers";
    UITableViewCell *cell = TGSettingsRow(tableView, titles[path.row], path.row, 2, NO);
    UISwitch *toggle = [[TGSwitchClass() alloc] init];
    toggle.tag = path.row;
    id saved = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    toggle.on = saved ? [saved boolValue] : YES;
    [toggle addTarget:self action:@selector(downloadChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    return nil;
}
- (void)notificationChanged:(UISwitch *)sender {
    NSInteger kind = sender.tag;
    sender.enabled = NO;
    __weak TGSettingsDetailController *weakSelf = self;
    [self.client setGlobalNotificationsEnabled:sender.on forKind:kind completion:^(__unused NSDictionary *result, NSString *error) {
        TGSettingsDetailController *current = weakSelf;
        if (!current) return;
        sender.enabled = YES;
        if (error) { sender.on = !sender.on; TGSettingsAlert(@"Уведомления", error); }
        current.notificationStates[@(kind)] = @(sender.on);
    }];
}
- (void)downloadChanged:(UISwitch *)sender {
    NSString *key = sender.tag == 0 ? @"TGAutoDownloadPhotos" : @"TGAutoDownloadStickers";
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (self.page == TGSettingsPageWallpapers) {
        if (path.section == 1) {
            [[NSUserDefaults standardUserDefaults] setInteger:path.row forKey:@"TGBubbleColor"];
            [tableView reloadData];
            return;
        }
        TGSettingsSetWallpaper(path.row);
        [tableView reloadData];
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.page == TGSettingsPageChats && path.section == 0) {
        UIActionSheet *sheet = [[RT7ActionSheet alloc] initWithTitle:@"Размер текста" delegate:self
            cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil otherButtonTitles:@"14 pt", @"16 pt", @"18 pt", nil];
        sheet.tag = 44;
        [sheet showInView:self.view];
    }
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (sheet.tag != 44 || buttonIndex >= 3) return;
    [[NSUserDefaults standardUserDefaults] setInteger:14 + buttonIndex * 2 forKey:@"TGChatFontSize"];
    [self.tableView reloadData];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path {
    return self.page == TGSettingsPageBlocked;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete || path.row >= self.blockedRows.count) return;
    NSDictionary *blocked = self.blockedRows[path.row];
    NSNumber *identifier = blocked[@"peer_id"][@"user_id"];
    NSDictionary *user = nil;
    for (NSDictionary *candidate in self.blockedResult[@"users"])
        if ([candidate[@"id"] isEqual:identifier]) { user = candidate; break; }
    if (!user[@"id"] || !user[@"access_hash"]) return;
    NSDictionary *peer = @{ @"_": @"inputPeerUser", @"user_id": user[@"id"], @"access_hash": user[@"access_hash"] };
    __weak TGSettingsDetailController *weakSelf = self;
    [self.client unblockPeer:peer completion:^(__unused NSDictionary *result, NSString *error) {
        if (error) TGSettingsAlert(@"Заблокированные", error);
        else [weakSelf reloadBlocked];
    }];
}
@end

@interface TGProfileEditController : TGClassicTableController <UITextFieldDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) UITextField *firstField, *lastField;
- (instancetype)initWithClient:(TGClient *)client user:(NSDictionary *)user;
@end
@implementation TGProfileEditController
- (instancetype)initWithClient:(TGClient *)client user:(NSDictionary *)user {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _client = client; self.title = @"Имя";
        _firstField = [[TGTextFieldClass() alloc] init]; _firstField.text = user[@"first_name"];
        _lastField = [[TGTextFieldClass() alloc] init]; _lastField.text = user[@"last_name"];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; TGSettingsTable(self.tableView);
    self.navigationItem.rightBarButtonItem = [[RT7BarButtonItem alloc] initWithTitle:@"Готово"
        style:UIBarButtonItemStyleDone target:self action:@selector(save)];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 2; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    TGSettingsFieldCell *cell = [[TGSettingsFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    TGSettingsBackground(cell, path.row, 2);
    UITextField *field = path.row == 0 ? self.firstField : self.lastField;
    field.frame = CGRectMake(12, 6, tableView.bounds.size.width - 48, 32);
    field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    field.placeholder = path.row == 0 ? @"Имя" : @"Фамилия";
    field.font = RT7Font(17,NO);
    field.returnKeyType = path.row == 0 ? UIReturnKeyNext : UIReturnKeyDone;
    field.delegate = self;
    field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter; cell.field = field; [cell.contentView addSubview:field];
    return cell;
}
- (BOOL)textFieldShouldReturn:(UITextField *)field {
    if (field == self.firstField) [self.lastField becomeFirstResponder]; else [self save];
    return NO;
}
- (void)save {
    [self.view endEditing:YES];
    NSString *first = [self.firstField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *last = [self.lastField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    __weak TGProfileEditController *weakSelf = self;
    [self.client updateProfileFirstName:first lastName:last completion:^(__unused NSDictionary *result, NSString *error) {
        TGProfileEditController *current = weakSelf;
        if (!current) return;
        current.navigationItem.rightBarButtonItem.enabled = YES;
        if (error) TGSettingsAlert(@"Имя", error);
        else [current.navigationController popViewControllerAnimated:YES];
    }];
}
@end

@interface TGSettingsController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *user;
@property (nonatomic, strong) NSDictionary *fullProfile;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel, *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *photoSpinner;
@property (nonatomic, strong) UIView *profileHeader;
@property(nonatomic,strong) RT27UserInfoCollectionItemView *telegram27Profile;
@property (nonatomic, strong) UILabel *musicLabel;
@property (nonatomic, strong) NSDictionary *musicDocument;
@property (nonatomic) BOOL musicSnapshotLoaded;
@property (nonatomic, strong) UIImageView *avatarOverlay;
@property (nonatomic, strong) UIButton *avatarTap;
@property(nonatomic,strong) NSNumber *avatarPhotoId;
@property(nonatomic) NSTimeInterval lastProfileLoad;
@end

static NSArray *RT27SettingsSections(void) {
    static NSArray *sections; static dispatch_once_t once;
    dispatch_once(&once,^{ sections=@[@[@"0:0"],@[@"0:1",@"1:10"],@[@"1:0",@"1:1",@"1:2",@"1:5"],@[@"1:3",@"1:4",@"2:0"],@[@"1:7",@"1:8"],@[@"1:6",@"1:9",@"1:11"],@[@"3:0",@"3:1"],@[@"4:0"]]; }); return sections;
}
static NSIndexPath *RT27SettingsPath(NSIndexPath *path) {
    NSArray *parts=[RT27SettingsSections()[path.section][path.row] componentsSeparatedByString:@":"];
    return [NSIndexPath indexPathForRow:[parts[1] integerValue] inSection:[parts[0] integerValue]];
}
@implementation TGSettingsController
- (instancetype)initWithClient:(TGClient *)client {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) { _client = client; self.title = @"Настройки"; self.hidesBottomBarWhenPushed = NO; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyCachedMusic)
        name:TGMusicProfileChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadProfile) name:@"TGSessionReadyNotification" object:nil];
    TGSettingsTable(self.tableView);
    self.navigationItem.rightBarButtonItem = [[RT7BarButtonItem alloc] initWithTitle:@"Изм."
        style:UIBarButtonItemStyleBordered target:self action:@selector(editProfile)];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 86)];
    self.profileHeader = header;
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(9, 14, 70, 70)];
    self.avatarView.image = TGSettingsArt(@"SettingsAddPhoto");
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.layer.cornerRadius = 5;
    [header addSubview:self.avatarView];
    UIImageView *overlay = [[UIImageView alloc] initWithFrame:self.avatarView.frame];
    overlay.image = nil;
    overlay.userInteractionEnabled = NO;
    [header addSubview:overlay];
    self.avatarOverlay = overlay;
    UIButton *avatarTap = [RT7Button buttonWithType:UIButtonTypeCustom];
    avatarTap.frame = self.avatarView.frame;
    [avatarTap addTarget:self action:@selector(changePhoto) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:avatarTap];
    self.avatarTap = avatarTap;
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(94, 24, header.bounds.size.width - 103, 24)];
    self.nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.nameLabel.backgroundColor = [UIColor clearColor];
    self.nameLabel.font = RT7Font(19,YES);
    self.nameLabel.textColor = [UIColor colorWithRed:0.13 green:0.16 blue:0.20 alpha:1];
    [header addSubview:self.nameLabel];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(94, 52, header.bounds.size.width - 103, 24)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.font = RT7Font(14,NO);
    self.statusLabel.textColor = [UIColor colorWithRed:0.43 green:0.49 blue:0.56 alpha:1];
    [header addSubview:self.statusLabel];
    self.musicLabel = [[UILabel alloc] initWithFrame:CGRectMake(94, 81, header.bounds.size.width - 103, 22)];
    self.musicLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.musicLabel.backgroundColor = [UIColor clearColor];
    self.musicLabel.textColor = [UIColor colorWithRed:0.22 green:0.43 blue:0.66 alpha:1];
    self.musicLabel.font = RT7Font(14,NO);
    [self.musicLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showProfileMusic)]];
    [header addSubview:self.musicLabel];
    self.photoSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.photoSpinner.center = CGPointMake(44, 49);
    [header addSubview:self.photoSpinner];
    self.tableView.tableHeaderView = header;
    self.nameLabel.text=@"Мой профиль";
    [self applyTheme];
    __weak TGSettingsController *weakSettings=self; TGClient *profileClient=self.client;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSDictionary *profile=[profileClient cachedSelfProfile];
        NSDictionary *music=[profileClient cachedSavedMusicForUser:nil];
        dispatch_async(dispatch_get_main_queue(),^{
            TGSettingsController *controller=weakSettings; if(!controller)return;
            if(!controller.user) [controller applyProfile:profile];
            if(!controller.musicSnapshotLoaded && music) {
                controller.musicSnapshotLoaded=YES; controller.musicDocument=[music[@"documents"] firstObject]; [controller updateMusicDisplay];
            }
        });
    });
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
    [self loadProfile];
}
- (void)updateTelegram27ProfileHeader {
    self.telegram27Profile.hidden=YES;
    for(UIView *view in @[self.avatarView,self.avatarTap,self.nameLabel,self.statusLabel]) view.hidden=NO;
    NSString *phone=self.user[@"phone"],*username=self.user[@"username"];
    if(TGModernThemeEnabled()) {
        NSMutableArray *parts=[NSMutableArray array];
        if(phone.length) [parts addObject:[@"+" stringByAppendingString:phone]];
        if(username.length) [parts addObject:[@"@" stringByAppendingString:username]];
        self.statusLabel.text=[parts componentsJoinedByString:@" · "];
    }
}
- (void)applyTheme {
    TGSettingsTable(self.tableView);
    CGFloat width=self.tableView.bounds.size.width,height=self.musicDocument ? 128 : 96;
    self.profileHeader.backgroundColor=RT7Surface();
    BOOL changed=!CGRectEqualToRect(self.profileHeader.frame,CGRectMake(0,0,width,height));
    self.profileHeader.frame=CGRectMake(0,0,width,height);
    self.avatarView.frame=CGRectMake(15,15,64,64); self.avatarView.layer.cornerRadius=32; self.avatarView.clipsToBounds=YES;
    self.avatarOverlay.hidden=YES; self.avatarTap.frame=self.avatarView.frame;
    self.nameLabel.frame=CGRectMake(94,19,MAX(0,width-109),27); self.nameLabel.font=RT7Font(20,NO); self.nameLabel.textAlignment=NSTextAlignmentLeft; self.nameLabel.textColor=RT7Text();
    self.statusLabel.frame=CGRectMake(94,49,MAX(0,width-109),23); self.statusLabel.font=RT7Font(13,NO); self.statusLabel.textAlignment=NSTextAlignmentLeft; self.statusLabel.textColor=RT7SecondaryText();
    self.musicLabel.hidden=!self.musicDocument; self.musicLabel.frame=CGRectMake(15,88,width-30,30); self.musicLabel.font=RT7Font(15,NO); self.musicLabel.textAlignment=NSTextAlignmentLeft; self.musicLabel.textColor=RT7Primary(); self.musicLabel.backgroundColor=[UIColor clearColor]; self.musicLabel.layer.cornerRadius=0; self.musicLabel.userInteractionEnabled=self.musicDocument!=nil;
    self.avatarView.autoresizingMask=self.avatarTap.autoresizingMask=UIViewAutoresizingNone;
    self.photoSpinner.center=self.avatarView.center;
    self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
    [self updateTelegram27ProfileHeader];
    if(changed || self.tableView.tableHeaderView!=self.profileHeader)self.tableView.tableHeaderView=self.profileHeader;

}
- (void)loadProfile {
    if (!self.client.isReady || NSDate.date.timeIntervalSince1970-self.lastProfileLoad<30) return;
    self.lastProfileLoad=NSDate.date.timeIntervalSince1970;
    __weak TGSettingsController *weakSelf = self;
    [self.client getSelfProfile:^(NSDictionary *result, __unused NSString *error) {
        TGSettingsController *current = weakSelf;
        if (current && result) [current applyProfile:result];
    }];
    [self.client getSavedMusicForUser:nil offset:0 limit:1 completion:^(NSDictionary *result, __unused NSString *error) {
        TGSettingsController *current = weakSelf;
        if (!current || ![result[@"_"] isEqual:@"users.savedMusic"]) return;
        current.musicSnapshotLoaded = YES;
        NSDictionary *document = [result[@"documents"] firstObject];
        if ((!document && !current.musicDocument) || [document[@"id"] isEqual:current.musicDocument[@"id"]]) return;
        current.musicDocument = document;
        [current updateMusicDisplay];
    }];
}
- (void)applyCachedMusic {
    NSDictionary *snapshot = [self.client cachedSavedMusicForUser:nil];
    if (!snapshot) return;
    self.musicSnapshotLoaded = YES;
    NSDictionary *document = [snapshot[@"documents"] firstObject];
    if ((!document && !self.musicDocument) || [document[@"id"] isEqual:self.musicDocument[@"id"]]) return;
    self.musicDocument = document;
    [self updateMusicDisplay];
}
- (void)updateMusicDisplay {
    self.musicLabel.text = self.musicDocument ? [NSString stringWithFormat:@"♫  %@ — %@",
        TGProfileMusicTitle(self.musicDocument), TGProfileMusicArtist(self.musicDocument)] : @"";
    [self applyTheme];
    [self.tableView reloadData];
}
- (void)applyProfile:(NSDictionary *)profile {
    self.fullProfile = profile[@"full_user"];
    NSDictionary *savedMusic = profile[@"full_user"][@"saved_music"];
    if (!self.musicSnapshotLoaded && [savedMusic isKindOfClass:[NSDictionary class]] &&
        ![savedMusic[@"id"] isEqual:self.musicDocument[@"id"]]) {
        self.musicDocument = savedMusic;
        [self updateMusicDisplay];
    }
    NSNumber *identifier = profile[@"full_user"][@"id"];
    NSDictionary *candidate = nil;
    for (NSDictionary *user in profile[@"users"])
        if ([user[@"id"] isEqual:identifier] || [user[@"self"] boolValue]) { candidate = user; break; }
    if (candidate) self.user = candidate;
    NSString *name = [[@[self.user[@"first_name"] ?: @"", self.user[@"last_name"] ?: @""]
        componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.nameLabel.text = name.length ? name : @"Мой профиль";
    NSString *phone = self.user[@"phone"];
    NSString *username = self.user[@"username"];
    self.statusLabel.text = TGModernThemeEnabled() && username.length ? [@"@" stringByAppendingString:username] :
        phone.length ? [@"+" stringByAppendingString:phone] : @"в сети";
    NSDictionary *photo = self.user[@"photo"];
    if (!photo[@"photo_id"]) { self.avatarPhotoId=nil; self.avatarView.image = TGSettingsArt(@"SettingsAddPhoto"); [self updateTelegram27ProfileHeader]; return; }
    [self updateTelegram27ProfileHeader];
    NSNumber *photoId=photo[@"photo_id"];
    if([self.avatarPhotoId isEqual:photoId])return;
    self.avatarPhotoId=photoId;
    __weak TGSettingsController *weakSelf=self; TGClient *avatarClient=self.client;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSData *cached=[avatarClient cachedAvatarForPhoto:photo];
        if(cached.length) [weakSelf prepareProfileAvatar:cached photoId:photoId];
        else dispatch_async(dispatch_get_main_queue(),^{
            TGSettingsController *current=weakSelf; if(!current || ![current.avatarPhotoId isEqual:photoId])return;
            [current.client getAvatarForPeer:@{@"_":@"inputPeerSelf"} photo:photo completion:^(NSData *data,NSString *error) {
                if(data.length)[weakSelf prepareProfileAvatar:data photoId:photoId];
                else if([weakSelf.avatarPhotoId isEqual:photoId])weakSelf.avatarPhotoId=nil;
            }];
        });
    });
}
- (void)prepareProfileAvatar:(NSData *)data photoId:(NSNumber *)photoId {
    __weak TGSettingsController *weakSelf=self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        UIImage *source=[UIImage imageWithData:data]; if(!source)return;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(80,80),NO,2);
        CGFloat scale=MAX(80/source.size.width,80/source.size.height);
        [source drawInRect:CGRectMake((80-source.size.width*scale)/2,(80-source.size.height*scale)/2,source.size.width*scale,source.size.height*scale)];
        UIImage *decoded=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
        dispatch_async(dispatch_get_main_queue(),^{ TGSettingsController *current=weakSelf; if([current.avatarPhotoId isEqual:photoId])current.avatarView.image=decoded; });
    });
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return TGModernThemeEnabled() ? RT27SettingsSections().count : 5; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(TGModernThemeEnabled()) return [RT27SettingsSections()[section] count];
    return section == 0 ? 2 : section == 1 ? 12 : section == 3 ? 2 : 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return TGModernThemeEnabled() ? (section==0 ? 20 : 28) : section == 0 ? 9 : 17; }
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if(!TGModernThemeEnabled()) return nil;
    UIView *view=[[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,[self tableView:table heightForHeaderInSection:section])]; view.backgroundColor=TGModernCanvas(); return view;
}
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    if(!TGModernThemeEnabled()) return UITableViewAutomaticDimension;
    NSString *text=[self tableView:table titleForFooterInSection:section];
    return text.length ? TGModernSectionHeight(text,table.bounds.size.width,NO) : 0.1f;
}
- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    if(!TGModernThemeEnabled()) return nil;
    return TGModernSectionView([self tableView:table titleForFooterInSection:section],table.bounds.size.width,[self tableView:table heightForFooterInSection:section],NO);
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    if(TGModernThemeEnabled()) return 44;
    return path.section == 2 ? (TGModernThemeEnabled() ? 50 : 166) : path.section == 0 || path.section == 4 ? 45 : 44;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if(TGModernThemeEnabled()) section=section==6 ? 3 : section==7 ? 4 : -1;
    return section == 3 ? @"Сохранять входящие фотографии в альбом iPhone." :
        section == 4 ? [@"ReTwelve · " stringByAppendingString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @""] : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSIndexPath *action=RT27SettingsPath(path);
    RT7ListCell *cell=[tableView dequeueReusableCellWithIdentifier:@"material-settings"];
    if(!cell)cell=[[RT7ListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"material-settings"];
    cell.firstInGroup=path.row==0; cell.lastInGroup=path.row+1==[RT27SettingsSections()[path.section] count];
    cell.accessoryView=nil; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; cell.selectionStyle=UITableViewCellSelectionStyleGray; cell.textLabel.textColor=RT7Text();
    NSString *title=nil,*icon=nil;
    if(action.section==0) { title=action.row ? @"Музыка профиля" : @"Изменить фотографию"; icon=action.row ? @"music" : @"camera"; if(!action.row)cell.textLabel.textColor=RT7Primary(); }
    else if(action.section==1) { title=@[@"Уведомления и звуки",@"Заблокированные",@"Устройства",@"Настройки чатов",@"Оформление",@"Конфиденциальность",@"Прокси",@"Хранилище",@"Стикеры",@"Облачный пароль",@"Аккаунты",@"Код-пароль"][action.row]; icon=@[@"settings",@"lock",@"device",@"chat",@"gallery",@"lock",@"settings",@"file",@"sticker",@"lock",@"person",@"lock"][action.row]; }
    else if(action.section==2) { title=@"Фон чата"; icon=@"gallery"; }
    else if(action.section==3) { title=action.row ? @"Сохранять входящие фото" : @"Поддержка"; icon=action.row ? @"gallery" : @"chat"; if(action.row) { cell.accessoryType=UITableViewCellAccessoryNone; RT7Switch *toggle=[[RT7Switch alloc] init]; toggle.on=[[NSUserDefaults standardUserDefaults] boolForKey:@"TGSaveIncomingPhotos"]; toggle.accessibilityLabel=title; [toggle addTarget:self action:@selector(autosaveChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle; cell.selectionStyle=UITableViewCellSelectionStyleNone; } }
    else { title=@"Выйти"; icon=@"back"; cell.textLabel.textColor=RT7Error(); cell.accessoryType=UITableViewCellAccessoryNone; }
    cell.textLabel.text=title; cell.imageView.image=RT7Icon(icon,24,action.section==4 ? RT7Error() : RT7Primary());
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    path=RT27SettingsPath(path);
    if(path.section==0 && path.row==0) { [self changePhoto]; return; }
    if(path.section==4) { [self confirmLogout]; return; }
    if (path.section == 1 && path.row >= 5) {
        UIViewController *controller = path.row == 5 ? [[TGPrivacyController alloc] initWithClient:self.client] : path.row == 6 ? TGProxyForm(self.client) : path.row == 7 ? [[TGStorageController alloc] initWithClient:self.client] : path.row == 8 ? [[TGStickerCatalogController alloc] initWithClient:self.client] : path.row == 9 ? TGTwoStepPasswordForm(self.client) : path.row == 10 ? [[TGAccountsController alloc] initWithClient:self.client] : TGLocalPasscodeSettings();
        [self.navigationController pushViewController:controller animated:YES]; return;
    }
    if (path.section == 0 && path.row == 1) {
        [self showProfileMusic];
    } else if (path.section == 1) {
        if (path.row == 2) {
            [self.navigationController pushViewController:[[TGDevicesController alloc] initWithClient:self.client] animated:YES];
            return;
        }
        TGSettingsPage page = path.row == 0 ? TGSettingsPageNotifications :
            path.row == 1 ? TGSettingsPageBlocked : path.row == 3 ? TGSettingsPageChats : TGSettingsPageWallpapers;
        [self.navigationController pushViewController:[[TGSettingsDetailController alloc] initWithClient:self.client page:page] animated:YES];
    } else if (path.section == 2) {
        [self.navigationController pushViewController:[[TGSettingsDetailController alloc] initWithClient:self.client
            page:TGSettingsPageWallpapers] animated:YES];
    } else if (path.section == 3 && path.row == 0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://telegram.org/faq"]];
    }
}
- (void)showProfileMusic {
    [self.navigationController pushViewController:[[TGProfileMusicController alloc] initWithClient:self.client
        inputUser:nil ownerName:self.nameLabel.text isSelf:YES firstDocument:self.musicDocument] animated:YES];
}
- (void)autosaveChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"TGSaveIncomingPhotos"];
}
- (void)showAppearance {
    [self.navigationController pushViewController:[[TGSettingsDetailController alloc] initWithClient:self.client page:TGSettingsPageWallpapers] animated:NO];
}
- (void)modernThemeChanged:(UISwitch *)sender {
    TGSetModernThemeEnabled(sender.on);
    [self applyTheme];
    [self.tableView reloadData];
}
- (void)editProfile {
    if (!self.fullProfile || !self.user) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
        [self.client getSelfProfile:^(NSDictionary *result, NSString *error) {
            self.navigationItem.rightBarButtonItem.enabled = YES;
            if (error || !result[@"full_user"]) { TGSettingsAlert(@"Профиль", error ?: @"Не удалось загрузить профиль."); return; }
            [self applyProfile:result]; [self editProfile];
        }]; return;
    }
    [self.navigationController pushViewController:TGProfileForm(self.client, self.user, self.fullProfile) animated:YES];
}
- (void)changePhoto {
    UIActionSheet *sheet = [[RT7ActionSheet alloc] initWithTitle:@"Фото профиля" delegate:self
        cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil
        otherButtonTitles:@"Сделать фото", @"Выбрать из галереи", nil];
    sheet.tag = 10;
    [sheet showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (sheet.tag != 10 || index < 0 || index >= 2) return;
    UIImagePickerControllerSourceType source = index == 0 ? UIImagePickerControllerSourceTypeCamera :
        UIImagePickerControllerSourceTypePhotoLibrary;
    if (![UIImagePickerController isSourceTypeAvailable:source]) {
        TGSettingsAlert(@"Фото профиля", @"Источник фото недоступен."); return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = source; picker.allowsEditing = YES; picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [self dismissViewControllerAnimated:YES completion:nil];
    if (!image) return;
    [self.photoSpinner startAnimating];
    CGSize size = image.size;
    CGFloat scale = MIN(1, 640.0 / MAX(size.width, size.height));
    CGSize target = CGSizeMake(MAX(1, round(size.width * scale)), MAX(1, round(size.height * scale)));
    UIGraphicsBeginImageContextWithOptions(target, YES, 1);
    [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    UIImage *small = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *data = UIImageJPEGRepresentation(small, 0.78);
    __weak TGSettingsController *weakSelf = self;
    [self.client uploadProfilePhotoData:data completion:^(__unused NSDictionary *result, NSString *error) {
        TGSettingsController *current = weakSelf;
        if (!current) return;
        [current.photoSpinner stopAnimating];
        if (error) TGSettingsAlert(@"Фото профиля", error);
        else [current loadProfile];
    }];
}
- (void)confirmLogout {
    UIAlertView *alert = [[RT7AlertView alloc] initWithTitle:@"Выйти из аккаунта?"
        message:@"Для следующего входа потребуется код Telegram."
        delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Выйти", nil];
    alert.tag = 101;
    [alert show];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if (alert.tag != 101 || index != 1) return;
    [self.client logOut:^(__unused NSDictionary *result, NSString *error) {
        if (error) TGSettingsAlert(@"Ошибка выхода", error);
        else [[NSNotificationCenter defaultCenter] postNotificationName:@"TGSessionExpiredNotification" object:self.client];
    }];
}
@end
