#import "RT27CardCell.h"
#import "../TGTheme.h"
// Cover only the pixels outside each rounded corner. A mask on the whole row
// forces offscreen rendering while the containing sheet is moving.
static UIImage *RT27CardCornerImage(NSUInteger corner) {
    static NSArray *images;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        NSMutableArray *corners=[NSMutableArray arrayWithCapacity:4];
        for(NSUInteger index=0; index<4; index++) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(20,20),NO,0);
            [TGModernCanvas() setFill]; UIRectFill(CGRectMake(0,0,20,20));
            CGContextRef context=UIGraphicsGetCurrentContext();
            CGContextSetBlendMode(context,kCGBlendModeClear);
            CGContextFillEllipseInRect(context,CGRectMake((index&1) ? -20 : 0,(index&2) ? -20 : 0,40,40));
            [corners addObject:UIGraphicsGetImageFromCurrentImageContext()];
            UIGraphicsEndImageContext();
        }
        images=[corners copy];
    });
    return images[corner];
}
@interface RT27CardCell ()
@property(nonatomic,strong) UIView *card;
@property(nonatomic,strong) UIView *stripe;
@property(nonatomic,strong) NSArray *corners;
@end
@implementation RT27CardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    self=[super initWithStyle:style reuseIdentifier:identifier];
    if(self) { self.backgroundColor=[UIColor clearColor]; self.backgroundView=nil; self.selectedBackgroundView=nil; self.selectionStyle=UITableViewCellSelectionStyleNone;
        _card=[[UIView alloc] init]; _card.backgroundColor=TGMaterialSurface(); [self.contentView addSubview:_card];
        _stripe=[[UIView alloc] init]; _stripe.backgroundColor=TGModernSeparator(); [_card addSubview:_stripe]; _cardSeparatorInset=15;
        NSMutableArray *corners=[NSMutableArray arrayWithCapacity:4];
        for(NSUInteger index=0; index<4; index++) {
            UIImageView *corner=[[UIImageView alloc] initWithImage:RT27CardCornerImage(index)];
            corner.userInteractionEnabled=NO; [_card addSubview:corner]; [corners addObject:corner];
        }
        _corners=[corners copy];
    } return self;
}
- (void)setInnerCell:(UITableViewCell *)cell {
    if(_innerCell==cell)return;
    [_innerCell removeFromSuperview];
    _innerCell=cell;
    [_card insertSubview:cell atIndex:0];
    [self setNeedsLayout];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit=[super hitTest:point withEvent:event];
    if(hit==nil)return nil;
    // Only the outer cell belongs to the table. A nested cell has no index path,
    // so route row taps to the outer cell while keeping real control targets.
    for(UIView *view=hit; view!=nil && view!=self; view=view.superview) {
        if([view isKindOfClass:[UIControl class]]) return hit;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; self.card.frame=CGRectMake(16,0,MAX(0,self.bounds.size.width-32),self.bounds.size.height); self.innerCell.frame=self.card.bounds;
    CGFloat pixel=1.0f/[UIScreen mainScreen].scale;
    self.stripe.hidden=self.lastInCard; self.stripe.frame=CGRectMake(self.cardSeparatorInset,self.card.bounds.size.height-pixel,MAX(0,self.card.bounds.size.width-self.cardSeparatorInset-12),pixel);
    for(NSUInteger index=0; index<self.corners.count; index++) {
        UIImageView *corner=self.corners[index];
        corner.hidden=(index&2) ? !self.lastInCard : !self.firstInCard;
        corner.frame=CGRectMake((index&1) ? self.card.bounds.size.width-20 : 0,(index&2) ? self.card.bounds.size.height-20 : 0,20,20);
    }
}
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated { [super setHighlighted:highlighted animated:animated]; [self.innerCell setHighlighted:highlighted animated:animated]; }
- (void)setSelected:(BOOL)selected animated:(BOOL)animated { [super setSelected:selected animated:animated]; [self.innerCell setSelected:selected animated:animated]; }
@end
