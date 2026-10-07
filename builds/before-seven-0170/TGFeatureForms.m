#import "Material/TGMaterialKit.h"
#import "TGFlatKit.h"
#import "TGTheme.h"
#import "TGClassicTableController.h"
#import "TGFeatureForms.h"
#import "TGClient.h"
#import "LegacyCompose/TGGroupedCell.h"
static void TGFeatureTable(UITableView *table) { table.backgroundView = nil; table.backgroundColor = TGModernThemeEnabled() ? TGModernCanvas() : [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/SettingsBackground"]]; table.separatorStyle = UITableViewCellSeparatorStyleNone; }
static TGGroupedCell *TGFeatureCell(UITableView *table, NSInteger row, NSInteger count, UITableViewCellStyle style) {
    TGGroupedCell *cell = [[TGClassicGroupedCell alloc] initWithStyle:style reuseIdentifier:nil]; cell.groupedCellPosition = (row == 0 ? TGGroupedCellPositionFirst : 0) | (row == count - 1 ? TGGroupedCellPositionLast : 0); cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor]; return cell;
}
// Lay out controls inside the actual grouped cell, whose width varies by OS and screen.
@interface TGFeatureInputCell : TGClassicGroupedCell
@property (nonatomic, strong) UILabel *caption;
@property (nonatomic, strong) UIView *input;
@end
@implementation TGFeatureInputCell
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width;
    CGFloat inset = self.cardInset+16;
    self.caption.frame = CGRectMake(inset, 7, MAX(0, width - inset * 2), 18);
    BOOL multiline = [self.input isKindOfClass:[UITextView class]];
    CGFloat inputInset = multiline ? inset - 5 : inset;
    self.input.frame = CGRectMake(inputInset, 27, MAX(0, width - inputInset * 2), MAX(0, self.contentView.bounds.size.height - 33));
}
@end

