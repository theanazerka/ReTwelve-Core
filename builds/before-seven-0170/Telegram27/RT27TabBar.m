#import "RT27Compat.h"
#import "RT27TabBar.h"
@interface RT27TabBar ()
@property(nonatomic,strong) NSMutableArray *hitControls;
@end
@implementation RT27TabBar

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        if ([RT27ViewController useExperimentalRTL])
            self.transform = CGAffineTransformMakeScale(-1.0f, 1.0f);
        
        self.multipleTouchEnabled = false;
        self.exclusiveTouch = true;
        
        _selectedIndex=-1;
        _backgroundView=[[UIView alloc] initWithFrame:self.bounds]; _backgroundView.backgroundColor=[UIColor whiteColor]; _backgroundView.userInteractionEnabled=NO; [self addSubview:_backgroundView];
        _stripeView=[[UIView alloc] init]; _stripeView.backgroundColor=RT27SeparatorColor(); _stripeView.userInteractionEnabled=NO; [self addSubview:_stripeView];

        _buttonViews = [[NSMutableArray alloc] init];
        
        UIImageView *contactsIcon = [[UIImageView alloc] initWithImage:[UIImage rt27_imageNamed:@"TabIconContacts.png"] highlightedImage:[UIImage rt27_imageNamed:@"TabIconContacts_Highlighted.png"]];
        [self addSubview:contactsIcon];
        [_buttonViews addObject:contactsIcon];
        
        UIImageView *messagesIcon = [[UIImageView alloc] initWithImage:[UIImage rt27_imageNamed:@"TabIconMessages.png"] highlightedImage:[UIImage rt27_imageNamed:@"TabIconMessages_Highlighted.png"]];
        [self addSubview:messagesIcon];
        [_buttonViews addObject:messagesIcon];
        
        UIImageView *settingsIcon = [[UIImageView alloc] initWithImage:[UIImage rt27_imageNamed:@"TabIconSettings.png"] highlightedImage:[UIImage rt27_imageNamed:@"TabIconSettings_Highlighted.png"]];
        [self addSubview:settingsIcon];
        [_buttonViews addObject:settingsIcon];
        
        _labelViews = [[NSMutableArray alloc] init];
        
        NSArray *titles = @[RT27Localized(@"Contacts.TabTitle"),
                            RT27Localized(@"DialogList.TabTitle"),
                            RT27Localized(@"Settings.TabTitle")];
        
        for (NSString *title in titles)
        {
            UILabel *label = [self createTabLabelWithText:title];
            [self addSubview:label];
            [_labelViews addObject:label];
        }
        _hitControls=[NSMutableArray array];
        for (NSUInteger index=0;index<titles.count;index++) {
            UIControl *control=[[UIControl alloc] initWithFrame:CGRectZero];
            control.tag=index; control.exclusiveTouch=YES;
            control.isAccessibilityElement=YES; control.accessibilityLabel=titles[index]; control.accessibilityTraits=UIAccessibilityTraitButton;
            [control addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:control]; [_hitControls addObject:control];
        }
    }
    return self;
}

- (UIFont *)tabLabelFont
{
    static UIFont *font = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            font = RT27SystemFontOfSize(10);
        else
            font = RT27SystemFontOfSize(14);
    });
    
    return font;
}

- (CGFloat)iconVerticalOffset
{
    static CGFloat offset = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            offset = 4.0f;
        else
            offset = 5.0f + RT27RetinaPixel;
    });
    
    return offset;
}

- (CGFloat)labelVerticalOffset
{
    static CGFloat offset = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            offset = 35 - RT27RetinaPixel;
        else
            offset = 36;
    });
    
    return offset;
}

- (CGFloat)sideIconOffsetForWidth:(CGFloat)width
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        return 0.0f;
    if (width < 320.0f + FLT_EPSILON)
        return 0.0f;
    
    return RT27Floor(width / 21.5f);
}

- (UILabel *)createTabLabelWithText:(NSString *)text
{
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = RT27ColorRGB(0x929292);
    label.highlightedTextColor = RT27AccentColor();
    label.font = [self tabLabelFont];
    label.text = text;
    [label sizeToFit];
    return label;
}

- (void)setSelectedIndex:(int)selectedIndex
{
    if (_selectedIndex==selectedIndex) return;
    if (_selectedIndex >= 0 && _selectedIndex < (int)_buttonViews.count)
    {
        ((UIImageView *)[_buttonViews objectAtIndex:_selectedIndex]).highlighted = false;
        ((UILabel *)[_labelViews objectAtIndex:_selectedIndex]).highlighted = false;
    }
    
    _selectedIndex = selectedIndex;
    
    if (_selectedIndex >= 0 && _selectedIndex < (int)_buttonViews.count)
    {
        ((UIImageView *)[_buttonViews objectAtIndex:_selectedIndex]).highlighted = true;
        ((UILabel *)[_labelViews objectAtIndex:_selectedIndex]).highlighted = true;
    }
    for (UIControl *control in _hitControls) control.accessibilityTraits=UIAccessibilityTraitButton | (control.tag==selectedIndex ? UIAccessibilityTraitSelected : 0);
}

- (void)tabPressed:(UIControl *)control {
    int index=(int)control.tag;
    if (index<0 || index>=(int)_buttonViews.count) return;
    [self setSelectedIndex:index];
    [_tabDelegate tabBarSelectedItem:index];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    int index = MAX(0, MIN((int)_buttonViews.count - 1, (int)([touch locationInView:self].x / (self.frame.size.width / 3))));
    [self setSelectedIndex:index];
    
    __strong id<RT27TabBarDelegate> delegate = _tabDelegate;
    [delegate tabBarSelectedItem:index];
}

