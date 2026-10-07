#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
#import "TGDialogFilterMatching.h"
@class TGClient;
@interface TGDialogFiltersController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client;
@property (nonatomic, copy) void (^selection)(NSDictionary *filter);
@end
