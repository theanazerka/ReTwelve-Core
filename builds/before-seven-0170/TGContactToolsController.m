#import "Material/TGMaterialKit.h"
#import "TGTheme.h"
#import "TGContactToolsController.h"
#import "TGClient.h"
#import "TGFeatureForms.h"
#import "LegacyCompose/TGGroupedCell.h"
#import <AddressBook/AddressBook.h>
@interface TGContactToolsController () <UIAlertViewDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic) BOOL busy;
@property (nonatomic) NSUInteger imported;
@end
@implementation TGContactToolsController
- (instancetype)initWithClient:(TGClient *)client { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _client = client; self.title = @"Контакты"; self.hidesBottomBarWhenPushed = YES; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundView = nil; self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/SettingsBackground"]]; self.tableView.separatorStyle = (TGModernThemeEnabled() ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone); self.status = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, self.view.bounds.size.width - 40, 70)]; self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.status.backgroundColor = [UIColor clearColor]; self.status.textColor = TGMaterialSecondaryText(); self.status.textAlignment = NSTextAlignmentCenter; self.status.numberOfLines = 3; self.status.font = TGMaterialFont(14,NO); self.tableView.tableFooterView = self.status; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 2; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path { TGGroupedCell *cell = [[TGClassicGroupedCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; cell.groupedCellPosition = path.row ? 2 : 1; cell.textLabel.backgroundColor = [UIColor clearColor]; cell.textLabel.font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(16,YES); cell.textLabel.text = path.row ? @"Импортировать с iPhone" : @"Добавить контакт"; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell; }
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; if (self.busy) return;
    if (path.row) { [[[UIAlertView alloc] initWithTitle:@"Импорт контактов" message:@"Имена и номера из адресной книги будут отправлены в Telegram для поиска Ваших контактов." delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Импортировать", nil] show]; return; }
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Новый контакт" fields:@[@{@"key": @"first_name", @"title": @"Имя", @"required": @YES}, @{@"key": @"last_name", @"title": @"Фамилия"}, @{@"key": @"phone", @"title": @"Номер телефона", @"placeholder": @"+7…", @"type": @"phone", @"required": @YES}] values:nil save:^(NSDictionary *values, void (^completion)(NSString *)) {
        NSDictionary *contact = @{@"_": @"inputPhoneContact", @"client_id": @1, @"phone": values[@"phone"], @"first_name": values[@"first_name"], @"last_name": values[@"last_name"] ?: @""};
        [self.client performRequest:@{@"_": @"contacts.importContacts", @"contacts": @[contact]} completion:^(NSDictionary *result, NSString *error) { if (!error && [result[@"retry_contacts"] count]) error = @"Telegram попросил повторить импорт позже."; completion(error); if (!error) self.status.text = [result[@"imported"] count] ? @"Контакт добавлен в Telegram." : @"Номер сохранён. Пользователь пока не найден в Telegram."; }];
    }]; [self.navigationController pushViewController:form animated:YES];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if (index == alert.cancelButtonIndex) return; self.busy = YES; self.status.text = @"Читаем адресную книгу…";
    ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, NULL);
    if (!book) { self.busy = NO; self.status.text = @"Не удалось открыть адресную книгу."; return; }
    ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
        if (!granted) { CFRelease(book); dispatch_async(dispatch_get_main_queue(), ^{ self.busy = NO; self.status.text = @"Разрешите доступ к контактам в настройках iPhone."; }); return; }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSArray *people = CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(book)); NSMutableArray *contacts = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set]; int64_t identifier = 1;
            for (id person in people) { ABRecordRef record = (__bridge ABRecordRef)person; NSString *first = CFBridgingRelease(ABRecordCopyValue(record, kABPersonFirstNameProperty)) ?: @""; NSString *last = CFBridgingRelease(ABRecordCopyValue(record, kABPersonLastNameProperty)) ?: @""; ABMultiValueRef phones = ABRecordCopyValue(record, kABPersonPhoneProperty);
                if (phones) { for (CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) { NSString *phone = CFBridgingRelease(ABMultiValueCopyValueAtIndex(phones, i)); NSString *normalized = [[phone componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]] componentsJoinedByString:@""]; if (normalized.length < 5 || [seen containsObject:normalized]) continue; [seen addObject:normalized]; [contacts addObject:@{@"_": @"inputPhoneContact", @"client_id": @(identifier++), @"phone": normalized, @"first_name": first.length ? first : last.length ? last : normalized, @"last_name": first.length ? last : @""}]; } CFRelease(phones); }
            }
            CFRelease(book); dispatch_async(dispatch_get_main_queue(), ^{ self.contacts = contacts; self.imported = 0; [self importFrom:0]; });
        });
    });
}
- (void)importFrom:(NSUInteger)offset {
    if (offset >= self.contacts.count) { self.busy = NO; self.status.text = [NSString stringWithFormat:@"Импорт завершён. Найдено в Telegram: %lu.", (unsigned long)self.imported]; self.contacts = nil; return; }
    NSUInteger count = MIN(100, self.contacts.count - offset); self.status.text = [NSString stringWithFormat:@"Импорт контактов: %lu / %lu", (unsigned long)offset, (unsigned long)self.contacts.count];
    [self.client performRequest:@{@"_": @"contacts.importContacts", @"contacts": [self.contacts subarrayWithRange:NSMakeRange(offset, count)]} completion:^(NSDictionary *result, NSString *error) {
        if (error || [result[@"retry_contacts"] count]) { self.busy = NO; self.status.text = error ?: @"Telegram попросил повторить импорт позже."; self.contacts = nil; return; }
        self.imported += [result[@"imported"] count]; [self importFrom:offset + count];
    }];
}
@end

UIViewController *TGNewContactForm(TGClient *client) {
    return [[TGFeatureFormController alloc] initWithTitle:@"Новый контакт" fields:@[@{@"key":@"first_name",@"title":@"Имя",@"required":@YES},@{@"key":@"last_name",@"title":@"Фамилия"},@{@"key":@"phone",@"title":@"Номер телефона",@"type":@"phone",@"placeholder":@"+7…",@"required":@YES}] values:nil save:^(NSDictionary *values,void (^completion)(NSString *)) {
        NSDictionary *contact=@{@"_":@"inputPhoneContact",@"client_id":@1,@"phone":values[@"phone"],@"first_name":values[@"first_name"],@"last_name":values[@"last_name"] ?: @""};
        [client performRequest:@{@"_":@"contacts.importContacts",@"contacts":@[contact]} completion:^(NSDictionary *result,NSString *error) {
            if(!error && [result[@"retry_contacts"] count]) error=@"Telegram попросил повторить импорт позже.";
            completion(error);
            if(!error) [[NSNotificationCenter defaultCenter] postNotificationName:@"RT27ContactsChanged" object:client];
        }];
    }];
}
