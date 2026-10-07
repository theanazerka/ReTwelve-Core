#import "TGViewController.h"
@interface TGTelegraphConversationProfileController : TGViewController
@property (nonatomic) bool createChat;
@property (nonatomic) NSInteger creationKind;
@property (nonatomic, copy) void (^createdChat)(NSDictionary *, NSString *, BOOL);
- (id)initWithCreateChat;
- (void)setCreateChatParticipants:(NSArray *)participants;
@end
