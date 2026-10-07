#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
@interface TGPollController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer message:(NSDictionary *)message;
@end
