#import "RT27Compat.h"
@protocol RT27TabBarDelegate <NSObject>

- (void)tabBarSelectedItem:(int)index;

@end

@interface RT27TabBar : UIView

@property (nonatomic, weak) id<RT27TabBarDelegate> tabDelegate;

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *stripeView;

@property (nonatomic, strong) NSMutableArray *buttonViews;
@property (nonatomic, strong) NSMutableArray *labelViews;

@property (nonatomic, strong) UIView *unreadBadgeContainer;
@property (nonatomic, strong) UIImageView *unreadBadgeBackground;
@property (nonatomic, strong) UILabel *unreadBadgeLabel;

@property (nonatomic) int selectedIndex;
- (void)setUnreadCount:(int)unreadCount;

@end

