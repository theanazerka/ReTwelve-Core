#import "Material/TGMaterialKit.h"
#import "TGMessageToolsController.h"
#import "TGClient.h"
#import "LegacyCompose/TGGroupedCell.h"
@interface TGMessageToolsController () <UISearchBarDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer, *result;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) NSString *mode;
@property (nonatomic) int32_t topic;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) BOOL loading, more;
@property (nonatomic, strong) UILabel *empty;
@property (nonatomic, strong) NSDictionary *actionMessage;
@end
@implementation TGMessageToolsController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer topic:(int32_t)topic mode:(NSString *)mode {
    if ((self = [super initWithStyle:UITableViewStylePlain])) { _client = client; _peer = peer; _mode = mode; _topic = topic; _messages = @[]; self.hidesBottomBarWhenPushed = YES; self.title = @{@"pinned": @"Закреплённые", @"scheduled": @"Отложенные", @"photos": @"Фото и видео", @"files": @"Файлы", @"links": @"Ссылки", @"search": @"Поиск сообщений"}[mode] ?: @"Сообщения"; } return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.tableView.rowHeight = 72;
    self.empty = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, self.view.bounds.size.width - 40, 80)];
    self.empty.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.empty.textAlignment = NSTextAlignmentCenter;
    self.empty.backgroundColor = [UIColor clearColor]; self.empty.textColor = TGMaterialSecondaryText(); self.empty.font = TGMaterialFont(15,NO); self.empty.numberOfLines = 3;
    if ([self.mode isEqual:@"search"]) { self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)]; self.search.placeholder = self.peer ? @"Поиск в чате" : @"Поиск по переписке"; self.search.delegate = self; self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.tableView.tableHeaderView = self.search; self.empty.text = @"Введите текст сообщения"; }
    else [self load:NO];
    self.tableView.tableFooterView = self.empty;
    if ([self.mode isEqual:@"pinned"]) [self.tableView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pinnedHeld:)]];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
    NSUInteger generation = ++self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ if (generation == self.generation) [self load:NO]; });
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; [self load:NO]; }
- (void)load:(BOOL)next {
    NSString *query = self.search.text ?: @"";
    if ([self.mode isEqual:@"search"] && !query.length) { self.messages = @[]; [self.tableView reloadData]; self.empty.text = @"Введите текст сообщения"; return; }
    if (next && (self.loading || !self.more)) return;
    NSUInteger generation = ++self.generation; self.loading = YES;
    self.empty.text = @"Загрузка…";
    NSDictionary *last = next ? [self.messages lastObject] : nil;
    NSMutableDictionary *request;
    if ([self.mode isEqual:@"scheduled"]) request = [@{ @"_": @"messages.getScheduledHistory", @"peer": self.peer, @"hash": @0 } mutableCopy];
    else if (self.peer) {
        request = [@{ @"_": @"messages.search", @"peer": self.peer, @"q": query, @"filter": @{ @"_": @{@"pinned": @"inputMessagesFilterPinned", @"photos": @"inputMessagesFilterPhotoVideo", @"files": @"inputMessagesFilterDocument", @"links": @"inputMessagesFilterUrl"}[self.mode] ?: @"inputMessagesFilterEmpty" }, @"min_date": @0, @"max_date": @0, @"offset_id": last[@"id"] ?: @0, @"add_offset": @0, @"limit": @50, @"max_id": @0, @"min_id": @0, @"hash": @0 } mutableCopy];
        if (self.topic > 1) request[@"top_msg_id"] = @(self.topic);
    } else {
        NSDictionary *offsetPeer = @{ @"_": @"inputPeerEmpty" };
        if (last) offsetPeer = [self inputPeerForMessage:last];
        request = [@{ @"_": @"messages.searchGlobal", @"q": query, @"filter": @{ @"_": @"inputMessagesFilterEmpty" }, @"min_date": @0, @"max_date": @0, @"offset_rate": next ? self.result[@"next_rate"] ?: @0 : @0, @"offset_peer": offsetPeer, @"offset_id": last[@"id"] ?: @0, @"limit": @50 } mutableCopy];
    }
    __weak TGMessageToolsController *weakSelf = self;
    [self.client performRequest:request completion:^(NSDictionary *result, NSString *error) {
        TGMessageToolsController *view = weakSelf; if (!view || generation != view.generation) return;
        view.loading = NO; NSArray *items = result[@"messages"] ?: @[]; view.more = ![view.mode isEqual:@"scheduled"] && items.count >= 50;
        if (next) { NSMutableDictionary *merged = [result mutableCopy]; for (NSString *key in @[@"users", @"chats"]) merged[key] = [(view.result[key] ?: @[]) arrayByAddingObjectsFromArray:result[key] ?: @[]]; view.result = merged; view.messages = [view.messages arrayByAddingObjectsFromArray:items]; }
        else { view.result = result; view.messages = items; }
        view.empty.text = error ?: (view.messages.count ? @"" : @"Сообщений нет"); [view.tableView reloadData];
    }];
}
- (NSDictionary *)inputPeerForMessage:(NSDictionary *)message {
    NSDictionary *peer = message[@"peer_id"]; NSNumber *identifier = peer[@"user_id"] ?: peer[@"channel_id"] ?: peer[@"chat_id"];
    if (peer[@"chat_id"]) return @{ @"_": @"inputPeerChat", @"chat_id": identifier };
    NSString *array = peer[@"user_id"] ? @"users" : @"chats";
    for (NSDictionary *entity in self.result[array]) if ([entity[@"id"] isEqual:identifier]) return peer[@"user_id"] ? @{ @"_": @"inputPeerUser", @"user_id": identifier, @"access_hash": entity[@"access_hash"] ?: @0 } : @{ @"_": @"inputPeerChannel", @"channel_id": identifier, @"access_hash": entity[@"access_hash"] ?: @0 };
    return @{ @"_": @"inputPeerEmpty" };
}
- (NSInteger)tableView:(UITableView *)view numberOfRowsInSection:(NSInteger)section { return self.messages.count; }
- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [view dequeueReusableCellWithIdentifier:@"message"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"message"];
    NSDictionary *message = self.messages[path.row]; cell.textLabel.font = TGMaterialFont(16,NO); cell.textLabel.numberOfLines = 2;
    cell.textLabel.text = [message[@"message"] length] ? message[@"message"] : message[@"media"] ? @"Вложение" : @"Сообщение";
    NSDateFormatter *format = [[NSDateFormatter alloc] init]; format.dateFormat = @"dd.MM.yyyy HH:mm";
    cell.detailTextLabel.text = [format stringFromDate:[NSDate dateWithTimeIntervalSince1970:[message[@"date"] doubleValue]]]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (path.row + 5 >= self.messages.count) [self load:YES]; return cell;
}
- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)path {
    [view deselectRowAtIndexPath:path animated:YES]; [self.search resignFirstResponder]; NSDictionary *message = self.messages[path.row];
    if ([self.mode isEqual:@"scheduled"]) { self.actionMessage = message; UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Отложенное сообщение" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Удалить" otherButtonTitles:@"Отправить сейчас", nil]; [sheet showInView:self.view]; }
    else if (self.selection) self.selection(message, self.result);
}
- (void)pinnedHeld:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:[gesture locationInView:self.tableView]];
    if (!path || path.row >= self.messages.count) return; self.actionMessage = self.messages[path.row];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Закреплённое сообщение" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Открепить" otherButtonTitles:nil]; sheet.tag = 1; [sheet showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == sheet.cancelButtonIndex) return;
    if (sheet.tag == 1) { [self.client performRequest:@{@"_": @"messages.updatePinnedMessage", @"peer": self.peer, @"id": self.actionMessage[@"id"], @"unpin": @YES} completion:^(NSDictionary *result, NSString *error) { if (error) [[[UIAlertView alloc] initWithTitle:@"Ошибка" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; else [self load:NO]; }]; return; }
    [self.client performRequest:@{ @"_": index == sheet.destructiveButtonIndex ? @"messages.deleteScheduledMessages" : @"messages.sendScheduledMessages", @"peer": self.peer, @"id": @[self.actionMessage[@"id"]] } completion:^(NSDictionary *result, NSString *error) {
        if (error) [[[UIAlertView alloc] initWithTitle:@"Ошибка" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; else [self load:NO];
    }];
}
@end
@interface TGScheduleMessageController ()
@property (nonatomic, strong) UIDatePicker *picker;
@property (nonatomic, strong) UILabel *descriptionLabel;
@end
@implementation TGScheduleMessageController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Отправить позже"; self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/SettingsBackground"]];
    self.picker = [[UIDatePicker alloc] init]; self.picker.minimumDate = [NSDate dateWithTimeIntervalSinceNow:60]; self.picker.date = [NSDate dateWithTimeIntervalSinceNow:3600]; [self.view addSubview:self.picker];
    self.descriptionLabel = [[UILabel alloc] init]; self.descriptionLabel.text = @"Сообщение будет отправлено Telegram\nв выбранное время."; self.descriptionLabel.numberOfLines = 2; self.descriptionLabel.textAlignment = NSTextAlignmentCenter; self.descriptionLabel.backgroundColor = [UIColor clearColor]; self.descriptionLabel.font = TGMaterialFont(15,NO); [self.view addSubview:self.descriptionLabel];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово" style:UIBarButtonItemStyleDone target:self action:@selector(done)];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.descriptionLabel.frame = CGRectMake(12, 15, self.view.bounds.size.width - 24, 60); self.picker.frame = CGRectMake(0, 85, self.view.bounds.size.width, 216); }
- (void)done { if (self.selection) self.selection((int32_t)[self.picker.date timeIntervalSince1970]); [self.navigationController popViewControllerAnimated:YES]; }
@end
