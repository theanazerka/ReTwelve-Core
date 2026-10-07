#import "RT27ModernConversationTitleView.h"
@implementation RT27ModernConversationTitleView { UILabel *_heading; UILabel *_detail; }
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:frame])) { self.clipsToBounds=YES; _heading=[[UILabel alloc] init]; _heading.font=TGMaterialFont(17,YES); _heading.textColor=TGMaterialText(); _heading.backgroundColor=[UIColor clearColor]; _heading.textAlignment=NSTextAlignmentCenter; _heading.lineBreakMode=NSLineBreakByTruncatingTail; [self addSubview:_heading]; _detail=[[UILabel alloc] init]; _detail.font=TGMaterialFont(11,NO); _detail.backgroundColor=[UIColor clearColor]; _detail.textAlignment=NSTextAlignmentCenter; _detail.lineBreakMode=NSLineBreakByTruncatingTail; [self addSubview:_detail]; [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)]]; self.accessibilityTraits=UIAccessibilityTraitButton; } return self; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(MIN(180,size.width),44); }
- (void)tapped { if([self.delegate respondsToSelector:@selector(titleViewTapped:)])[self.delegate titleViewTapped:self]; }
- (void)layoutSubviews { [super layoutSubviews]; CGFloat w=self.bounds.size.width,h=self.bounds.size.height; _heading.frame=CGRectMake(0,MAX(0,(h-40)/2),w,24); _detail.frame=CGRectMake(0,MAX(24,(h-40)/2+24),w,16); _heading.text=self.title; _detail.text=self.typingStatus.length ? self.typingStatus : self.status; _detail.textColor=self.typingStatus.length || self.statusHasAccentColor ? TGMaterialPrimary() : TGMaterialSecondaryText(); self.accessibilityLabel=self.title; }
- (void)setTitle:(NSString *)title { _title=[title copy]; [self setNeedsLayout]; }
- (void)setStatus:(NSString *)status { _status=[status copy]; [self setNeedsLayout]; }
- (void)setTypingStatus:(NSString *)status { _typingStatus=[status copy]; [self setNeedsLayout]; }
- (void)setStatusHasAccentColor:(bool)value { _statusHasAccentColor=value; [self setNeedsLayout]; }
- (void)setOrientation:(UIInterfaceOrientation)orientation { [self setNeedsLayout]; }
- (void)setEditingMode:(bool)editing animated:(bool)animated { self.userInteractionEnabled=!editing; }
- (void)setStatus:(NSString *)status animated:(bool)animated { self.status=status; }
- (void)setAttributedStatus:(NSAttributedString *)status animated:(bool)animated { self.status=status.string; }
- (void)setTypingStatus:(NSString *)status activity:(RT27ModernConversationTitleViewActivity)activity animated:(bool)animated { self.typingStatus=status; }
- (void)setIcons:(NSArray *)icons {}
- (void)setModalProgressStatus:(NSString *)status { self.typingStatus=status; }
- (void)setUnreadCount:(int)count {}
- (void)suspendAnimations {}
- (void)resumeAnimations {}
@end