- (void)loadUnreadBadgeView
{
    if (_unreadBadgeContainer != nil)
        return;
    
    _unreadBadgeContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    _unreadBadgeContainer.hidden = true;
    _unreadBadgeContainer.userInteractionEnabled = false;
    _unreadBadgeContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self addSubview:_unreadBadgeContainer];
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(18.0f, 18.0f), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, RT27ColorRGB(0xff3b30).CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 18.0f, 18.0f));
    UIImage *badgeImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:9.0f topCapHeight:0.0f];
    UIGraphicsEndImageContext();
    
    _unreadBadgeBackground = [[UIImageView alloc] initWithImage:badgeImage];
    [_unreadBadgeContainer addSubview:_unreadBadgeBackground];
    
    _unreadBadgeLabel = [[UILabel alloc] init];
    _unreadBadgeLabel.text = @"1";
    [_unreadBadgeLabel sizeToFit];
    _unreadBadgeLabel.text = nil;
    _unreadBadgeLabel.backgroundColor = [UIColor clearColor];
    _unreadBadgeLabel.textColor = [UIColor whiteColor];
    _unreadBadgeLabel.font = RT27SystemFontOfSize(13);
    [_unreadBadgeContainer addSubview:_unreadBadgeLabel];
    
    [self setNeedsLayout];
}

- (void)setUnreadCount:(int)unreadCount
{
    if (unreadCount <= 0 && _unreadBadgeLabel == nil)
        return;
    
    [self loadUnreadBadgeView];
    
    if (unreadCount <= 0)
        _unreadBadgeContainer.hidden = true;
    else
    {
        NSString *text = nil;
        
        if (RT27IsLocaleArabic())
            text = [RT27StringUtils stringWithLocalizedNumber:unreadCount];
        else
        {
            if (unreadCount < 1000)
                text = [[NSString alloc] initWithFormat:@"%d", unreadCount];
            else if (unreadCount < 1000000)
                text = [[NSString alloc] initWithFormat:@"%dK", unreadCount / 1000];
            else
                text = [[NSString alloc] initWithFormat:@"%dM", unreadCount / 1000000];
        }
        
        _unreadBadgeLabel.text = text;
        [_unreadBadgeLabel sizeToFit];
        _unreadBadgeContainer.hidden = false;
        
        CGRect frame = _unreadBadgeBackground.frame;
        CGFloat textWidth = _unreadBadgeLabel.frame.size.width;
        frame.size.width = MAX(18.0f, textWidth + 10.0f + RT27RetinaPixel * 2.0f);
        frame.origin.x = _unreadBadgeBackground.superview.frame.size.width - frame.size.width;
        _unreadBadgeBackground.frame = frame;
        
        CGRect labelFrame = _unreadBadgeLabel.frame;
        labelFrame.origin.x = 5.0f + RT27RetinaPixel + frame.origin.x;
        labelFrame.origin.y = 1;
        _unreadBadgeLabel.frame = labelFrame;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize viewSize = self.bounds.size;
    
    _backgroundView.frame = CGRectMake(0, 0, viewSize.width, viewSize.height);
    CGFloat stripeHeight = RT27IsRetina() ? 0.5f : 1.0f;
    _stripeView.frame = CGRectMake(0, -stripeHeight, viewSize.width, stripeHeight);
    
    float indicatorWidth = floorf((float)viewSize.width / 3);
    if (((int)indicatorWidth) % 2 != 0)
        indicatorWidth -= 1;
    
    float paddingLeft = floorf((float)(viewSize.width - indicatorWidth * 3) / 2);
    CGFloat iconVerticalOffset = [self iconVerticalOffset];
    CGFloat labelVerticalOffset = [self labelVerticalOffset];
    for (NSUInteger index=0;index<_hitControls.count;index++) {
        CGFloat left=RT27RetinaFloor(viewSize.width*index/_hitControls.count);
        CGFloat right=RT27RetinaFloor(viewSize.width*(index+1)/_hitControls.count);
        ((UIControl *)_hitControls[index]).frame=CGRectMake(left,0,right-left,viewSize.height);
    }
    
    int index = -1;
    for (UIView *iconView in _buttonViews)
    {
        index++;
        
        CGFloat horizontalOffset = 0.0f;
        if (index == 0 || index == 2)
            horizontalOffset = [self sideIconOffsetForWidth:viewSize.width] * (index == 0 ? 1 : -1);
        
        CGRect frame = iconView.frame;
        frame.origin.x = paddingLeft + index * indicatorWidth + floorf((float)(indicatorWidth - frame.size.width) / 2) + horizontalOffset;
        frame.origin.y = iconVerticalOffset;
        
        iconView.frame = frame;
        
        if (index == 1)
        {
            if (_unreadBadgeContainer != nil)
            {
                CGRect unreadBadgeContainerFrame = _unreadBadgeContainer.frame;
                unreadBadgeContainerFrame.origin.x = frame.origin.x + frame.size.width - 9;
                unreadBadgeContainerFrame.origin.y = 2;
                _unreadBadgeContainer.frame = unreadBadgeContainerFrame;
            }
        }
        
        UILabel *labelView = [_labelViews objectAtIndex:index];
        
        CGRect labelFrame = labelView.frame;
        labelFrame.origin.x = paddingLeft + index * indicatorWidth + floorf((float)(indicatorWidth - labelFrame.size.width) / 2) + horizontalOffset;
        labelFrame.origin.y = labelVerticalOffset;
        labelView.frame = labelFrame;
    }
}

@end
