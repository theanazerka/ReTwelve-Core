#import "Material/TGMaterialKit.h"
#import "TGTheme.h"
#import "TGDevicesController.h"
#import "TGClient.h"
#import "TGDeviceQRController.h"
#import "TGInlineAnimationView.h"

static UIImage *TGDevicesArt(NSString *name) {
    return [UIImage imageNamed:[@"OriginalTelegram/" stringByAppendingString:name]];
}
static UIImage *TGDevicesStretch(NSString *name) {
    UIImage *image = TGDevicesArt(name);
    return [image stretchableImageWithLeftCapWidth:(NSInteger)image.size.width / 2
                                 topCapHeight:(NSInteger)image.size.height / 2];
}

@interface TGDeviceSessionCell : TGClassicGroupedCell
@end
@implementation TGDeviceSessionCell
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width,inset=self.cardInset+16;
    if (self.detailTextLabel.text.length) {
        self.textLabel.frame = CGRectMake(inset, 8, MAX(0,width - 2*inset), 22);
        self.detailTextLabel.frame = CGRectMake(inset, 32, MAX(0,width - 2*inset), 34);
    } else self.textLabel.frame = CGRectMake(inset, 0, width - 2*inset, self.contentView.bounds.size.height);
}
@end

@interface TGDevicesController ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *currentSession;
@property (nonatomic, strong) NSArray *unconfirmedSessions, *otherSessions;
@property (nonatomic, strong) NSDictionary *selectedSession;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) TGInlineAnimationView *deviceAnimationView;
@property (nonatomic, strong) UILabel *headerHint;
@property (nonatomic, strong) UIButton *addDeviceButton;
@property (nonatomic) BOOL loading, busy;
- (void)updateDeviceAnimation;
@end

