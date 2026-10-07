#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
@interface TGMessageToolsController : TGClassicTableController <UISearchBarDelegate>
@property (nonatomic, copy) void (^selection)(NSDictionary *message, NSDictionary *result);
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer topic:(int32_t)topic mode:(NSString *)mode;
@end
@interface TGScheduleMessageController : UIViewController
@property (nonatomic, copy) void (^selection)(int32_t date);
@end
