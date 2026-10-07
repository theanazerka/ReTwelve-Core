#import <UIKit/UIKit.h>
@interface RT27CardCell : UITableViewCell
@property(nonatomic,strong) UITableViewCell *innerCell;
@property(nonatomic) BOOL firstInCard,lastInCard;
@property(nonatomic) CGFloat cardSeparatorInset;
@end
