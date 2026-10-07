#import "TGFlatKit.h"
#import "TGTheme.h"
#import "TGLocalPasscode.h"
#import "TGFeatureForms.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonCryptoError.h>
static NSMutableDictionary *TGPasscodeQuery(void) { return [@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrService: @"com.anazerka.telegramcodedemo.localpasscode", (__bridge id)kSecAttrAccount: @"lock"} mutableCopy]; }
static NSDictionary *TGPasscodeRead(void) {
    NSMutableDictionary *query = TGPasscodeQuery(); query[(__bridge id)kSecReturnData] = @YES; query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne; CFTypeRef value = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &value) != errSecSuccess) return nil;
    NSData *data = CFBridgingRelease(value); return [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
}
BOOL TGLocalPasscodeEnabled(void) { return TGPasscodeRead() != nil; }
static NSData *TGPasscodeHash(NSString *password, NSData *salt) { NSData *input = [password dataUsingEncoding:NSUTF8StringEncoding]; unsigned char hash[32]; if (CCKeyDerivationPBKDF(kCCPBKDF2, input.bytes, input.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA256, 60000, hash, sizeof(hash)) != kCCSuccess) return nil; return [NSData dataWithBytes:hash length:sizeof(hash)]; }
static BOOL TGPasscodeEqual(NSData *left, NSData *right) { if (left.length != 32 || right.length != 32) return NO; const unsigned char *a = left.bytes, *b = right.bytes; unsigned char different = 0; for (NSUInteger i = 0; i < 32; i++) different |= a[i] ^ b[i]; return different == 0; }
static BOOL TGPasscodeCheck(NSString *password, NSDictionary *stored) { return TGPasscodeEqual(TGPasscodeHash(password, stored[@"salt"]), stored[@"hash"]); }
UIViewController *TGLocalPasscodeSettings(void) {
    BOOL enabled = TGLocalPasscodeEnabled();
    NSMutableArray *fields = [NSMutableArray array]; if (enabled) [fields addObject:@{@"key": @"old", @"title": @"Текущий код", @"type": @"password", @"required": @YES}];
    [fields addObject:@{@"key": @"new", @"title": @"Новый код", @"type": @"password"}]; [fields addObject:@{@"key": @"confirm", @"title": @"Повторите код", @"type": @"password"}];
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Код-пароль" fields:fields values:nil save:^(NSDictionary *values, void (^completion)(NSString *)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSDictionary *stored = TGPasscodeRead(); NSString *error = nil;
            if (stored && !TGPasscodeCheck(values[@"old"] ?: @"", stored)) error = @"Неверный текущий код.";
            NSString *password = values[@"new"] ?: @"";
            if (!error && ![password isEqual:values[@"confirm"] ?: @""]) error = @"Коды не совпадают.";
            if (!error && password.length && password.length < 4) error = @"Используйте не меньше четырёх символов.";
            if (!error) {
                if (!password.length) { OSStatus status = SecItemDelete((__bridge CFDictionaryRef)TGPasscodeQuery()); if (status != errSecSuccess && status != errSecItemNotFound) error = @"Не удалось отключить код в связке ключей."; }
                else { unsigned char bytes[32]; if (SecRandomCopyBytes(kSecRandomDefault, sizeof(bytes), bytes) != errSecSuccess) error = @"Не удалось создать код.";
                    else { NSData *salt = [NSData dataWithBytes:bytes length:sizeof(bytes)]; NSData *hash = TGPasscodeHash(password, salt); NSData *data = hash ? [NSPropertyListSerialization dataWithPropertyList:@{@"salt": salt, @"hash": hash} format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] : nil;
                        if (!data) error = @"Не удалось сохранить код.";
                        else { NSDictionary *attributes = @{(__bridge id)kSecValueData: data, (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly}; OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)TGPasscodeQuery(), (__bridge CFDictionaryRef)attributes);
                            if (status == errSecItemNotFound) { NSMutableDictionary *query = TGPasscodeQuery(); [query addEntriesFromDictionary:attributes]; status = SecItemAdd((__bridge CFDictionaryRef)query, NULL); }
                            if (status != errSecSuccess) error = @"Не удалось сохранить код в связке ключей.";
                        }
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{ if (!error) { [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TGLockFailures"]; [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TGLockRetryAfter"]; [[NSNotificationCenter defaultCenter] postNotificationName:@"TGLocalPasscodeChanged" object:nil]; } completion(error); });
        });
    }]; form.explanation = enabled ? @"Оставьте новый код и подтверждение пустыми, чтобы отключить блокировку. Код защищает все аккаунты в этом приложении." : @"Код запрашивается при открытии приложения. Он хранится в связке ключей и не отправляется в Telegram."; return form;
}
@interface TGLocalPasscodeGate () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *input;
@property (nonatomic, strong) UILabel *hint, *titleLabel;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic) BOOL busy;
@end
@implementation TGLocalPasscodeGate
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/DarkLinen"]];
    self.titleLabel = [[UILabel alloc] init]; self.titleLabel.text = @"Telegram"; self.titleLabel.font = [UIFont boldSystemFontOfSize:28]; self.titleLabel.textColor = TGModernThemeEnabled() ? [UIColor blackColor] : [UIColor whiteColor]; self.titleLabel.backgroundColor = [UIColor clearColor]; self.titleLabel.textAlignment = NSTextAlignmentCenter; [self.view addSubview:self.titleLabel];
    self.input = [[TGTextFieldClass() alloc] init]; self.input.borderStyle = UITextBorderStyleRoundedRect; self.input.font = [UIFont systemFontOfSize:22]; self.input.textAlignment = NSTextAlignmentCenter; self.input.secureTextEntry = YES; self.input.placeholder = @"Код-пароль"; self.input.autocorrectionType = UITextAutocorrectionTypeNo; self.input.autocapitalizationType = UITextAutocapitalizationTypeNone; self.input.delegate = self; self.input.returnKeyType = UIReturnKeyDone; [self.view addSubview:self.input];
    self.hint = [[UILabel alloc] init]; self.hint.text = @"Введите код для разблокировки"; self.hint.font = [UIFont systemFontOfSize:14]; self.hint.textColor = TGModernThemeEnabled() ? TGModernSecondaryText() : [UIColor whiteColor]; self.hint.backgroundColor = [UIColor clearColor]; self.hint.textAlignment = NSTextAlignmentCenter; self.hint.numberOfLines = 2; [self.view addSubview:self.hint];
    self.button = [UIButton buttonWithType:UIButtonTypeRoundedRect]; [self.button setTitle:@"Разблокировать" forState:UIControlStateNormal]; [self.button addTarget:self action:@selector(unlock) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.button];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; CGFloat width = MIN(300, self.view.bounds.size.width - 40), x = (self.view.bounds.size.width - width) / 2; self.titleLabel.frame = CGRectMake(x, 42, width, 42); self.hint.frame = CGRectMake(x, 92, width, 40); self.input.frame = CGRectMake(x, 142, width, 42); self.button.frame = CGRectMake(x, 195, width, 40); }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self.input becomeFirstResponder]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [self unlock]; return NO; }
