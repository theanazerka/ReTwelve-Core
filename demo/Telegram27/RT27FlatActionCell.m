#import "../Seven/RT7UIKit.h"
#import "RT27Compat.h"
#import "RT27FlatActionCell.h"

#import "RT27Compat.h"

#import "RT27Compat.h"
#import "RT27Compat.h"

@interface RT27FlatActionCell ()
{
    CALayer *_separatorLayer;
}

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *iconView;

@property (nonatomic) RT27FlatActionCellMode mode;

@end

@implementation RT27FlatActionCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        UIView *selectedView = [[UIView alloc] init];
        selectedView.backgroundColor = RT27SelectionColor();
        self.selectedBackgroundView = selectedView;
        
        CGFloat originX = RT27IsPad() ? 74.0f : 66.0f;
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(originX, 14 - RT27RetinaPixel + (RT27IsPad() ? 4.0f : 0.0f), self.contentView.frame.size.width - originX - 6, 20)];
        _titleLabel.contentMode = UIViewContentModeLeft;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.font = RT27SystemFontOfSize(17);
        _titleLabel.backgroundColor = [UIColor whiteColor];
        _titleLabel.textColor = RT27AccentColor();
        [self.contentView addSubview:_titleLabel];
        
        _iconView = [[UIImageView alloc] init];
        [self.contentView addSubview:_iconView];
        
        _separatorLayer = [[CALayer alloc] init];
        _separatorLayer.backgroundColor = RT27SeparatorColor().CGColor;
        [self.contentView.layer addSublayer:_separatorLayer];
    }
    return self;
}

- (void)setMode:(RT27FlatActionCellMode)mode
{
    _mode = mode;
    
    if (mode == RT27FlatActionCellModeInvite)
        _titleLabel.text = RT27Localized(@"Contacts.InviteFriends");
    else if (mode == RT27FlatActionCellModeCreateGroup || mode == RT27FlatActionCellModeCreateGroupContacts)
        _titleLabel.text = RT27Localized(@"Compose.NewGroup");
    else if (mode == RT27FlatActionCellModeCreateEncrypted)
        _titleLabel.text = RT27Localized(@"Compose.NewEncryptedChat");
    else if (mode == RT27FlatActionCellModeBroadcasts)
        _titleLabel.text = RT27Localized(@"BroadcastLists.Title");
    else if (mode == RT27FlatActionCellModeCreateBroadcast)
        _titleLabel.text = RT27Localized(@"Compose.NewBroadcastButton");

    static UIImage *inviteIcon = nil;
    static UIImage *friendsIcon = nil;
    static UIImage *encryptedIcon = nil;
    static UIImage *broadcastsIcon = nil;
    
    if (inviteIcon == nil)
    {
        inviteIcon = [UIImage rt27_imageNamed:@"ModernContactListInviteFriendsIcon.png"];
        friendsIcon = [UIImage rt27_imageNamed:@"ModernContactListCreateGroupIcon.png"];
        encryptedIcon = [UIImage rt27_imageNamed:@"ModernContactListCreateSecretChatIcon.png"];
        broadcastsIcon = [UIImage rt27_imageNamed:@"ModernContactListBroadcastIcon.png"];
    }
    
    CGFloat verticalOffset = RT27IsPad() ? 4.0f : 0.0f;
    CGFloat horizontalOffset = RT27IsPad() ? 8.0f : 0.0f;
    
    if (mode == RT27FlatActionCellModeInvite)
    {
        _iconView.image = inviteIcon;
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(20 - RT27RetinaPixel + horizontalOffset, 9 + verticalOffset);
        _iconView.frame = iconFrame;
    }
    else if (mode == RT27FlatActionCellModeCreateGroup || mode == RT27FlatActionCellModeCreateGroupContacts)
    {
        _iconView.image = friendsIcon;
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(20 - RT27RetinaPixel + horizontalOffset, 9 + verticalOffset);
        _iconView.frame = iconFrame;
    }
    else if (mode == RT27FlatActionCellModeCreateEncrypted)
    {
        _iconView.image = encryptedIcon;
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(20 - RT27RetinaPixel + horizontalOffset - 1, 8 + verticalOffset);
        _iconView.frame = iconFrame;
    }
    else if (mode == RT27FlatActionCellModeBroadcasts || mode == RT27FlatActionCellModeCreateBroadcast)
    {
        _iconView.image = broadcastsIcon;
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(20 - RT27RetinaPixel + horizontalOffset - 1 + 2, 8 + verticalOffset + 3);
        _iconView.frame = iconFrame;
    }
    if((int)mode==6) {
        _titleLabel.text=@"Создать контакт";
        _iconView.image=RT7ImageNamed(@"ModernSettings/ModernContactListAddMemberIcon");
        [_iconView sizeToFit]; _iconView.frame=CGRectMake(20,9,_iconView.frame.size.width,_iconView.frame.size.height);
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
            if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass])// || ((int)view.frame.size.height) == 25)
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
    
    CGFloat separatorHeight = RT27IsRetina() ? 0.5f : 1.0f;
    
    CGRect frame = self.selectedBackgroundView.frame;
    frame.origin.y = true ? -1 : 0;
    frame.size.height = self.frame.size.height + 1;
    self.selectedBackgroundView.frame = frame;
    
    CGFloat separatorOrigin = (RT27IsPad() ? 74.0f : 65.0f);
    _separatorLayer.frame = CGRectMake(separatorOrigin, self.frame.size.height - separatorHeight, self.frame.size.width - separatorOrigin, separatorHeight);
}

@end
