#import "Seven/RT7UIKit.h"
#import "TGTheme.h"
#import "TGAccountsController.h"
#import "TGClient.h"
#import "LegacyCompose/TGGroupedCell.h"
NSString *TGActiveAccountIdentifier(void) { return [[NSUserDefaults standardUserDefaults] stringForKey:@"TGActiveAccount"] ?: @""; }
void TGRememberAccount(NSString *identifier, NSDictionary *user) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; NSMutableArray *accounts = [[defaults arrayForKey:@"TGAccounts"] mutableCopy] ?: [NSMutableArray array];
    NSUInteger index = NSNotFound; for (NSUInteger i = 0; i < accounts.count; i++) if ([accounts[i][@"key"] isEqual:identifier]) { index = i; break; }
    NSMutableDictionary *entry = index == NSNotFound ? [NSMutableDictionary dictionaryWithObject:identifier forKey:@"key"] : [accounts[index] mutableCopy];
    if (user) { entry[@"title"] = [[@[user[@"first_name"] ?: @"", user[@"last_name"] ?: @""] componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; entry[@"phone"] = user[@"phone"] ?: @""; entry[@"user_id"] = user[@"id"] ?: @0; }
    if (index == NSNotFound) [accounts addObject:entry]; else accounts[index] = entry;
    [defaults setObject:accounts forKey:@"TGAccounts"];
}
@interface TGAccountsController ()
@property (nonatomic, strong) NSArray *accounts;
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) TGClient *removingClient;
@property (nonatomic, copy) NSString *removingIdentifier;
@end
@implementation TGAccountsController
- (instancetype)init { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { self.title = @"Аккаунты"; self.hidesBottomBarWhenPushed = YES; } return self; }
- (instancetype)initWithClient:(TGClient *)client { if ((self = [self init])) self.client = client; return self; }
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundView = nil; self.tableView.backgroundColor = [UIColor colorWithPatternImage:RT7ImageNamed(@"OriginalTelegram/SettingsBackground")]; self.tableView.separatorStyle = (TGModernThemeEnabled() ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone); self.tableView.rowHeight = 60; self.accounts = [[NSUserDefaults standardUserDefaults] arrayForKey:@"TGAccounts"] ?: @[]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 2; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return section == 0 ? self.accounts.count : 1; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    TGGroupedCell *cell = [[TGClassicGroupedCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; NSInteger count = path.section == 0 ? self.accounts.count : 1; cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row == count - 1 ? 2 : 0); cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    if (path.section == 1) { cell.textLabel.text = @"Добавить аккаунт"; cell.textLabel.textColor = [UIColor colorWithRed:.2 green:.4 blue:.65 alpha:1]; }
    else { NSDictionary *account = self.accounts[path.row]; cell.textLabel.text = [account[@"title"] length] ? account[@"title"] : @"Аккаунт Telegram"; cell.detailTextLabel.text = account[@"phone"]; cell.accessoryType = [account[@"key"] isEqual:TGActiveAccountIdentifier()] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone; }
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    if (self.removingClient) return;
    NSString *identifier = path.section == 1 ? [[NSUUID UUID] UUIDString] : self.accounts[path.row][@"key"];
    if ([identifier isEqual:TGActiveAccountIdentifier()]) return;
    [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:@"TGActiveAccount"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TGSwitchAccountNotification" object:nil];
}
- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path { return path.section == 0 && !self.removingClient; }
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete || self.removingClient) return;
    self.removingIdentifier = self.accounts[path.row][@"key"];
    UIAlertView *alert = [[RT7AlertView alloc] initWithTitle:@"Выйти из аккаунта?" message:@"Сеанс на этом iPhone будет завершён. Для повторного входа потребуется код Telegram." delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Выйти", nil]; [alert show];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if (index != 1) { self.removingIdentifier = nil; return; }
    NSString *identifier = self.removingIdentifier; if (!identifier || self.removingClient) return;
    BOOL current = [identifier isEqual:self.client.accountIdentifier];
    TGClient *client = current ? self.client : [[TGClient alloc] initWithAccountIdentifier:identifier]; self.removingClient = client;
    void (^finish)(NSString *) = ^(NSString *error) {
        if (!current) [client suspendConnection]; self.removingClient = nil;
        if (error) { [[[RT7AlertView alloc] initWithTitle:@"Не удалось выйти" message:error delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show]; return; }
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; NSMutableArray *accounts = [[defaults arrayForKey:@"TGAccounts"] mutableCopy] ?: [NSMutableArray array];
        for (NSInteger i = (NSInteger)accounts.count - 1; i >= 0; i--) if ([accounts[i][@"key"] isEqual:identifier]) [accounts removeObjectAtIndex:i];
        [defaults setObject:accounts forKey:@"TGAccounts"]; self.accounts = accounts; [self.tableView reloadData];
        if (current) { [defaults setObject:accounts.count ? accounts[0][@"key"] : @"" forKey:@"TGActiveAccount"]; [[NSNotificationCenter defaultCenter] postNotificationName:@"TGSwitchAccountNotification" object:nil]; }
    };
    if (!client.hasSavedSession) { [client clearSavedSession]; finish(nil); return; }
    void (^logout)(void) = ^{ [client logOut:^(NSDictionary *result, NSString *error) { finish(error); }]; };
    if (current) logout(); else [client restoreSession:^(NSDictionary *result, NSString *error) { if (error) finish(error); else logout(); }];
}
@end
