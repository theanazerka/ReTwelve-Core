#import "TGLegacyUICompat.h"
// A channel-specific wizard built with the ported Telegram 1 UI components.
@interface TGChannelCreationController : TGViewController
@property (nonatomic, copy) void (^createdChat)(NSDictionary *,NSString *,BOOL);
@end
