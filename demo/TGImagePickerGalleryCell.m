#import "Seven/RT7UIKit.h"
#import "TGTheme.h"
#import "TGImagePickerGalleryCell.h"



@interface TGImagePickerGalleryCell ()

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;

@end

@implementation TGImagePickerGalleryCell

@synthesize iconView = _iconView;
@synthesize titleLabel = _titleLabel;
@synthesize countLabel = _countLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        static UIImage *cellImage = nil;
        if (cellImage == nil)
            cellImage = [RT7ImageNamed(@"OriginalTelegram/Cell96_Light.png") stretchableImageWithLeftCapWidth:0 topCapHeight:1];
        
        static UIImage *selectedCellImage = nil;
        if (selectedCellImage == nil)
            selectedCellImage = RT7ImageNamed(@"OriginalTelegram/CellHighlighted96.png");
        
        self.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];
        
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(6, 7, 33, 33)];
        [self.contentView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(53, 13, 10, 20)];
        _titleLabel.contentMode = UIViewContentModeLeft;
        _titleLabel.font = TGModernThemeEnabled() ? [UIFont systemFontOfSize:17] : [UIFont boldSystemFontOfSize:17];
        _titleLabel.backgroundColor = [UIColor whiteColor];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.highlightedTextColor = TGModernThemeEnabled() ? [UIColor blackColor] : [UIColor whiteColor];
        [self.contentView addSubview:_titleLabel];
        
        _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(53, 13, 10, 20)];
        _countLabel.contentMode = UIViewContentModeLeft;
        _countLabel.font = [UIFont systemFontOfSize:17];
        _countLabel.backgroundColor = [UIColor whiteColor];
        _countLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1];
        _countLabel.highlightedTextColor = TGModernThemeEnabled() ? TGModernSecondaryText() : [UIColor whiteColor];
        [self.contentView addSubview:_countLabel];
        
        UIImageView *disclosureIndicator = [[UIImageView alloc] initWithImage:RT7ImageNamed(@"OriginalTelegram/MenuDisclosureIndicator_Light.png") highlightedImage:RT7ImageNamed(@"OriginalTelegram/MenuDisclosureIndicator_Highlighted.png")];
        disclosureIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        disclosureIndicator.frame = CGRectOffset(disclosureIndicator.frame, self.contentView.frame.size.width - disclosureIndicator.frame.size.width - 12, 15 + (([UIScreen mainScreen].scale > 1) ? 0.5f : 0.0f));
        [self.contentView addSubview:disclosureIndicator];
    }
    return self;
}

- (void)setIcon:(UIImage *)icon highlightedIcon:(UIImage *)highlightedIcon
{
    _iconView.image = icon;
    _iconView.highlightedImage = highlightedIcon;
}

- (void)setTitle:(NSString *)title countString:(NSString *)countString
{
    _titleLabel.text = title;
    _countLabel.text = countString;
    [_countLabel sizeToFit];
}

- (void)setTitleAccentColor:(bool)accent
{
    if (accent)
    {
        _titleLabel.textColor = [UIColor colorWithRed:0 green:0.45 blue:0.82 alpha:1];
    }
    else
    {
        _titleLabel.textColor = [UIColor blackColor];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    if (selected)
    {
        CGRect frame = self.selectedBackgroundView.frame;
        frame.origin.y = true ? -1 : 0;
        frame.size.height = self.frame.size.height + 1;
        self.selectedBackgroundView.frame = frame;
        
        [self adjustOrdering];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    if (highlighted)
    {
        CGRect frame = self.selectedBackgroundView.frame;
        frame.origin.y = true ? -1 : 0;
        frame.size.height = self.frame.size.height + 1;
        self.selectedBackgroundView.frame = frame;
        
        [self adjustOrdering];
    }
}

- (void)adjustOrdering
{
    if ([self.superview isKindOfClass:[UITableView class]])
    {
        Class UITableViewCellClass = [UITableViewCell class];
        Class UISearchBarClass = [UISearchBar class];
        int maxCellIndex = 0;
        int index = -1;
        int selfIndex = 0;
        for (UIView *view in self.superview.subviews)
        {
            index++;
            if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass] || view.tag == 0x33FC2014)
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
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = self.selectedBackgroundView.frame;
    frame.origin.y = true ? -1 : 0;
    frame.size.height = self.frame.size.height + 1;
    self.selectedBackgroundView.frame = frame;
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(self.frame.size.width - 50 - 70, _titleLabel.frame.size.height)];
    _titleLabel.frame = CGRectMake(_titleLabel.frame.origin.x, _titleLabel.frame.origin.y, titleSize.width, titleSize.height);
    
    _countLabel.frame = CGRectMake(_titleLabel.frame.origin.x + titleSize.width + 4, _countLabel.frame.origin.y, _countLabel.frame.size.width, _countLabel.frame.size.height);
}

@end
