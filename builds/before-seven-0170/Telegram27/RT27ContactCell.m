#import "RT27ContactCell.h"
@implementation RT27ContactCell { UIImageView *_portrait; UILabel *_name; UILabel *_status; UIImageView *_selection; UIImage *_cachedPortrait; UITapGestureRecognizer *_selectionTap; }
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier { return [self initWithStyle:style reuseIdentifier:identifier selectionControls:NO editingControls:NO]; }
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier selectionControls:(bool)selection editingControls:(bool)editing {
 if((self=[super initWithStyle:style reuseIdentifier:identifier])) {
  self.backgroundColor=TGMaterialSurface(); self.selectionStyle=UITableViewCellSelectionStyleGray; UIView *highlight=[[UIView alloc] init]; highlight.backgroundColor=TGMaterialPrimaryContainer(); self.selectedBackgroundView=highlight;
  _portrait=[[UIImageView alloc] init]; _portrait.contentMode=UIViewContentModeScaleAspectFill; _portrait.clipsToBounds=YES; _portrait.layer.cornerRadius=22; [self.contentView addSubview:_portrait];
  _name=[[UILabel alloc] init]; _name.font=TGMaterialFont(16,YES); _name.textColor=TGMaterialText(); _name.backgroundColor=[UIColor clearColor]; [self.contentView addSubview:_name];
  _status=[[UILabel alloc] init]; _status.font=TGMaterialFont(12,NO); _status.backgroundColor=[UIColor clearColor]; [self.contentView addSubview:_status];
  _selection=[[UIImageView alloc] init]; _selection.contentMode=UIViewContentModeCenter; _selection.layer.cornerRadius=12; _selection.layer.borderWidth=1.5; _selection.layer.borderColor=TGMaterialOutline().CGColor; [self.contentView addSubview:_selection];
  _selectionTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleContact:)]; [self.contentView addGestureRecognizer:_selectionTap]; self.selectionEnabled=selection;
 }
 return self;
}
- (void)layoutSubviews { [super layoutSubviews]; CGFloat h=self.bounds.size.height,w=self.contentView.bounds.size.width,left=self.selectionEnabled ? 52 : 16;
 _selectionTap.enabled=self.selectionEnabled && self.actionHandle!=nil; _selection.hidden=!self.selectionEnabled; _selection.frame=CGRectMake(16,(h-24)/2,24,24); _portrait.hidden=self.hideAvatar; _portrait.frame=CGRectMake(left,(h-44)/2,44,44);
 left+=self.hideAvatar ? 0 : 60; _name.frame=CGRectMake(left,MAX(3,(h-42)/2),MAX(0,w-left-16),24); _status.frame=CGRectMake(left,CGRectGetMaxY(_name.frame),MAX(0,w-left-16),18);
 _name.text=[@[self.titleTextFirst ?: @"",self.titleTextSecond ?: @""] componentsJoinedByString:@" "]; _status.text=self.subtitleText;
 if(self.subtitleAttributedText.length)_status.attributedText=self.subtitleAttributedText;
 _status.textColor=self.subtitleActive ? TGMaterialPrimary() : TGMaterialSecondaryText(); self.contentView.alpha=self.isDisabled ? .45 : 1;
 _selection.backgroundColor=self.contactSelected ? TGMaterialPrimary() : [UIColor clearColor]; _selection.image=self.contactSelected ? TGMaterialIcon(@"check",18,TGMaterialOnPrimary()) : nil;
}
- (void)toggleContact:(UITapGestureRecognizer *)gesture { if(gesture.state==UIGestureRecognizerStateEnded && self.selectionEnabled && !self.isDisabled) [self.actionHandle requestAction:@"/contactlist/toggleItem" options:@{@"itemId":@(self.itemId),@"selected":@(self.contactSelected),@"cell":self}]; }
- (void)resetView:(bool)animated { if(!_cachedPortrait)_portrait.image=TGMaterialIcon(@"person",40,TGMaterialPrimary()); [self setNeedsLayout]; }
- (void)setCachedAvatarImage:(UIImage *)image { _cachedPortrait=image; _portrait.image=image; }
- (void)setSelectionEnabled:(bool)enabled animated:(bool)animated { self.selectionEnabled=enabled; [self setNeedsLayout]; }
- (void)updateFlags:(bool)selected { [self updateFlags:selected animated:NO force:NO]; }
- (void)updateFlags:(bool)selected force:(bool)force { [self updateFlags:selected animated:NO force:force]; }
- (void)updateFlags:(bool)selected animated:(bool)animated force:(bool)force { self.contactSelected=selected; [self setNeedsLayout]; }
@end
