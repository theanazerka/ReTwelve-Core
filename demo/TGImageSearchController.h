#import "Seven/RT7UIKit.h"
#import <UIKit/UIKit.h>

@class TGClient;

@interface TGImageSearchController : RT7TableController <UISearchBarDelegate>
@property (nonatomic) BOOL gifMode;
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer topicId:(int32_t)topicId
                     sent:(void (^)(void))sent;
@end
