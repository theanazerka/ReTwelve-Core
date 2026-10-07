#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
@interface TGAccountsController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client;
@end
NSString *TGActiveAccountIdentifier(void);
void TGRememberAccount(NSString *identifier, NSDictionary *user);
