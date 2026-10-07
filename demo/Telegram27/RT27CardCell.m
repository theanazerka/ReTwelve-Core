#import "RT27CardCell.h"
#import "../Seven/RT7UIKit.h"
@implementation RT27CardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if((self=[super initWithStyle:style reuseIdentifier:identifier])) { self.cardInset=0; self.backgroundColor=RT7Surface(); self.selectionStyle=UITableViewCellSelectionStyleNone; self.lastInGroup=YES; }
    return self;
}
- (void)setInnerCell:(UITableViewCell *)cell { if(_innerCell==cell)return; [_innerCell removeFromSuperview]; _innerCell=cell; cell.userInteractionEnabled=NO; [self.contentView addSubview:cell]; [self setNeedsLayout]; }
- (void)layoutSubviews { [super layoutSubviews]; _innerCell.frame=self.contentView.bounds; }
@end
