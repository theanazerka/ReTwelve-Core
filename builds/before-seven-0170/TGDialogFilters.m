#import "TGTheme.h"
#import "TGDialogFilters.h"
#import "TGClient.h"
#import "TGFeatureForms.h"
#import "LegacyCompose/TGGroupedCell.h"
@interface TGDialogFiltersController ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *filters;
@property (nonatomic) BOOL loading;
@end
@implementation TGDialogFiltersController
- (instancetype)initWithClient:(TGClient *)client { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _client = client; _filters = @[]; self.title = @"Папки чатов"; self.hidesBottomBarWhenPushed = YES; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundView = nil; self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/SettingsBackground"]]; self.tableView.separatorStyle = (TGModernThemeEnabled() ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone); self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)]; self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Изменить" style:UIBarButtonItemStylePlain target:self action:@selector(edit)]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; }
- (void)reload {
    if (self.loading) return; self.loading = YES; __weak TGDialogFiltersController *weakSelf = self;
    [self.client performRequest:@{@"_": @"messages.getDialogFilters"} completion:^(NSDictionary *result, NSString *error) {
        TGDialogFiltersController *controller = weakSelf; if (!controller) return; controller.loading = NO;
        if (error) { [[[UIAlertView alloc] initWithTitle:@"Папки не загрузились" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; return; }
        NSMutableArray *filters = [NSMutableArray array]; for (NSDictionary *filter in result[@"filters"]) if ([filter[@"_"] isEqual:@"dialogFilter"] || [filter[@"_"] isEqual:@"dialogFilterChatlist"]) [filters addObject:filter]; controller.filters = filters; [controller.tableView reloadData];
    }];
}
- (void)edit { [self.tableView setEditing:!self.tableView.editing animated:YES]; self.navigationItem.leftBarButtonItem.title = self.tableView.editing ? @"Готово" : @"Изменить"; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.filters.count + 1; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    TGGroupedCell *cell = [[TGGroupedCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row == self.filters.count ? 2 : 0); cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; cell.textLabel.text = path.row == 0 ? @"Все чаты" : self.filters[path.row - 1][@"title"][@"text"]; cell.detailTextLabel.text = path.row && self.tableView.editing ? @"Нажмите, чтобы изменить" : nil; return cell;
}
- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path { return path.row > 0; }
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *filter = self.filters[path.row - 1]; table.userInteractionEnabled = NO;
    [self.client performRequest:@{@"_": @"messages.updateDialogFilter", @"id": filter[@"id"]} completion:^(NSDictionary *result, NSString *error) { table.userInteractionEnabled = YES; if (error) [[[UIAlertView alloc] initWithTitle:@"Ошибка" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; else [self reload]; }];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; NSDictionary *filter = path.row ? self.filters[path.row - 1] : nil;
    if (self.tableView.editing && filter) { [self editFilter:filter]; return; }
    if (self.selection) self.selection(filter); [self.navigationController popViewControllerAnimated:YES];
}
- (void)add { [self editFilter:nil]; }
- (void)editFilter:(NSDictionary *)original {
    if (original && ![original[@"_"] isEqual:@"dialogFilter"]) { [[[UIAlertView alloc] initWithTitle:@"Общая папка" message:@"Папку, полученную по ссылке, можно выбрать или удалить. Настройки её состава задаёт владелец." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; return; }
    int identifier = 2; for (NSDictionary *filter in self.filters) identifier = MAX(identifier, [filter[@"id"] intValue] + 1);
    NSMutableDictionary *values = [original mutableCopy] ?: [@{@"contacts": @YES, @"non_contacts": @YES, @"groups": @YES, @"broadcasts": @YES, @"bots": @YES} mutableCopy]; values[@"name"] = original[@"title"][@"text"] ?: @"";
    NSArray *keys = @[@"contacts", @"non_contacts", @"groups", @"broadcasts", @"bots", @"exclude_muted", @"exclude_read", @"exclude_archived"];
    NSArray *titles = @[@"Контакты", @"Другие пользователи", @"Группы", @"Каналы", @"Боты", @"Без отключённого звука", @"Только непрочитанные", @"Без архива"];
    NSMutableArray *fields = [NSMutableArray arrayWithObject:@{@"key": @"name", @"title": @"Название", @"required": @YES}];
    for (NSUInteger i = 0; i < keys.count; i++) [fields addObject:@{@"key": keys[i], @"title": titles[i], @"type": @"switch"}];
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:original ? @"Изменить папку" : @"Новая папка" fields:fields values:values save:^(NSDictionary *input, void (^completion)(NSString *)) {
        NSString *name = [input[@"name"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length > 12) { completion(@"Название должно содержать не больше 12 символов."); return; }
        BOOL any = NO; for (NSString *key in [keys subarrayWithRange:NSMakeRange(0, 5)]) any |= [input[key] boolValue];
        if (!any && ![original[@"include_peers"] count]) { completion(@"Выберите хотя бы один вид чатов."); return; }
        NSMutableDictionary *filter = [original mutableCopy] ?: [@{@"_": @"dialogFilter", @"id": @(identifier), @"pinned_peers": @[], @"include_peers": @[], @"exclude_peers": @[]} mutableCopy];
        filter[@"title"] = @{@"_": @"textWithEntities", @"text": name, @"entities": @[]}; for (NSString *key in keys) filter[key] = @([input[key] boolValue]);
        [self.client performRequest:@{@"_": @"messages.updateDialogFilter", @"id": filter[@"id"], @"filter": filter} completion:^(NSDictionary *result, NSString *error) { completion(error); }];
    }]; form.explanation = @"Папка синхронизируется с другими устройствами. Чаты, добавленные или исключённые там вручную, сохраняются."; [self.navigationController pushViewController:form animated:YES];
}
@end
