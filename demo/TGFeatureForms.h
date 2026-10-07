#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
typedef void (^TGFormSave)(NSDictionary *values, void (^completion)(NSString *error));
@interface TGFeatureFormController : TGClassicTableController
- (instancetype)initWithTitle:(NSString *)title fields:(NSArray *)fields values:(NSDictionary *)values save:(TGFormSave)save;
@property (nonatomic, copy) NSString *explanation;
@end
@interface TGPrivacyController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client;
@end
@interface TGStorageController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client;
@end
TGFeatureFormController *TGProxyForm(TGClient *client);

TGFeatureFormController *TGTwoStepPasswordForm(TGClient *client);
TGFeatureFormController *TGProfileForm(TGClient *client, NSDictionary *user, NSDictionary *fullProfile);
