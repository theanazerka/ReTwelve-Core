#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;

@interface TGDevicesController : TGClassicTableController <UIAlertViewDelegate, UIActionSheetDelegate>
- (instancetype)initWithClient:(TGClient *)client;
@end