@implementation TGDevicesController
- (instancetype)initWithClient:(TGClient *)client {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) { _client = client; self.title = @"Устройства"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.separatorStyle = (TGModernThemeEnabled() ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone);
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:TGDevicesArt(@"SettingsBackground")];
    UILabel *empty = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    empty.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    empty.backgroundColor = [UIColor clearColor];
    empty.textColor = TGMaterialSecondaryText();
    empty.textAlignment = NSTextAlignmentCenter;
    empty.text = @"Загружаем устройства…";
    self.tableView.backgroundView = empty;
    self.emptyLabel = empty;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 244)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    TGInlineAnimationView *animationView = [[TGInlineAnimationView alloc] initWithFrame:CGRectMake((header.bounds.size.width - 144) / 2, 0, 144, 144) resourceName:@"Devices"];
    animationView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [header addSubview:animationView];
    self.deviceAnimationView = animationView;
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(18, 143, header.bounds.size.width - 36, 42)];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    hint.backgroundColor = [UIColor clearColor];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 2;
    hint.font = TGMaterialFont(14,NO);
    hint.textColor = [UIColor colorWithRed:0.43 green:0.49 blue:0.56 alpha:1];
    hint.text = @"Устройства, на которых выполнен вход в Telegram";
    [header addSubview:hint];
    self.headerHint = hint;
    UIButton *addDevice = [UIButton buttonWithType:UIButtonTypeCustom];
    addDevice.frame = CGRectMake(18, 193, header.bounds.size.width - 36, 43);
    addDevice.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [addDevice setBackgroundImage:TGDevicesStretch(@"GroupedCellSingle") forState:UIControlStateNormal];
    [addDevice setBackgroundImage:TGDevicesStretch(@"GroupedCellSingle_Selected") forState:UIControlStateHighlighted];
    [addDevice setTitle:@"Добавить устройство" forState:UIControlStateNormal];
    [addDevice setTitleColor:TGModernThemeEnabled() ? TGModernBlue() : [UIColor colorWithRed:0.15 green:0.32 blue:0.53 alpha:1] forState:UIControlStateNormal];
    addDevice.titleLabel.font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(17,YES);
    [addDevice addTarget:self action:@selector(addDevice) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:addDevice];
    self.addDeviceButton = addDevice;
    if (TGModernThemeEnabled()) {
        [addDevice setBackgroundImage:TGFlatImage(TGModernBlue()) forState:UIControlStateNormal];
        [addDevice setBackgroundImage:TGFlatImage([TGMaterialPrimary() colorWithAlphaComponent:.85]) forState:UIControlStateHighlighted];
        [addDevice setTitleColor:TGMaterialSurface() forState:UIControlStateNormal];
        addDevice.layer.cornerRadius = 22; addDevice.clipsToBounds = YES;
        hint.textColor = TGModernSecondaryText();
    }
    self.tableView.tableHeaderView = header;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
        target:self action:@selector(refresh)];
    [self refresh];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.currentSession && !self.loading && !self.busy) [self refresh];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *header = self.tableView.tableHeaderView;
    CGFloat width = self.tableView.bounds.size.width;
    if (!header || width <= 0) return;
    CGRect frame = header.frame;
    if (fabs(frame.size.width - width) > .5) { frame.size.width = width; header.frame = frame; self.tableView.tableHeaderView = header; }
    self.deviceAnimationView.frame = CGRectMake(floor((width - 144) / 2), 0, 144, 144);
    self.headerHint.frame = CGRectMake(24, 143, MAX(0, width - 48), 42);
    self.addDeviceButton.frame = CGRectMake(TGModernThemeEnabled() ? 12 : 18, 193, MAX(0, width - (TGModernThemeEnabled() ? 24 : 36)), 43);
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateDeviceAnimation];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.deviceAnimationView pause];
}
- (void)updateDeviceAnimation {
    BOOL visible = self.view.window && !self.tableView.dragging && !self.tableView.decelerating &&
        self.tableView.contentOffset.y < CGRectGetMaxY(self.tableView.tableHeaderView.frame);
    if (visible) [self.deviceAnimationView play];
    else [self.deviceAnimationView pause];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { [self updateDeviceAnimation]; }
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self updateDeviceAnimation];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView { [self updateDeviceAnimation]; }
- (void)addDevice {
    if (self.busy) return;
    __weak TGDevicesController *weakSelf = self;
    TGDeviceQRController *scanner = [[TGDeviceQRController alloc] initWithClient:self.client linked:^(NSDictionary *session) {
        TGDevicesController *controller = weakSelf;
        if (!controller) return;
        [controller refresh];
        NSString *device = session[@"device_model"] ?: @"Новое устройство";
        [[[UIAlertView alloc] initWithTitle:@"Устройство подключено" message:device delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
    }];
    [self.navigationController pushViewController:scanner animated:YES];
}
- (void)refresh {
    if (self.loading || self.busy) return;
    self.loading = YES;
    if (!self.currentSession) self.emptyLabel.text = @"Загружаем устройства…";
    self.navigationItem.rightBarButtonItem.enabled = NO;
    __weak TGDevicesController *weakSelf = self;
    [self.client getDeviceSessions:^(NSDictionary *result, NSString *error) {
        TGDevicesController *controller = weakSelf;
        if (!controller) return;
        controller.loading = NO;
        controller.navigationItem.rightBarButtonItem.enabled = YES;
        if (error) {
            if (!controller.currentSession) controller.emptyLabel.text = @"Не удалось загрузить устройства";
            [[[UIAlertView alloc] initWithTitle:@"Устройства" message:error delegate:nil
                cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        NSMutableArray *pending = [NSMutableArray array], *other = [NSMutableArray array];
        controller.currentSession = nil;
        for (NSDictionary *session in result[@"authorizations"]) {
            if ([session[@"current"] boolValue]) controller.currentSession = session;
            else if ([session[@"unconfirmed"] boolValue]) [pending addObject:session];
            else [other addObject:session];
        }
        NSComparator recentFirst = ^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [b[@"date_active"] compare:a[@"date_active"]];
        };
        [pending sortUsingComparator:recentFirst];
        [other sortUsingComparator:recentFirst];
        controller.unconfirmedSessions = pending;
        controller.otherSessions = other;
        controller.emptyLabel.text = nil;
        [controller.tableView reloadData];
    }];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.currentSession ? 1 : 0;
    if (section == 1) return self.unconfirmedSessions.count;
    if (section == 2) return self.otherSessions.count;
    return self.otherSessions.count + self.unconfirmedSessions.count > 0 ? 1 : 0;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return self.currentSession ? @"ЭТО УСТРОЙСТВО" : nil;
    if (section == 1) return self.unconfirmedSessions.count ? @"НЕПОДТВЕРЖДЁННЫЕ ВХОДЫ" : nil;
    if (section == 2) return self.otherSessions.count ? @"ДРУГИЕ УСТРОЙСТВА" : nil;
    return nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 3 && [self tableView:tableView numberOfRowsInSection:3] ?
        @"Текущий сеанс останется активным." : nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    return path.section == 3 ? 48 : TGModernThemeEnabled() ? 76 : 68;
}
- (NSDictionary *)sessionAtPath:(NSIndexPath *)path {
    if (path.section == 0) return self.currentSession;
    if (path.section == 1) return self.unconfirmedSessions[path.row];
    if (path.section == 2) return self.otherSessions[path.row];
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    TGDeviceSessionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"device-session"];
    if (!cell) cell = [[TGDeviceSessionCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"device-session"];
    NSInteger count = [self tableView:tableView numberOfRowsInSection:path.section];
    cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row + 1 == count ? 2 : 0);
    if (!TGModernThemeEnabled()) {
        cell.backgroundView = [[UIImageView alloc] initWithImage:TGDevicesStretch(@"GroupedCellSingle")];
        cell.selectedBackgroundView = [[UIImageView alloc] initWithImage:TGDevicesStretch(@"GroupedCellSingle_Selected")];
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.text = nil; cell.textLabel.textAlignment = NSTextAlignmentLeft; cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = TGMaterialText();
    if (path.section == 3) {
        cell.textLabel.text = @"Завершить другие сеансы";
        cell.textLabel.textColor = [UIColor colorWithRed:0.73 green:0.13 blue:0.13 alpha:1];
        cell.textLabel.font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(17,YES);
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    }
    NSDictionary *session = [self sessionAtPath:path];
    NSString *device = session[@"device_model"];
    if (!device.length) device = session[@"platform"] ?: @"Неизвестное устройство";
    NSString *app = session[@"app_name"] ?: @"Telegram";
    NSString *version = session[@"app_version"] ?: @"";
    NSString *place = session[@"region"];
    if (!place.length) place = session[@"country"];
    NSString *status = path.section == 0 ? @"в сети" : [self dateText:session[@"date_active"]];
    cell.textLabel.text = device;
    cell.textLabel.font = TGMaterialFont(17,YES);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@\n%@%@%@", app, version,
        place ?: @"", place.length ? @" · " : @"", status];
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.font = TGMaterialFont(TGModernThemeEnabled() ? 13 : 12,NO);
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.43 green:0.49 blue:0.56 alpha:1];
    cell.accessoryType = path.section == 0 ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (NSString *)dateText:(NSNumber *)date {
    if (![date longLongValue]) return @"";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[date doubleValue]]];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (self.busy || path.section == 0) return;
    if (path.section == 3) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Завершить другие сеансы?"
            message:@"Telegram выйдет из аккаунта на всех остальных устройствах."
            delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Завершить", nil];
        alert.tag = 602; [alert show]; return;
    }
    self.selectedSession = [self sessionAtPath:path];
    if (path.section == 1) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:self.selectedSession[@"device_model"]
            delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Завершить сеанс"
            otherButtonTitles:@"Подтвердить вход", nil];
        sheet.tag = 604; [sheet showInView:self.view];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Завершить сеанс?"
            message:[NSString stringWithFormat:@"%@ выйдет из аккаунта Telegram.",
                self.selectedSession[@"device_model"] ?: @"Устройство"]
            delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Завершить", nil];
        alert.tag = 601; [alert show];
    }
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (sheet.tag != 604 || index == sheet.cancelButtonIndex) return;
    if (index == sheet.destructiveButtonIndex) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Завершить сеанс?"
            message:@"Попытка входа будет отклонена." delegate:self cancelButtonTitle:@"Отмена"
            otherButtonTitles:@"Завершить", nil];
        alert.tag = 601; [alert show];
    } else if (index == 1) [self confirmSelected];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if (index == alert.cancelButtonIndex || self.busy) return;
    if (alert.tag == 601) [self terminateSelected];
    else if (alert.tag == 602) [self terminateOthers];
}
- (void)finishAction:(NSString *)error result:(NSDictionary *)result {
    self.busy = NO;
    if (error && [error rangeOfString:@"FRESH_RESET_AUTHORISATION_FORBIDDEN"].location != NSNotFound)
        error = @"После входа с этого устройства должно пройти 24 часа, прежде чем можно будет завершить другие сеансы.";
    if (!error && [result[@"_"] isEqual:@"boolFalse"]) error = @"Telegram не выполнил действие.";
    if (error) {
        [[[UIAlertView alloc] initWithTitle:@"Устройства" message:error delegate:nil
            cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
    } else [self refresh];
}
- (void)terminateSelected {
    NSNumber *hash = self.selectedSession[@"hash"];
    if (!hash) return;
    self.busy = YES;
    __weak TGDevicesController *weakSelf = self;
    [self.client terminateDeviceSession:hash completion:^(NSDictionary *result, NSString *error) {
        [weakSelf finishAction:error result:result];
    }];
}
- (void)terminateOthers {
    self.busy = YES;
    __weak TGDevicesController *weakSelf = self;
    [self.client terminateOtherDeviceSessions:^(NSDictionary *result, NSString *error) {
        [weakSelf finishAction:error result:result];
    }];
}
- (void)confirmSelected {
    NSNumber *hash = self.selectedSession[@"hash"];
    if (!hash) return;
    self.busy = YES;
    __weak TGDevicesController *weakSelf = self;
    [self.client confirmDeviceSession:hash completion:^(NSDictionary *result, NSString *error) {
        [weakSelf finishAction:error result:result];
    }];
}
@end
