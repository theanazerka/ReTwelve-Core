#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27ModernBarButton.h"

#import "RT27ModernBackToolbarButton.h"

@interface RT27ModernBarButton ()
{
    UIImageView *_iconView;
}

@end

@implementation RT27ModernBarButton

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, image.size.width, image.size.height)];
    if (self)
    {
        _iconView = [[UIImageView alloc] initWithImage:image];
        [self addSubview:_iconView];
    }
    return self;
}

- (UIEdgeInsets)alignmentRectInsets
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    insets = UIEdgeInsetsMake(0.0f, 0.0f, 8.0f, 0.0f);
    return insets;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (self.superview.frame.size.height > 32.0f + 1.0f)
        _iconView.frame = CGRectMake(_portraitAdjustment.x, _portraitAdjustment.y, _iconView.frame.size.width, _iconView.frame.size.height);
    else
        _iconView.frame = CGRectMake(_landscapeAdjustment.x, _landscapeAdjustment.y, _iconView.frame.size.width, _iconView.frame.size.height);
}

@end