- (void)unlock {
    if (self.busy) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; NSTimeInterval wait = [defaults doubleForKey:@"TGLockRetryAfter"] - [NSDate timeIntervalSinceReferenceDate];
    if (wait > 0) { self.hint.text = [NSString stringWithFormat:@"Повторите через %.0f сек.", ceil(wait)]; return; }
    self.busy = YES; self.button.enabled = NO; NSString *password = self.input.text ?: @""; NSDictionary *stored = TGPasscodeRead();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL correct = !stored || TGPasscodeCheck(password, stored);
        dispatch_async(dispatch_get_main_queue(), ^{ self.busy = NO; self.button.enabled = YES;
            if (correct) { [defaults removeObjectForKey:@"TGLockFailures"]; [defaults removeObjectForKey:@"TGLockRetryAfter"]; [self.input resignFirstResponder]; if (self.unlocked) self.unlocked(); }
            else { NSInteger failures = [defaults integerForKey:@"TGLockFailures"] + 1; [defaults setInteger:failures forKey:@"TGLockFailures"]; if (failures >= 5) [defaults setDouble:[NSDate timeIntervalSinceReferenceDate] + 30 forKey:@"TGLockRetryAfter"]; self.input.text = @""; self.hint.text = failures >= 5 ? @"Слишком много попыток. Подождите 30 сек." : @"Неверный код. Попробуйте ещё раз."; }
        });
    });
}
@end