@interface TGFeatureFormController () <UITextFieldDelegate, UITextViewDelegate>
@property (nonatomic, strong) NSArray *fields;
@property (nonatomic, strong) NSMutableDictionary *values;
@property (nonatomic, copy) TGFormSave saveHandler;
@property (nonatomic) BOOL busy;
@end
@implementation TGFeatureFormController
- (instancetype)initWithTitle:(NSString *)title fields:(NSArray *)fields values:(NSDictionary *)values save:(TGFormSave)save {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) { self.title = title; _fields = fields; _values = [values mutableCopy] ?: [NSMutableDictionary dictionary]; _saveHandler = [save copy]; self.hidesBottomBarWhenPushed = YES; } return self;
}
- (void)viewDidLoad { [super viewDidLoad]; TGFeatureTable(self.tableView); self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово" style:UIBarButtonItemStyleDone target:self action:@selector(save)]; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.fields.count; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *spec = self.fields[path.row];
    if ([spec[@"type"] isEqual:@"multiline"]) return 112;
    if (![spec[@"type"] isEqual:@"switch"]) return 62;
    CGFloat width = MAX(80, table.bounds.size.width - (TGModernThemeEnabled() ? 120 : 140));
    UIFont *font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(15,YES);
    CGFloat textHeight = [spec[@"title"] sizeWithFont:font constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height;
    return MAX(TGModernThemeEnabled() ? 48 : 46, ceil(textHeight) + 20);
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section { return self.explanation; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *spec = self.fields[path.row]; NSString *key = spec[@"key"], *type = spec[@"type"];
    TGFeatureInputCell *cell = [[TGFeatureInputCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.groupedCellPosition = (path.row == 0 ? TGGroupedCellPositionFirst : 0) | (path.row == self.fields.count - 1 ? TGGroupedCellPositionLast : 0);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if ([type isEqual:@"switch"]) {
        cell.textLabel.text = spec[@"title"]; cell.textLabel.font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(15,YES); cell.textLabel.numberOfLines = 0;
        UISwitch *toggle = [[TGSwitchClass() alloc] init]; toggle.tag = path.row; toggle.on = [self.values[key] boolValue]; [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle;
    } else {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero]; label.autoresizingMask = UIViewAutoresizingFlexibleWidth; label.backgroundColor = [UIColor clearColor]; label.font = TGModernThemeEnabled() ? TGMaterialFont(13,NO) : TGMaterialFont(13,YES); label.textColor = TGModernThemeEnabled() ? TGModernSecondaryText() : [UIColor colorWithRed:.3 green:.4 blue:.52 alpha:1]; label.text = spec[@"title"]; cell.caption = label; [cell.contentView addSubview:label];
        if ([type isEqual:@"multiline"]) {
            UITextView *input = [[UITextView alloc] initWithFrame:CGRectZero]; input.autoresizingMask = UIViewAutoresizingFlexibleWidth; input.font = TGMaterialFont(16,NO); input.backgroundColor = [UIColor clearColor]; input.text = self.values[key] ?: @""; input.tag = path.row; input.delegate = self; cell.input = input; [cell.contentView addSubview:input];
        } else {
            UITextField *input = [[TGTextFieldClass() alloc] initWithFrame:CGRectZero]; input.autoresizingMask = UIViewAutoresizingFlexibleWidth; input.font = TGMaterialFont(17,NO); input.text = self.values[key] ?: @""; input.placeholder = spec[@"placeholder"]; input.tag = path.row; input.delegate = self; input.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter; input.clearButtonMode = UITextFieldViewModeWhileEditing; input.returnKeyType = UIReturnKeyDone; input.autocapitalizationType = UITextAutocapitalizationTypeNone; input.autocorrectionType = UITextAutocorrectionTypeNo; input.secureTextEntry = [type isEqual:@"password"]; input.keyboardType = [type isEqual:@"number"] ? UIKeyboardTypeNumbersAndPunctuation : [type isEqual:@"phone"] ? UIKeyboardTypePhonePad : [type isEqual:@"email"] ? UIKeyboardTypeEmailAddress : UIKeyboardTypeDefault; [input addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged]; cell.input = input; [cell.contentView addSubview:input];
        }
    } return cell;
}
- (void)fieldChanged:(UITextField *)field { self.values[self.fields[field.tag][@"key"]] = field.text ?: @""; }
- (void)textViewDidChange:(UITextView *)view { self.values[self.fields[view.tag][@"key"]] = view.text ?: @""; }
- (void)toggleChanged:(UISwitch *)toggle { self.values[self.fields[toggle.tag][@"key"]] = @(toggle.on); }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (void)save {
    if (self.busy || !self.saveHandler) return; [self.view endEditing:YES];
    for (NSDictionary *spec in self.fields) if ([spec[@"required"] boolValue] && ![self.values[spec[@"key"]] length]) { [[[UIAlertView alloc] initWithTitle:spec[@"title"] message:@"Заполните это поле." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; return; }
    self.busy = YES; self.navigationItem.rightBarButtonItem.enabled = NO;
    __weak TGFeatureFormController *weakSelf = self;
    self.saveHandler([self.values copy], ^(NSString *error) { dispatch_async(dispatch_get_main_queue(), ^{ TGFeatureFormController *view = weakSelf; if (!view) return; view.busy = NO; view.navigationItem.rightBarButtonItem.enabled = YES; if (error) [[[UIAlertView alloc] initWithTitle:@"Не удалось сохранить" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; else [view.navigationController popViewControllerAnimated:YES]; }); });
}
@end

@interface TGPrivacyChoiceController : TGClassicTableController
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSDictionary *result;
@property (nonatomic) NSInteger selected;
@property (nonatomic) BOOL busy;
@end
@implementation TGPrivacyChoiceController
- (void)viewDidLoad { [super viewDidLoad]; TGFeatureTable(self.tableView); self.selected = -1; self.busy = YES;
    [self.client performRequest:@{ @"_": @"account.getPrivacy", @"key": @{ @"_": self.key } } completion:^(NSDictionary *result, NSString *error) { self.busy = NO; self.result = result; for (NSDictionary *rule in result[@"rules"]) { if ([rule[@"_"] isEqual:@"privacyValueAllowAll"]) self.selected = 0; else if ([rule[@"_"] isEqual:@"privacyValueAllowContacts"]) self.selected = 1; else if ([rule[@"_"] isEqual:@"privacyValueDisallowAll"] && self.selected < 0) self.selected = 2; } if (error) [[[UIAlertView alloc] initWithTitle:@"Конфиденциальность" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; [self.tableView reloadData]; }];
}
- (NSInteger)tableView:(UITableView *)view numberOfRowsInSection:(NSInteger)section { return 3; }
- (NSString *)tableView:(UITableView *)view titleForFooterInSection:(NSInteger)section { return self.busy ? @"Загрузка…" : @"Существующие индивидуальные исключения сохраняются."; }
- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)path { TGGroupedCell *cell = TGFeatureCell(view, path.row, 3, UITableViewCellStyleDefault); cell.textLabel.text = @[@"Все", @"Мои контакты", @"Никто"][path.row]; cell.accessoryType = self.selected == path.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone; return cell; }
- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)path {
    [view deselectRowAtIndexPath:path animated:YES]; if (self.busy || !self.result) return;
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *rule in self.result[@"rules"]) {
        NSString *type = rule[@"_"]; if ([type isEqual:@"privacyValueAllowAll"] || [type isEqual:@"privacyValueAllowContacts"] || [type isEqual:@"privacyValueDisallowAll"]) continue;
        NSMutableDictionary *input = [rule mutableCopy]; input[@"_"] = [@"input" stringByAppendingString:[type stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@"P"]];
        if (rule[@"users"]) { NSMutableArray *users = [NSMutableArray array]; for (NSNumber *identifier in rule[@"users"]) for (NSDictionary *user in self.result[@"users"]) if ([identifier isEqual:user[@"id"]] && user[@"access_hash"]) [users addObject:@{ @"_": @"inputUser", @"user_id": identifier, @"access_hash": user[@"access_hash"] }]; if (users.count != [rule[@"users"] count]) { [[[UIAlertView alloc] initWithTitle:@"Не удалось сохранить" message:@"Не удалось получить пользователей из исключений. Повторите позже." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; return; } input[@"users"] = users; }
        [input removeObjectForKey:@"flags"]; [rules addObject:input];
    }
    [rules addObject:@{ @"_": @[@"inputPrivacyValueAllowAll", @"inputPrivacyValueAllowContacts", @"inputPrivacyValueDisallowAll"][path.row] }];
    self.busy = YES; [self.client performRequest:@{ @"_": @"account.setPrivacy", @"key": @{ @"_": self.key }, @"rules": rules } completion:^(NSDictionary *result, NSString *error) { self.busy = NO; if (error) [[[UIAlertView alloc] initWithTitle:@"Не удалось сохранить" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; else { self.result = result; self.selected = path.row; } [self.tableView reloadData]; }];
}
@end
@interface TGPrivacyController ()
@property (nonatomic, strong) TGClient *client;
@end
@implementation TGPrivacyController
- (instancetype)initWithClient:(TGClient *)client { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _client = client; self.title = @"Конфиденциальность"; self.hidesBottomBarWhenPushed = YES; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; TGFeatureTable(self.tableView); }
- (NSInteger)tableView:(UITableView *)view numberOfRowsInSection:(NSInteger)section { return 7; }
- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)path { TGGroupedCell *cell = TGFeatureCell(view, path.row, 7, UITableViewCellStyleDefault); cell.textLabel.text = @[@"Номер телефона", @"Последняя активность", @"Фотография профиля", @"Пересылка сообщений", @"Приглашения в группы", @"О себе", @"Музыка профиля"][path.row]; cell.textLabel.font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(16,YES); cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell; }
- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)path { TGPrivacyChoiceController *choice = [[TGPrivacyChoiceController alloc] initWithStyle:UITableViewStyleGrouped]; choice.client = self.client; choice.title = [view cellForRowAtIndexPath:path].textLabel.text; choice.key = @[@"inputPrivacyKeyPhoneNumber", @"inputPrivacyKeyStatusTimestamp", @"inputPrivacyKeyProfilePhoto", @"inputPrivacyKeyForwards", @"inputPrivacyKeyChatInvite", @"inputPrivacyKeyAbout", @"inputPrivacyKeySavedMusic"][path.row]; [self.navigationController pushViewController:choice animated:YES]; }
@end

@interface TGStorageController () <UIActionSheetDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *sizes;
@end
@implementation TGStorageController
- (instancetype)initWithClient:(TGClient *)client { if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _client = client; self.title = @"Хранилище"; self.hidesBottomBarWhenPushed = YES; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; TGFeatureTable(self.tableView); [self refresh]; }
- (void)refresh { [self.client mediaCacheSizes:^(NSDictionary *sizes) { self.sizes = sizes; [self.tableView reloadData]; }]; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 3; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section { return @"Очищаются только локальные копии. Сообщения, черновики и файлы в Telegram сохраняются. Музыку этот экран не очищает."; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path { TGGroupedCell *cell = TGFeatureCell(table, path.row, 3, UITableViewCellStyleValue1); cell.textLabel.text = @[@"Фотографии и аватары", @"Стикеры", @"Видео"][path.row]; double size = [self.sizes[@[@"photos", @"stickers", @"videos"][path.row]] doubleValue] / (1024 * 1024); cell.detailTextLabel.text = self.sizes ? [NSString stringWithFormat:@"%.1f МБ", size] : @"…"; cell.textLabel.font = TGMaterialFont(15,YES); return cell; }
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { [table deselectRowAtIndexPath:path animated:YES]; UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Очистить локальные копии?" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Очистить" otherButtonTitles:nil]; sheet.tag = path.row; [sheet showInView:self.view]; }
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index { if (index == sheet.destructiveButtonIndex) [self.client clearMediaCacheKind:@[@"photos", @"stickers", @"videos"][sheet.tag] completion:^{ [self refresh]; }]; }
@end
TGFeatureFormController *TGProxyForm(TGClient *client) {
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Прокси" fields:@[
        @{ @"key": @"enabled", @"title": @"Использовать прокси", @"type": @"switch" },
        @{ @"key": @"host", @"title": @"Сервер", @"placeholder": @"Адрес сервера" },
        @{ @"key": @"port", @"title": @"Порт", @"type": @"number", @"placeholder": @"1080" },
        @{ @"key": @"username", @"title": @"Имя пользователя SOCKS5" },
        @{ @"key": @"password", @"title": @"Пароль SOCKS5", @"type": @"password" },
        @{ @"key": @"secret", @"title": @"Секрет MTProto", @"type": @"password" }
    ] values:[client savedProxySettings] save:^(NSDictionary *values, void (^completion)(NSString *)) { completion([client updateProxySettings:values]); }];
    form.explanation = @"Для SOCKS5 оставьте секрет пустым. Для MTProto укажите секрет из ссылки прокси."; return form;
}

TGFeatureFormController *TGTwoStepPasswordForm(TGClient *client) {
    __block __weak TGFeatureFormController *weakForm;
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Облачный пароль" fields:@[
        @{ @"key": @"old", @"title": @"Текущий пароль", @"type": @"password", @"placeholder": @"Если пароль уже установлен" },
        @{ @"key": @"remove", @"title": @"Отключить облачный пароль", @"type": @"switch" },
        @{ @"key": @"new", @"title": @"Новый пароль", @"type": @"password" },
        @{ @"key": @"confirm", @"title": @"Повторите новый пароль", @"type": @"password" },
        @{ @"key": @"hint", @"title": @"Подсказка" },
        @{ @"key": @"email", @"title": @"Почта для восстановления", @"type": @"email" }
    ] values:nil save:^(NSDictionary *values, void (^completion)(NSString *)) {
        BOOL removing = [values[@"remove"] boolValue];
        if (removing && ![values[@"old"] length]) { completion(@"Для отключения введите текущий облачный пароль."); return; }
        if (!removing && ![values[@"new"] length]) { completion(@"Введите новый пароль."); return; }
        if (!removing && ![values[@"new"] isEqual:values[@"confirm"]]) { completion(@"Новые пароли не совпадают."); return; }
        if (!removing && [values[@"hint"] isEqual:values[@"new"]]) { completion(@"Подсказка не должна совпадать с паролем."); return; }
        [client updateTwoStepPassword:values[@"old"] ?: @"" newPassword:removing ? @"" : values[@"new"] hint:values[@"hint"] email:values[@"email"] completion:^(NSDictionary *result, NSString *error) {
            if (![error hasPrefix:@"EMAIL_UNCONFIRMED"]) { completion(error); return; }
            UINavigationController *navigation = weakForm.navigationController;
            TGFeatureFormController *confirmation = [[TGFeatureFormController alloc] initWithTitle:@"Подтвердите почту" fields:@[@{@"key": @"code", @"title": @"Код из письма", @"type": @"number", @"required": @YES}] values:nil save:^(NSDictionary *input, void (^finish)(NSString *)) {
                [client performRequest:@{@"_": @"account.confirmPasswordEmail", @"code": input[@"code"]} completion:^(NSDictionary *response, NSString *issue) { finish(issue); }];
            }]; confirmation.explanation = @"Пароль уже установлен. Введите код, отправленный на указанную почту.";
            completion(nil); dispatch_async(dispatch_get_main_queue(), ^{ [navigation pushViewController:confirmation animated:YES]; });
        }];
    }]; weakForm = form; form.explanation = @"Этот пароль защищает вход в аккаунт на новых устройствах. Оставьте текущий пароль пустым, если он ещё не установлен."; return form;
}

TGFeatureFormController *TGProfileForm(TGClient *client, NSDictionary *user, NSDictionary *fullProfile) {
    NSDictionary *birthday = fullProfile[@"birthday"];
    NSString *date = birthday[@"day"] ? [NSString stringWithFormat:@"%@.%@%@", birthday[@"day"], birthday[@"month"], birthday[@"year"] ? [@"." stringByAppendingString:[birthday[@"year"] stringValue]] : @""] : @"";
    NSDictionary *original = @{@"first": user[@"first_name"] ?: @"", @"last": user[@"last_name"] ?: @"", @"username": user[@"username"] ?: @"", @"about": fullProfile[@"about"] ?: @"", @"birthday": date};
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Мой профиль" fields:@[
        @{@"key": @"first", @"title": @"Имя", @"required": @YES},
        @{@"key": @"last", @"title": @"Фамилия"},
        @{@"key": @"username", @"title": @"Имя пользователя", @"placeholder": @"Без @"},
        @{@"key": @"about", @"title": @"О себе", @"type": @"multiline"},
        @{@"key": @"birthday", @"title": @"День рождения", @"placeholder": @"ДД.ММ или ДД.ММ.ГГГГ", @"type": @"number"}
    ] values:original save:^(NSDictionary *values, void (^completion)(NSString *)) {
        NSString *first = [values[@"first"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *username = values[@"username"] ?: @"";
        if (!first.length || first.length > 64 || [values[@"last"] length] > 64) { completion(@"Имя и фамилия должны содержать не больше 64 символов. Имя обязательно."); return; }
        NSCharacterSet *letters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
        if (username.length && (username.length < 5 || username.length > 32 || [username rangeOfCharacterFromSet:letters.invertedSet].location != NSNotFound)) { completion(@"Имя пользователя: от 5 до 32 латинских букв, цифр или подчёркиваний."); return; }
        NSString *dateText = values[@"birthday"] ?: @""; NSMutableDictionary *newBirthday = nil;
        if (dateText.length) {
            NSArray *parts = [dateText componentsSeparatedByString:@"."]; BOOL valid = parts.count == 2 || parts.count == 3;
            for (NSString *part in parts) if (!part.length || [part rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location != NSNotFound) valid = NO;
            NSInteger day = valid ? [parts[0] integerValue] : 0, month = valid ? [parts[1] integerValue] : 0, year = valid && parts.count == 3 ? [parts[2] integerValue] : 2000;
            NSDateComponents *components = [[NSDateComponents alloc] init]; components.day = day; components.month = month; components.year = year;
            NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar]; NSDate *parsed = [calendar dateFromComponents:components];
            NSDateComponents *actual = parsed ? [calendar components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:parsed] : nil;
            NSInteger currentYear = [[calendar components:NSYearCalendarUnit fromDate:[NSDate date]] year];
            if (!valid || year < 1900 || (parts.count == 3 && year > currentYear) || actual.day != day || actual.month != month || actual.year != year) { completion(@"Укажите существующую дату: ДД.ММ или ДД.ММ.ГГГГ."); return; }
            newBirthday = [@{@"_": @"birthday", @"day": @(day), @"month": @(month)} mutableCopy]; if (parts.count == 3) newBirthday[@"year"] = @(year);
        }
        void (^saveBirthday)(void) = ^{
            if ([dateText isEqual:original[@"birthday"]]) { completion(nil); return; }
            NSMutableDictionary *request = [@{@"_": @"account.updateBirthday"} mutableCopy]; if (newBirthday) request[@"birthday"] = newBirthday;
            [client performRequest:request completion:^(NSDictionary *result, NSString *error) { completion(error); }];
        };
        void (^saveUsername)(void) = ^{
            if ([username isEqual:original[@"username"]]) { saveBirthday(); return; }
            [client performRequest:@{@"_": @"account.updateUsername", @"username": username} completion:^(NSDictionary *result, NSString *error) { if (error && ![error isEqual:@"USERNAME_NOT_MODIFIED"]) completion(error); else saveBirthday(); }];
        };
        [client performRequest:@{@"_": @"account.updateProfile", @"first_name": first, @"last_name": values[@"last"] ?: @"", @"about": values[@"about"] ?: @""} completion:^(NSDictionary *result, NSString *error) { if (error) completion(error); else saveUsername(); }];
    }]; form.explanation = @"Год рождения можно не указывать. Очистите дату, чтобы убрать её из профиля. Фото меняется на предыдущем экране."; return form;
}
