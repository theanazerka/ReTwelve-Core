#import "../Seven/RT7UIKit.h"
#import <UIKit/UIKit.h>
@interface RT27CardCell : RT7ListCell
@property(nonatomic,strong) UITableViewCell *innerCell;
@property(nonatomic) BOOL firstInCard,lastInCard;
@property(nonatomic) CGFloat cardSeparatorInset;
@end
