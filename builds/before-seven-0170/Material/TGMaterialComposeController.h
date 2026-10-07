#import <UIKit/UIKit.h>
@class TGClient;
@interface TGMaterialComposeController : UIViewController
// -1: contacts tab, 0: new conversation, 1: group, 2: supergroup, 4: subscribers.
- (instancetype)initWithClient:(TGClient *)client kind:(NSInteger)kind;
@property(nonatomic,copy) void (^openedUser)(NSDictionary *user);
@property(nonatomic,copy) void (^createdChat)(NSDictionary *chat,NSString *title,BOOL channel);
@property(nonatomic,copy) void (^selectedUsers)(NSArray *users);
@end
