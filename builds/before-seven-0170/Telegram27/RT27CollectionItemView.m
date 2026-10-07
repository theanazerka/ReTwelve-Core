#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27CollectionItemView.h"

#import <QuartzCore/QuartzCore.h>

#import "RT27Compat.h"

@interface RT27CollectionItemView ()
{
}

@end

@implementation RT27CollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _itemPosition = 1 << 31;
        _separatorInset = 15.0f;
        
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = [UIColor whiteColor];
        
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = RT27SelectionColor();
    }
    return self;
}

- (void)setItemPosition:(int)itemPosition
{
    if (_itemPosition != itemPosition)
    {
        _itemPosition = itemPosition;
        [self _updateStripes];
        [self setNeedsLayout];
    }
}

- (void)_updateStripes
{
    static CGColorRef stripeColor = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        stripeColor = CGColorRetain(RT27SeparatorColor().CGColor);
    });
    
    if (_topStripeLayer == nil)
    {
        _topStripeLayer = [[CALayer alloc] init];
        _topStripeLayer.backgroundColor = stripeColor;
        [self.backgroundView.layer addSublayer:_topStripeLayer];
    }
    
    if (_bottomStripeLayer == nil)
    {
        _bottomStripeLayer = [[CALayer alloc] init];
        _bottomStripeLayer.backgroundColor = stripeColor;
        [self.backgroundView.layer addSublayer:_bottomStripeLayer];
    }
    
    _topStripeLayer.hidden = (_itemPosition & (RT27CollectionItemViewPositionFirstInBlock | RT27CollectionItemViewPositionLastInBlock | RT27CollectionItemViewPositionMiddleInBlock)) == 0;
    _bottomStripeLayer.hidden = (_itemPosition & (RT27CollectionItemViewPositionLastInBlock | RT27CollectionItemViewPositionIncludeNextSeparator)) == 0;
    self.backgroundView.backgroundColor = _itemPosition == 0 ? [UIColor clearColor] : [UIColor whiteColor];
}

static void adjustSelectedBackgroundViewFrame(CGSize viewSize, int positionMask, UIEdgeInsets selectionInsets, UIView *backgroundView)
{
    CGRect frame = backgroundView.frame;
    
    float stripeHeight = RT27IsRetina() ? 0.5f : 1.0f;
    
    if ((positionMask & RT27CollectionItemViewPositionFirstInBlock) && (positionMask & RT27CollectionItemViewPositionLastInBlock))
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height;
    }
    else if (positionMask & (RT27CollectionItemViewPositionLastInBlock | RT27CollectionItemViewPositionIncludeNextSeparator))
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height;
    }
    else if (positionMask & RT27CollectionItemViewPositionFirstInBlock)
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height + stripeHeight;
    }
    else
    {
        frame.origin.y = 0;
        frame.size.height = viewSize.height + stripeHeight;
    }
    
    frame.origin.y -= selectionInsets.top;
    frame.size.height += selectionInsets.top + selectionInsets.bottom;

    backgroundView.frame = frame;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    if (selected)
    {
        adjustSelectedBackgroundViewFrame(self.frame.size, _itemPosition, _selectionInsets, self.selectedBackgroundView);
        
        [self adjustOrdering];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    if (highlighted)
    {
        adjustSelectedBackgroundViewFrame(self.frame.size, _itemPosition, _selectionInsets, self.selectedBackgroundView);
        
        [self adjustOrdering];
    }
}

- (void)adjustOrdering
{
    Class UITableViewCellClass = [UICollectionViewCell class];
    Class UISearchBarClass = [UISearchBar class];
    int maxCellIndex = 0;
    int index = -1;
    int selfIndex = 0;
    for (UIView *view in self.superview.subviews)
    {
        index++;
        if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass])
        {
            maxCellIndex = index;
            
            if (view == self)
                selfIndex = index;
        }
    }
    
    if (selfIndex < maxCellIndex)
    {
        [self.superview insertSubview:self atIndex:maxCellIndex];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize viewSize = self.bounds.size;
    
    adjustSelectedBackgroundViewFrame(viewSize, _itemPosition, _selectionInsets, self.selectedBackgroundView);
    
    static float stripeHeight = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        stripeHeight = RT27IsRetina() ? 0.5f : 1.0f;
    });
    
    if (_itemPosition & RT27CollectionItemViewPositionFirstInBlock)
        _topStripeLayer.frame = CGRectMake(0, 0, viewSize.width, stripeHeight);
    else
        _topStripeLayer.frame = CGRectMake(_separatorInset, 0, viewSize.width - _separatorInset, stripeHeight);
    
    if (_itemPosition & RT27CollectionItemViewPositionLastInBlock)
        _bottomStripeLayer.frame = CGRectMake(0, viewSize.height - stripeHeight, viewSize.width, stripeHeight);
    else if (_itemPosition & RT27CollectionItemViewPositionIncludeNextSeparator)
        _bottomStripeLayer.frame = CGRectMake(_separatorInset, viewSize.height - stripeHeight, viewSize.width - _separatorInset, stripeHeight);
}

@end
