#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
@interface TGCustomEmojiController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client;
@property (nonatomic, copy) void (^selection)(NSDictionary *document);
@end
