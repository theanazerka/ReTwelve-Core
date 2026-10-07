#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
@interface TGGroupManagementController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity;
@end
