#import "Material/TGMaterialKit.h"
#import "TGTheme.h"
#import "TGClassicTableController.h"
#import "TGGroupManagementController.h"
#import "TGClient.h"
#import "TGFeatureForms.h"
#import "LegacyCompose/TGGroupedCell.h"
static void TGManagementError(NSString *error) { if (error) [[[UIAlertView alloc] initWithTitle:@"Не удалось выполнить действие" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; }
static void TGManagementStyle(UITableView *table) { table.backgroundView = nil; table.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/SettingsBackground"]]; table.separatorStyle = (TGModernThemeEnabled() ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone); }
@interface TGGroupMembersController : TGClassicTableController <UIActionSheetDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer, *entity;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) NSMutableDictionary *users;
@property (nonatomic, strong) NSDictionary *chosen;
@property (nonatomic) BOOL loading, more;
@end
@implementation TGGroupMembersController
- (void)viewDidLoad { [super viewDidLoad]; self.entries = @[]; self.users = [NSMutableDictionary dictionary]; self.tableView.rowHeight = 62; self.more = YES; self.hidesBottomBarWhenPushed = YES; TGManagementStyle(self.tableView); [self load:NO]; }
- (NSDictionary *)channel { return @{@"_": @"inputChannel", @"channel_id": self.peer[@"channel_id"], @"access_hash": self.peer[@"access_hash"]}; }
- (void)load:(BOOL)next {
    if (self.loading || (next && !self.more)) return; self.loading = YES;
    NSMutableDictionary *request;
    if ([self.mode isEqual:@"requests"]) request = [@{@"_": @"messages.getChatInviteImporters", @"requested": @YES, @"peer": self.peer, @"offset_date": next ? [self.entries lastObject][@"date"] ?: @0 : @0, @"offset_user": @{@"_": @"inputUserEmpty"}, @"limit": @100} mutableCopy];
    else if (self.peer[@"chat_id"]) request = [@{@"_": @"messages.getFullChat", @"chat_id": self.peer[@"chat_id"]} mutableCopy];
    else {
        NSMutableDictionary *filter = [@{@"_": [self.mode isEqual:@"admins"] ? @"channelParticipantsAdmins" : [self.mode isEqual:@"banned"] ? @"channelParticipantsKicked" : @"channelParticipantsRecent"} mutableCopy];
        if ([self.mode isEqual:@"banned"]) filter[@"q"] = @"";
        request = [@{@"_": @"channels.getParticipants", @"channel": [self channel], @"filter": filter, @"offset": next ? @(self.entries.count) : @0, @"limit": @100, @"hash": @0} mutableCopy];
    }
    if (next && [self.mode isEqual:@"requests"]) { NSDictionary *user = self.users[[self.entries lastObject][@"user_id"]]; if (user[@"access_hash"]) request[@"offset_user"] = @{@"_": @"inputUser", @"user_id": user[@"id"], @"access_hash": user[@"access_hash"]}; }
    __weak TGGroupMembersController *weakSelf = self;
    [self.client performRequest:request completion:^(NSDictionary *result, NSString *error) {
        TGGroupMembersController *controller = weakSelf; if (!controller) return; controller.loading = NO; if (error) { TGManagementError(error); return; }
        NSArray *items = [controller.mode isEqual:@"requests"] ? result[@"importers"] : controller.peer[@"chat_id"] ? result[@"full_chat"][@"participants"][@"participants"] : result[@"participants"];
        for (NSDictionary *user in result[@"users"]) if (user[@"id"]) controller.users[user[@"id"]] = user;
        if ([controller.mode isEqual:@"admins"] && controller.peer[@"chat_id"]) items = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *entry, __unused NSDictionary *bindings) { return [entry[@"_"] isEqual:@"chatParticipantAdmin"] || [entry[@"_"] isEqual:@"chatParticipantCreator"]; }]];
        controller.more = !controller.peer[@"chat_id"] && items.count == 100;
        controller.entries = next ? [controller.entries arrayByAddingObjectsFromArray:items ?: @[]] : items ?: @[]; [controller.tableView reloadData];
    }];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.entries.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    TGGroupedCell *cell = [table dequeueReusableCellWithIdentifier:@"member"]; if (!cell) cell = [[TGClassicGroupedCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"member"];
    cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row == self.entries.count - 1 ? 2 : 0); cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    NSDictionary *entry = self.entries[path.row]; NSNumber *identifier = entry[@"user_id"] ?: entry[@"peer"][@"user_id"]; NSDictionary *user = self.users[identifier];
    cell.textLabel.text = [[@[user[@"first_name"] ?: @"", user[@"last_name"] ?: @""] componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!cell.textLabel.text.length) cell.textLabel.text = [identifier description] ?: @"Участник";
    cell.detailTextLabel.text = [entry[@"_"] rangeOfString:@"Creator"].location != NSNotFound ? @"Владелец" : entry[@"rank"] ?: user[@"username"] ?: @"";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; if (path.row + 4 >= self.entries.count) [self load:YES]; return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; self.chosen = self.entries[path.row];
    if ([self.chosen[@"_"] rangeOfString:@"Creator"].location != NSNotFound) return;
    if ([self.mode isEqual:@"requests"]) { UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Заявка на вступление" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Отклонить" otherButtonTitles:@"Принять", nil]; [sheet showInView:self.view]; return; }
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Участник" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil otherButtonTitles:@"Права администратора", self.peer[@"channel_id"] ? @"Ограничения" : nil, nil]; [sheet showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == sheet.cancelButtonIndex) return;
    NSNumber *identifier = self.chosen[@"user_id"] ?: self.chosen[@"peer"][@"user_id"]; NSDictionary *user = self.users[identifier];
    if (!identifier || !user[@"access_hash"]) { TGManagementError(@"Не удалось получить данные пользователя. Обновите список."); return; }
    NSDictionary *inputUser = @{@"_": @"inputUser", @"user_id": identifier, @"access_hash": user[@"access_hash"]};
    if ([self.mode isEqual:@"requests"]) { [self.client performRequest:@{@"_": @"messages.hideChatJoinRequest", @"peer": self.peer, @"user_id": inputUser, @"approved": @(index != sheet.destructiveButtonIndex)} completion:^(NSDictionary *result, NSString *error) { TGManagementError(error); if (!error) [self load:NO]; }]; return; }
    BOOL admin = index == 0;
    if (self.peer[@"chat_id"]) {
        TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Администратор" fields:@[@{@"key": @"enabled", @"title": @"Администратор", @"type": @"switch"}] values:@{@"enabled": @([self.chosen[@"_"] isEqual:@"chatParticipantAdmin"])} save:^(NSDictionary *values, void (^completion)(NSString *)) { [self.client performRequest:@{@"_": @"messages.editChatAdmin", @"chat_id": self.peer[@"chat_id"], @"user_id": inputUser, @"is_admin": @([values[@"enabled"] boolValue])} completion:^(NSDictionary *result, NSString *error) { completion(error); if (!error) [self load:NO]; }]; }]; [self.navigationController pushViewController:form animated:YES]; return;
    }
    NSArray *keys = admin ? @[@"change_info", @"post_messages", @"edit_messages", @"delete_messages", @"ban_users", @"invite_users", @"pin_messages", @"add_admins", @"anonymous", @"manage_topics"] : @[@"view_messages", @"send_messages", @"send_photos", @"send_videos", @"send_audios", @"send_voices", @"send_docs", @"send_stickers", @"send_gifs", @"send_polls", @"embed_links", @"invite_users", @"pin_messages", @"change_info", @"manage_topics"];
    NSArray *titles = admin ? @[@"Изменять информацию", @"Публиковать сообщения", @"Редактировать сообщения", @"Удалять сообщения", @"Блокировать участников", @"Приглашать участников", @"Закреплять сообщения", @"Добавлять администраторов", @"Анонимный администратор", @"Управлять темами"] : @[@"Заблокировать участника", @"Запретить сообщения", @"Запретить фотографии", @"Запретить видео", @"Запретить музыку", @"Запретить голосовые", @"Запретить файлы", @"Запретить стикеры", @"Запретить GIF", @"Запретить опросы", @"Запретить ссылки", @"Запретить приглашения", @"Запретить закрепления", @"Запретить изменение данных", @"Запретить управление темами"];
    NSMutableArray *fields = [NSMutableArray array]; for (NSUInteger i = 0; i < keys.count; i++) [fields addObject:@{@"key": keys[i], @"title": titles[i], @"type": @"switch"}];
    NSDictionary *oldRights = self.chosen[admin ? @"admin_rights" : @"banned_rights"];
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:admin ? @"Права администратора" : @"Ограничения" fields:fields values:oldRights ?: @{} save:^(NSDictionary *values, void (^completion)(NSString *)) {
        NSMutableDictionary *rights = [oldRights mutableCopy] ?: [NSMutableDictionary dictionary]; rights[@"_"] = admin ? @"chatAdminRights" : @"chatBannedRights"; for (NSString *key in keys) rights[key] = @([values[key] boolValue]);
        if (!admin) rights[@"until_date"] = @0;
        NSMutableDictionary *request = [@{@"_": admin ? @"channels.editAdmin" : @"channels.editBanned", @"channel": [self channel]} mutableCopy];
        if (admin) { request[@"user_id"] = inputUser; request[@"admin_rights"] = rights; request[@"rank"] = self.chosen[@"rank"] ?: @""; }
        else { request[@"participant"] = @{@"_": @"inputPeerUser", @"user_id": identifier, @"access_hash": user[@"access_hash"]}; request[@"banned_rights"] = rights; }
        [self.client performRequest:request completion:^(NSDictionary *result, NSString *error) { completion(error); if (!error) [self load:NO]; }];
    }]; form.explanation = admin ? @"Права вступают в силу после нажатия «Готово»." : @"Включённый переключатель запрещает выбранное действие. Ограничения действуют без срока."; [self.navigationController pushViewController:form animated:YES];
}
@end
@interface TGGroupInvitesController : TGClassicTableController <UIActionSheetDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer, *chosen;
@property (nonatomic, strong) NSArray *invites;
@end
@implementation TGGroupInvitesController
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"Ссылки-приглашения"; self.hidesBottomBarWhenPushed = YES; self.tableView.rowHeight = 70; TGManagementStyle(self.tableView); self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)]; [self reload]; }
- (void)reload { [self.client performRequest:@{@"_": @"messages.getExportedChatInvites", @"peer": self.peer, @"admin_id": @{@"_": @"inputUserSelf"}, @"limit": @100} completion:^(NSDictionary *result, NSString *error) { TGManagementError(error); if (!error) { self.invites = result[@"invites"] ?: @[]; [self.tableView reloadData]; } }]; }
- (void)add { TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Новая ссылка" fields:@[@{@"key": @"title", @"title": @"Название ссылки"}, @{@"key": @"request_needed", @"title": @"Заявки на вступление", @"type": @"switch"}] values:nil save:^(NSDictionary *values, void (^completion)(NSString *)) { NSMutableDictionary *request = [@{@"_": @"messages.exportChatInvite", @"peer": self.peer, @"request_needed": @([values[@"request_needed"] boolValue])} mutableCopy]; if ([values[@"title"] length]) request[@"title"] = values[@"title"]; [self.client performRequest:request completion:^(NSDictionary *result, NSString *error) { completion(error); if (!error) [self reload]; }]; }]; [self.navigationController pushViewController:form animated:YES]; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.invites.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path { TGGroupedCell *cell = [[TGClassicGroupedCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row == self.invites.count - 1 ? 2 : 0); NSDictionary *invite = self.invites[path.row]; cell.textLabel.text = [invite[@"title"] length] ? invite[@"title"] : invite[@"link"]; cell.textLabel.font = TGMaterialFont(15,YES); cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ вступлений%@", invite[@"usage"] ?: @0, [invite[@"request_needed"] boolValue] ? @" · по заявке" : @""]; cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell; }
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { [table deselectRowAtIndexPath:path animated:YES]; self.chosen = self.invites[path.row]; UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:self.chosen[@"link"] delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Отозвать ссылку" otherButtonTitles:@"Скопировать", nil]; [sheet showInView:self.view]; }
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index { if (index == sheet.cancelButtonIndex) return; if (index != sheet.destructiveButtonIndex) { [UIPasteboard generalPasteboard].string = self.chosen[@"link"]; return; } [self.client performRequest:@{@"_": @"messages.editExportedChatInvite", @"peer": self.peer, @"link": self.chosen[@"link"], @"revoked": @YES} completion:^(NSDictionary *result, NSString *error) { TGManagementError(error); if (!error) [self reload]; }]; }
@end
@interface TGGroupManagementController ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer, *entity;
@end
@implementation TGGroupManagementController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _client = client; _peer = peer; _entity = entity; self.title = @"Управление"; self.hidesBottomBarWhenPushed = YES; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; TGManagementStyle(self.tableView); }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.peer[@"channel_id"] ? 5 : 4; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path { TGGroupedCell *cell = [[TGClassicGroupedCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; NSInteger count = self.peer[@"channel_id"] ? 5 : 4; cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row == count - 1 ? 2 : 0); cell.textLabel.backgroundColor = [UIColor clearColor]; cell.textLabel.font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(16,YES); cell.textLabel.text = (self.peer[@"channel_id"] ? @[@"Участники", @"Администраторы", @"Заблокированные", @"Заявки на вступление", @"Ссылки-приглашения"] : @[@"Участники", @"Администраторы", @"Заявки на вступление", @"Ссылки-приглашения"])[path.row]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell; }
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { [table deselectRowAtIndexPath:path animated:YES]; BOOL channel = self.peer[@"channel_id"] != nil; NSInteger invites = channel ? 4 : 3; if (path.row == invites) { TGGroupInvitesController *controller = [[TGGroupInvitesController alloc] initWithStyle:UITableViewStyleGrouped]; controller.client = self.client; controller.peer = self.peer; [self.navigationController pushViewController:controller animated:YES]; } else { TGGroupMembersController *controller = [[TGGroupMembersController alloc] initWithStyle:UITableViewStyleGrouped]; controller.client = self.client; controller.peer = self.peer; controller.entity = self.entity; controller.mode = (channel ? @[@"members", @"admins", @"banned", @"requests"] : @[@"members", @"admins", @"requests"])[path.row]; controller.title = [table cellForRowAtIndexPath:path].textLabel.text; [self.navigationController pushViewController:controller animated:YES]; } }
@end
