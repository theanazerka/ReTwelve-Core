#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
@interface TGContactToolsController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client;
@end

#ifdef __cplusplus
extern "C" {
#endif
UIViewController *TGNewContactForm(TGClient *client);
#ifdef __cplusplus
}
#endif
