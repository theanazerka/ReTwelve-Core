/* Telegram for iOS v1.1, Copyright Peter Iakovlev, 2013.
 * Adapted for this client under GNU GPL v2 or later. */
#import <UIKit/UIKit.h>

@protocol TGConversationActionsPanelDelegate <NSObject>
- (void)conversationActionsPanelDidSelect:(NSString *)action;
@end

@interface TGConversationActionsPanel : UIView
@property (nonatomic, weak) id<TGConversationActionsPanelDelegate> delegate;
@property (nonatomic) BOOL isBeingShown;
@property (nonatomic) BOOL isMuted;
- (id)initWithFrame:(CGRect)frame;
- (void)show:(BOOL)animated;
- (void)hide:(BOOL)animated;
@end
