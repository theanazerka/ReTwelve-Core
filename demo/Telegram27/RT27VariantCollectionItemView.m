#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27VariantCollectionItemView.h"

#import "RT27Compat.h"
#import "RT27Compat.h"

@interface RT27VariantCollectionItemView ()
{
    UILabel *_titleLabel;
    UILabel *_variantLabel;
    UIImageView *_disclosureIndicator;
}

@end

@implementation RT27VariantCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = RT27SystemFontOfSize(17);
        [self addSubview:_titleLabel];
        
        _variantLabel = [[UILabel alloc] init];
        _variantLabel.textColor = RT27ColorRGB(0x929297);
        _variantLabel.backgroundColor = [UIColor clearColor];
        _variantLabel.font = RT27SystemFontOfSize(17);
        [self addSubview:_variantLabel];
        
        _disclosureIndicator = [[UIImageView alloc] initWithImage:[UIImage rt27_imageNamed:@"ModernListsDisclosureIndicator.png"]];
        [self addSubview:_disclosureIndicator];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setVariant:(NSString *)variant
{
    _variantLabel.text = variant;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(bounds.size.width, CGFLOAT_MAX)];
    CGSize variantSize = [_variantLabel sizeThatFits:CGSizeMake(bounds.size.width, CGFLOAT_MAX)];
    
    _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 15, floorf((bounds.size.height - _disclosureIndicator.frame.size.height) / 2), _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
    
    CGFloat startingX = 15.0f;
    CGFloat indicatorSpacing = 10.0f;
    CGFloat labelSpacing = 8.0f;
    CGFloat availableWidth = _disclosureIndicator.frame.origin.x - startingX - indicatorSpacing;
    
    CGFloat titleY =  RT27Floor((bounds.size.height - titleSize.height) / 2.0f) + RT27RetinaPixel;
    CGFloat variantY =  RT27Floor((bounds.size.height - variantSize.height) / 2.0f) + RT27RetinaPixel;
    
    if (titleSize.width + labelSpacing + variantSize.width <= availableWidth)
    {
        _titleLabel.frame = CGRectMake(startingX, titleY, titleSize.width, titleSize.height);
        _variantLabel.frame = CGRectMake(startingX + availableWidth - variantSize.width, variantY, variantSize.width, variantSize.height);
    }
    else if (titleSize.width > variantSize.width)
    {
        CGFloat titleWidth = RT27Floor(availableWidth * 2.0f / 3.0f) - labelSpacing;
        _titleLabel.frame = CGRectMake(startingX, titleY, titleWidth, titleSize.height);
        CGFloat variantWidth = MIN(variantSize.width, availableWidth - titleWidth - labelSpacing);
        _variantLabel.frame = CGRectMake(startingX + availableWidth - variantWidth, variantY, variantWidth, variantSize.height);
    }
    else
    {
        CGFloat variantWidth = RT27Floor(availableWidth / 2.0f) - labelSpacing;
        _variantLabel.frame = CGRectMake(startingX + availableWidth - variantWidth, variantY, variantWidth, variantSize.height);
        CGFloat titleWidth = MIN(titleSize.width, availableWidth - variantWidth - labelSpacing);
        _titleLabel.frame = CGRectMake(startingX, titleY, titleWidth, titleSize.height);
    }
}

@end
