#import "RT7UIKit.h"
#import <objc/runtime.h>
#include <math.h>

static UIColor *TGColor(unsigned int hex) { return [UIColor colorWithRed:((hex>>16)&255)/255.0 green:((hex>>8)&255)/255.0 blue:(hex&255)/255.0 alpha:1]; }
UIColor *RT7Primary(void) { return TGColor(0x007AFF); }
UIColor *RT7OnPrimary(void) { return TGColor(0xFFFFFF); }
UIColor *RT7PrimaryContainer(void) { return TGColor(0xD9EBFF); }
UIColor *RT7Surface(void) { return TGColor(0xFFFFFF); }
UIColor *RT7Canvas(void) { return TGColor(0xEFEFF4); }
UIColor *RT7SurfaceVariant(void) { return TGColor(0xE5E5EA); }
UIColor *RT7Text(void) { return TGColor(0x000000); }
UIColor *RT7SecondaryText(void) { return TGColor(0x8E8E93); }
UIColor *RT7Outline(void) { return TGColor(0xC8C7CC); }
UIColor *RT7Error(void) { return TGColor(0xFF3B30); }
UIColor *RT7BubbleColor(NSInteger index) { unsigned int colors[]={0xDCF8C6,0xD6EDD0,0xD8E2FF,0xFFD9E4,0xE8DEFF,0xF5E3A3,0xFFDBC9}; return TGColor(colors[MAX(0,MIN(6,index))]); }
UIImage *RT7Wallpaper(NSInteger index) {
 static NSArray *images; static dispatch_once_t once; dispatch_once(&once,^{
 NSMutableArray *items=[NSMutableArray array];
 for(NSInteger i=0;i<3;i++) {
  CGSize size=CGSizeMake(320,568); UIGraphicsBeginImageContextWithOptions(size,YES,0); [i==1 ? RT7Surface() : RT7Canvas() setFill]; UIRectFill((CGRect){CGPointZero,size});
  if(i==2) { [[RT7PrimaryContainer() colorWithAlphaComponent:.55] setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-140,-110,420,420)] fill]; [[RT7SurfaceVariant() colorWithAlphaComponent:.7] setFill]; [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(135,320,270,270) cornerRadius:90] fill]; }
  [items addObject:UIGraphicsGetImageFromCurrentImageContext()]; UIGraphicsEndImageContext();
 }
 images=[items copy]; }); return images[MAX(0,MIN(2,index))];
}
UIFont *RT7Font(CGFloat size, BOOL medium) { return [UIFont fontWithName:medium ? @"HelveticaNeue-Medium" : @"HelveticaNeue" size:size] ?: [UIFont systemFontOfSize:size]; }

UIImage *RT7Shape(CGSize size, UIColor *color, CGFloat radius) {
    size.width=MAX(2,size.width); size.height=MAX(2,size.height);
    UIGraphicsBeginImageContextWithOptions(size,NO,0);
    [color setFill]; [[UIBezierPath bezierPathWithRoundedRect:(CGRect){CGPointZero,size} cornerRadius:MIN(radius,MIN(size.width,size.height)/2)] fill];
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image;
}
static void TGLine(CGContextRef ctx, CGFloat x, CGFloat y, CGFloat dx, CGFloat dy) { CGContextMoveToPoint(ctx,x,y); CGContextAddLineToPoint(ctx,dx,dy); }
UIImage *RT7Icon(NSString *name, CGFloat size, UIColor *color) {
    static NSCache *cache; static dispatch_once_t once; dispatch_once(&once,^{ cache=[[NSCache alloc] init]; cache.countLimit=180; });
    NSString *key=[NSString stringWithFormat:@"%@/%g/%@",name,size,color]; UIImage *image=[cache objectForKey:key]; if(image)return image;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size,size),NO,0); CGContextRef c=UIGraphicsGetCurrentContext(); CGContextScaleCTM(c,size/24,size/24);
    CGContextSetStrokeColorWithColor(c,color.CGColor); CGContextSetFillColorWithColor(c,color.CGColor); CGContextSetLineWidth(c,1.4); CGContextSetLineCap(c,kCGLineCapRound); CGContextSetLineJoin(c,kCGLineJoinRound);
    if([name isEqual:@"close"]) { TGLine(c,6,6,18,18); TGLine(c,18,6,6,18); }
    else if([name isEqual:@"back"]) { TGLine(c,15,3,6,12); CGContextAddLineToPoint(c,15,21); }
    else if([name isEqual:@"chevron"]) { TGLine(c,9,6,15,12); CGContextAddLineToPoint(c,9,18); }
    else if([name isEqual:@"search"]) { CGContextStrokeEllipseInRect(c,CGRectMake(3,3,13,13)); TGLine(c,14.5,14.5,21,21); }
    else if([name isEqual:@"add"]) { TGLine(c,12,5,12,19); TGLine(c,5,12,19,12); }
    else if([name isEqual:@"check"]) { TGLine(c,4,12,9,17); CGContextAddLineToPoint(c,20,6); }
    else if([name isEqual:@"more"]) { for(int i=0;i<3;i++)CGContextFillEllipseInRect(c,CGRectMake(4+i*7,11,2,2)); }
    else if([name isEqual:@"play"] || [name isEqual:@"send"]) { CGContextMoveToPoint(c,6,4); CGContextAddLineToPoint(c,21,12); CGContextAddLineToPoint(c,6,20); CGContextClosePath(c); if([name isEqual:@"play"])CGContextFillPath(c); else { CGContextStrokePath(c); TGLine(c,6,12,17,12); } }
    else if([name isEqual:@"pause"]) { CGContextFillRect(c,CGRectMake(6,4,4,16)); CGContextFillRect(c,CGRectMake(14,4,4,16)); }
    else if([name isEqual:@"next"] || [name isEqual:@"previous"]) { BOOL prev=[name isEqual:@"previous"]; if(prev) { CGContextTranslateCTM(c,24,0); CGContextScaleCTM(c,-1,1); } CGContextMoveToPoint(c,5,5); CGContextAddLineToPoint(c,16,12); CGContextAddLineToPoint(c,5,19); CGContextClosePath(c); CGContextFillPath(c); TGLine(c,19,5,19,19); }
    else if([name isEqual:@"emoji"]) { CGContextStrokeEllipseInRect(c,CGRectMake(3,3,18,18)); CGContextFillEllipseInRect(c,CGRectMake(7,8,2,2)); CGContextFillEllipseInRect(c,CGRectMake(15,8,2,2)); CGContextMoveToPoint(c,7,14); CGContextAddCurveToPoint(c,9,18,15,18,17,14); }
    else if([name isEqual:@"microphone"]) { UIBezierPath *p=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(9,3,6,12) cornerRadius:3]; [p stroke]; CGContextMoveToPoint(c,5,10); CGContextAddCurveToPoint(c,5,22,19,22,19,10); TGLine(c,12,19,12,22); TGLine(c,8,22,16,22); }
    else if([name isEqual:@"attachment"]) { CGContextMoveToPoint(c,9,17); CGContextAddLineToPoint(c,16,10); CGContextAddCurveToPoint(c,19,7,15,4,12,7); CGContextAddLineToPoint(c,5,14); CGContextAddCurveToPoint(c,0,20,8,25,13,20); CGContextAddLineToPoint(c,21,12); }
    else if([name isEqual:@"group"]) { CGContextStrokeEllipseInRect(c,CGRectMake(7,4,6,6)); CGContextStrokeEllipseInRect(c,CGRectMake(16,5,5,5)); CGContextMoveToPoint(c,2,20); CGContextAddCurveToPoint(c,2,10,18,10,18,20); CGContextClosePath(c); CGContextStrokePath(c); CGContextMoveToPoint(c,16,13); CGContextAddCurveToPoint(c,22,12,23,16,23,20); }
    else if([name isEqual:@"person"] || [name isEqual:@"contacts"]) { CGContextStrokeEllipseInRect(c,CGRectMake(8,3,8,8)); CGContextMoveToPoint(c,4,21); CGContextAddCurveToPoint(c,4,12,20,12,20,21); CGContextAddLineToPoint(c,4,21); }
    else if([name isEqual:@"chat"]) { [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3,3,18,15) cornerRadius:5] stroke]; TGLine(c,7,18,5,22); CGContextAddLineToPoint(c,12,18); TGLine(c,7,8,17,8); TGLine(c,7,12,14,12); }
    else if([name isEqual:@"settings"]) { CGContextStrokeEllipseInRect(c,CGRectMake(9,9,6,6)); CGContextStrokeEllipseInRect(c,CGRectMake(4,4,16,16)); for(int i=0;i<8;i++) { double a=i*M_PI/4; TGLine(c,12+8*cos(a),12+8*sin(a),12+11*cos(a),12+11*sin(a)); } }
    else if([name isEqual:@"camera"] || [name isEqual:@"gallery"]) { [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2,6,20,15) cornerRadius:3] stroke]; if([name isEqual:@"camera"]) { CGContextStrokeEllipseInRect(c,CGRectMake(8,10,8,8)); TGLine(c,7,6,9,3); CGContextAddLineToPoint(c,15,3); CGContextAddLineToPoint(c,17,6); } else { CGContextStrokeEllipseInRect(c,CGRectMake(6,9,3,3)); TGLine(c,3,19,11,12); CGContextAddLineToPoint(c,17,19); } }
    else if([name isEqual:@"device"]) { [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3,4,18,13) cornerRadius:2] stroke]; TGLine(c,8,21,16,21); TGLine(c,12,17,12,21); }
    else if([name isEqual:@"file"]) { TGLine(c,5,3,15,3); CGContextAddLineToPoint(c,20,8); CGContextAddLineToPoint(c,20,21); CGContextAddLineToPoint(c,5,21); CGContextClosePath(c); TGLine(c,15,3,15,9); CGContextAddLineToPoint(c,20,9); }
    else if([name isEqual:@"music"]) { TGLine(c,9,17,9,5); CGContextAddLineToPoint(c,20,3); CGContextAddLineToPoint(c,20,15); TGLine(c,9,8,20,6); CGContextStrokePath(c); CGContextFillEllipseInRect(c,CGRectMake(3,16,6,5)); CGContextFillEllipseInRect(c,CGRectMake(14,14,6,5)); }
    else if([name isEqual:@"archive"]) { CGContextStrokeRect(c,CGRectMake(3,7,18,14)); CGContextStrokeRect(c,CGRectMake(2,3,20,4)); TGLine(c,9,12,15,12); }
    else if([name isEqual:@"trash"]) { TGLine(c,4,6,20,6); TGLine(c,6,6,7,21); CGContextAddLineToPoint(c,17,21); CGContextAddLineToPoint(c,18,6); TGLine(c,9,3,15,3); TGLine(c,10,10,10,17); TGLine(c,14,10,14,17); }
    else if([name isEqual:@"edit"]) { TGLine(c,4,20,5,15); CGContextAddLineToPoint(c,16,4); CGContextAddLineToPoint(c,20,8); CGContextAddLineToPoint(c,9,19); CGContextClosePath(c); TGLine(c,14,6,18,10); }
    else if([name isEqual:@"reply"] || [name isEqual:@"share"]) { BOOL share=[name isEqual:@"share"]; if(share){CGContextTranslateCTM(c,24,0);CGContextScaleCTM(c,-1,1);} TGLine(c,10,5,3,11); CGContextAddLineToPoint(c,10,17); CGContextMoveToPoint(c,3,11); CGContextAddCurveToPoint(c,19,8,20,17,21,20); }
    else if([name isEqual:@"copy"]) { [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8,7,13,14) cornerRadius:2] stroke]; TGLine(c,5,17,3,17); CGContextAddLineToPoint(c,3,3); CGContextAddLineToPoint(c,16,3); }
    else if([name isEqual:@"channel"]) { TGLine(c,3,9,8,9); CGContextAddLineToPoint(c,18,4); CGContextAddLineToPoint(c,18,20); CGContextAddLineToPoint(c,8,15); CGContextAddLineToPoint(c,3,15); CGContextClosePath(c); TGLine(c,8,15,9,21); TGLine(c,22,10,22,14); }
    else if([name isEqual:@"location"]) { CGContextMoveToPoint(c,12,22); CGContextAddCurveToPoint(c,4,12,4,7,6,5); CGContextAddCurveToPoint(c,9,1,15,1,18,5); CGContextAddCurveToPoint(c,20,7,20,12,12,22); CGContextClosePath(c); CGContextStrokePath(c); CGContextStrokeEllipseInRect(c,CGRectMake(9,7,6,6)); }
    else if([name isEqual:@"repeat"]) { TGLine(c,4,10,4,6); CGContextAddLineToPoint(c,20,6); TGLine(c,17,3,20,6); CGContextAddLineToPoint(c,17,9); TGLine(c,20,14,20,18); CGContextAddLineToPoint(c,4,18); TGLine(c,7,15,4,18); CGContextAddLineToPoint(c,7,21); }
    else if([name isEqual:@"shuffle"]) { TGLine(c,3,6,7,6); CGContextAddLineToPoint(c,17,18); CGContextAddLineToPoint(c,21,18); TGLine(c,3,18,7,18); CGContextAddLineToPoint(c,17,6); CGContextAddLineToPoint(c,21,6); TGLine(c,18,3,21,6); CGContextAddLineToPoint(c,18,9); }
    else if([name isEqual:@"lock"]) { [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5,10,14,11) cornerRadius:3] stroke]; CGContextMoveToPoint(c,8,10); CGContextAddCurveToPoint(c,6,0,18,0,16,10); }
    else if([name isEqual:@"bookmark"]) { TGLine(c,6,21,6,3); CGContextAddLineToPoint(c,18,3); CGContextAddLineToPoint(c,18,21); CGContextAddLineToPoint(c,12,17); CGContextClosePath(c); }
    else if([name isEqual:@"sticker"]) { [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3,3,18,18) cornerRadius:5] stroke]; TGLine(c,21,13,14,14); CGContextAddLineToPoint(c,13,21); }
    else if([name isEqual:@"muted"]) { TGLine(c,3,10,7,10); CGContextAddLineToPoint(c,12,5); CGContextAddLineToPoint(c,12,19); CGContextAddLineToPoint(c,7,14); CGContextAddLineToPoint(c,3,14); CGContextClosePath(c); TGLine(c,17,9,22,14); TGLine(c,22,9,17,14); }
    else { CGContextStrokeEllipseInRect(c,CGRectMake(4,4,16,16)); TGLine(c,12,10,12,17); CGContextFillEllipseInRect(c,CGRectMake(11,6,2,2)); }
    CGContextStrokePath(c); image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); if(image)[cache setObject:image forKey:key]; return image;
}
UIImage *RT7Asset(NSString *path, UIImage *original) {
    if(!original)return nil; NSString *n=[[path lastPathComponent] stringByDeletingPathExtension];
    BOOL legacy=[path hasPrefix:@"OriginalTelegram/"] || [path hasPrefix:@"Telegram27/"] || [path hasPrefix:@"UI7Theme/"] || [path hasPrefix:@"NewTelegram/"] || [path hasPrefix:@"Modern"] || [path hasPrefix:@"StickerKeyboard/"] || [n hasPrefix:@"Input"];
    if(!legacy)return original;
    if([n rangeOfString:@"Background"].location!=NSNotFound || [n rangeOfString:@"Linen" options:NSCaseInsensitiveSearch].location!=NSNotFound || [n hasPrefix:@"Header"] || [n hasPrefix:@"LoginHeader"] || [n hasPrefix:@"GalleryTopPanel"] || [n hasPrefix:@"GalleryBottomPanel"] || [n hasPrefix:@"ImagePickerPanel"] || [n hasPrefix:@"ConversationInputPanel"] || [n hasPrefix:@"ToolbarBackground"]) return RT7Shape(original.size,RT7Canvas(),0);
    if([n rangeOfString:@"Shadow"].location!=NSNotFound || [n hasSuffix:@"_Corners"] || [n hasPrefix:@"BackButton"] || [n hasPrefix:@"HeaderButton"] || [n hasPrefix:@"SendButton"] || [n hasPrefix:@"MenuGrayButton"] || [n hasPrefix:@"MenuRedButton"] || [n hasPrefix:@"LoginButton"] || [n hasPrefix:@"ActionMenuButton"] || [n hasPrefix:@"GroupedAction"] || [n hasPrefix:@"ImagePickerBlueButton"] || [n hasPrefix:@"ImagePickerGrayButton"]) return RT7Shape(original.size,[UIColor clearColor],0);
    if([n hasPrefix:@"GroupedCell"] || [n hasPrefix:@"TableCell"] || [n hasPrefix:@"ContactCell"] || [n hasPrefix:@"CellHighlighted"] || [n hasPrefix:@"Cell88"]) return RT7Shape(original.size,RT7Surface(),0);
    if([n rangeOfString:@"InputField"].location!=NSNotFound || [n hasPrefix:@"LoginInput"] || [n isEqual:@"ModernConversationInput"]) return RT7Shape(original.size,RT7SurfaceVariant(),MIN(16,original.size.height/2));
    NSDictionary *map=@{@"TabIconContacts":@"contacts",@"TabIconMessages":@"chat",@"TabIconSettings":@"settings",@"TabContacts":@"contacts",@"TabChats":@"chat",@"TabSettings":@"settings",@"ModernConversationAttach":@"attachment",@"ModernConversationMicButton":@"microphone",@"ModernNavigationAddButtonIcon":@"add",@"ModernNavigationComposeButtonIcon":@"edit",@"ModernListsDisclosureIndicator":@"chevron",@"MenuDisclosureIndicator":@"chevron",@"InputSend":@"send",@"InputVoiceRecord":@"microphone",@"InputAttach":@"add",@"Emoji":@"emoji",@"Sticker":@"sticker",@"Attachment":@"attachment",@"Muted":@"muted",@"Check":@"check",@"MusicPlayerControlPlay":@"play",@"MusicPlayerControlPause":@"pause",@"MusicPlayerControlPrevious":@"previous",@"MusicPlayerControlNext":@"next",@"MusicPlayerControlRepeat":@"repeat",@"MusicPlayerControlShuffle":@"shuffle",@"MusicPlayerControlShare":@"share"};
    NSString *base=[n componentsSeparatedByString:@"_"].firstObject; NSString *icon=map[n] ?: map[base];
    if(!icon) { if([n hasPrefix:@"TabContacts"])icon=@"contacts"; else if([n hasPrefix:@"TabChats"])icon=@"chat"; else if([n hasPrefix:@"TabSettings"])icon=@"settings"; else if([n hasPrefix:@"Emoji"])icon=@"emoji"; else if([n hasPrefix:@"MessageCheck"])icon=@"check"; else if([n hasPrefix:@"ModernConversationMic"])icon=@"microphone"; }
    if([n hasPrefix:@"ImagePickerSelect"] || [n hasPrefix:@"ModernContactSelection"] || [n hasPrefix:@"ImagePickerThumbnalSelect"]) {
        BOOL checked=[n rangeOfString:@"Checked"].location!=NSNotFound; CGFloat side=MAX(28,MIN(original.size.width,original.size.height));
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(side,side),NO,0); CGRect circle=CGRectInset(CGRectMake(0,0,side,side),3,3);
        UIBezierPath *p=[UIBezierPath bezierPathWithOvalInRect:circle]; [checked ? RT7Primary() : [RT7Text() colorWithAlphaComponent:.24] setFill]; [p fill]; [RT7OnPrimary() setStroke]; p.lineWidth=2; [p stroke];
        if(checked)[RT7Icon(@"check",side-12,RT7OnPrimary()) drawInRect:CGRectInset(circle,3,3)]; UIImage *mark=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return mark;
    }
    if(!icon) {
        NSDictionary *parts=@{@"Camera":@"camera",@"Photo":@"gallery",@"Stickers":@"sticker",@"Wallpaper":@"gallery",@"Privacy":@"lock",@"Passport":@"person",@"Watch":@"device",@"Devices":@"device",@"Data":@"file",@"Support":@"chat",@"Notifications":@"settings",@"Proxy":@"settings",@"Search":@"search",@"Compose":@"edit",@"AddMember":@"group",@"NewGroup":@"group",@"Invite":@"person",@"Encrypted":@"lock",@"Disclosure":@"chevron",@"RecordVideo":@"camera",@"Microphone":@"microphone",@"Favorite":@"bookmark",@"Recent":@"music",@"Keyboard":@"chat",@"Delete":@"back",@"GIF":@"gallery"};
        if([n rangeOfString:@"Icon"].location!=NSNotFound || [n hasPrefix:@"Settings"] || [n hasPrefix:@"Modern"] || [path hasPrefix:@"StickerKeyboard/"]) {
            for(NSString *part in parts)if([n rangeOfString:part options:NSCaseInsensitiveSearch].location!=NSNotFound){ icon=parts[part]; break; }
        }
    }
    if([n rangeOfString:@"AvatarPlaceholder"].location!=NSNotFound || [n isEqual:@"SettingsAddPhoto"] || [n hasPrefix:@"ProfilePhotoPlaceholder"]) {
        CGSize size=original.size; UIGraphicsBeginImageContextWithOptions(size,NO,0); [RT7PrimaryContainer() setFill]; [[UIBezierPath bezierPathWithOvalInRect:(CGRect){CGPointZero,size}] fill]; CGFloat d=MIN(size.width,size.height)*.55; [RT7Icon(@"person",d,RT7Primary()) drawInRect:CGRectMake((size.width-d)/2,(size.height-d)/2,d,d)]; UIImage *avatar=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return avatar;
    }
    if(icon)return RT7Icon(icon,MIN(28,MAX(18,MIN(original.size.width,original.size.height))),RT7Primary());
    return RT7Shape(original.size,[UIColor clearColor],0);
}
void RT7Animate(CALayer *layer, NSString *key, id from, id to, NSTimeInterval duration) {
    CABasicAnimation *animation=[CABasicAnimation animationWithKeyPath:key]; animation.fromValue=from; animation.toValue=to; animation.duration=duration; animation.timingFunction=[CAMediaTimingFunction functionWithControlPoints:.2 :.0 :.0 :1];
    [layer addAnimation:animation forKey:[@"material." stringByAppendingString:key]];
}
void RT7SlidePanel(UIView *panel, UIView *scrim, BOOL show, void (^completion)(void)) {
    CGFloat distance=MAX(panel.bounds.size.height,panel.superview.bounds.size.height-CGRectGetMinY(panel.frame));
    // Animate the composited layer directly. Never render tables into a bitmap.
    panel.userInteractionEnabled=NO;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    [CATransaction setCompletionBlock:^{ panel.userInteractionEnabled=YES; if(completion)completion(); }];
    CATransform3D start=show ? CATransform3DMakeTranslation(0,distance,0) : CATransform3DIdentity;
    CATransform3D end=show ? CATransform3DIdentity : CATransform3DMakeTranslation(0,distance,0);
    panel.layer.transform=end; scrim.layer.opacity=show ? 1 : 0;
    RT7Animate(panel.layer,@"transform",[NSValue valueWithCATransform3D:start],[NSValue valueWithCATransform3D:end],show ? .28 : .22);
    RT7Animate(scrim.layer,@"opacity",@(show ? 0 : 1),@(show ? 1 : 0),.22);
    [CATransaction commit];
}
// Geometry and colors follow UI7Kit's public UIKit presentation, without its private patches.
void RT7ConfigureSlider(UISlider *slider) {
    UIImage *thumb=RT7Shape(CGSizeMake(28,28),[UIColor whiteColor],14);
    UIImage *active=[RT7Shape(CGSizeMake(4,2),RT7Primary(),0) resizableImageWithCapInsets:UIEdgeInsetsMake(0,1,0,1)];
    UIImage *track=[RT7Shape(CGSizeMake(4,2),RT7SurfaceVariant(),0) resizableImageWithCapInsets:UIEdgeInsetsMake(0,1,0,1)];
    for(NSNumber *state in @[@0,@1,@2]) { [slider setThumbImage:thumb forState:state.integerValue]; [slider setMinimumTrackImage:active forState:state.integerValue]; [slider setMaximumTrackImage:track forState:state.integerValue]; }
}
UIImage *RT7ImageNamed(NSString *name) {
    if(!name.length)return nil;
    static NSCache *cache; static dispatch_once_t once; dispatch_once(&once,^{cache=[[NSCache alloc] init]; cache.countLimit=256;});
    UIImage *image=[cache objectForKey:name]; if(image)return image;
    image=RT7Asset(name,[UIImage imageNamed:name]); if(image)[cache setObject:image forKey:name]; return image;
}
@implementation RT7Button
+ (instancetype)buttonWithType:(UIButtonType)type { return [[self alloc] initWithFrame:CGRectZero]; }
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) { self.titleLabel.font=RT7Font(17,NO); self.exclusiveTouch=YES; [self setTitleColor:RT7Primary() forState:UIControlStateNormal]; [self setTitleColor:RT7SecondaryText() forState:UIControlStateDisabled]; }
    return self;
}
- (void)setHighlighted:(BOOL)value { [super setHighlighted:value]; self.alpha=value ? .4 : self.enabled ? 1 : .35; }
- (void)setEnabled:(BOOL)value { [super setEnabled:value]; self.alpha=value ? 1 : .35; }
@end
@implementation RT7TextField
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:frame])) { self.font=RT7Font(17,NO); self.textColor=RT7Text(); self.backgroundColor=RT7Surface(); self.borderStyle=UITextBorderStyleNone; self.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter; } return self; }
- (CGRect)textRectForBounds:(CGRect)bounds { CGFloat left=self.leftView && self.leftViewMode==UITextFieldViewModeAlways ? self.leftView.bounds.size.width : 15; CGFloat right=self.clearButtonMode!=UITextFieldViewModeNever && self.isEditing && self.text.length ? 32 : 15; return CGRectMake(bounds.origin.x+left,bounds.origin.y,MAX(0,bounds.size.width-left-right),bounds.size.height); }
- (CGRect)editingRectForBounds:(CGRect)bounds { return [self textRectForBounds:bounds]; }
- (CGRect)placeholderRectForBounds:(CGRect)bounds { return [self textRectForBounds:bounds]; }
@end
@implementation RT7Switch
- (instancetype)init { return [self initWithFrame:CGRectMake(0,0,51,31)]; }
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:CGRectMake(frame.origin.x,frame.origin.y,51,31)])) {
        self.onTintColor=[UIColor colorWithRed:76/255.0 green:217/255.0 blue:100/255.0 alpha:1]; self.borderColor=RT7SurfaceVariant(); self.inactiveColor=RT7SurfaceVariant(); self.thumbTintColor=[UIColor whiteColor]; self.shadowColor= nil;
    } return self;
}
@end
void RT7PrepareScreen(UIViewController *controller) {
    UINavigationBar *bar=controller.navigationController.navigationBar; if(!bar)return;
    bar.translucent=NO; bar.tintColor=RT7Primary();
    [bar setBackgroundImage:RT7Shape(CGSizeMake(2,2),[UIColor colorWithWhite:.98 alpha:1],0) forBarMetrics:UIBarMetricsDefault];
    if([bar respondsToSelector:@selector(setShadowImage:)])bar.shadowImage=RT7Shape(CGSizeMake(1,1),RT7Outline(),0);
    bar.titleTextAttributes=@{UITextAttributeTextColor:RT7Text(),UITextAttributeFont:RT7Font(17,YES),UITextAttributeTextShadowColor:[UIColor clearColor],UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetZero]};
}
@implementation RT7ListCell { UITableViewCellStyle _rowStyle; UILabel *_title,*_detail; UIImageView *_icon,*_chevron; UIView *_accessory; UITableViewCellAccessoryType _accessoryType7; CALayer *_divider; }
- (UILabel *)textLabel { return _title; }
- (UILabel *)detailTextLabel { return _detail; }
- (UIImageView *)imageView { return _icon; }
- (UIView *)accessoryView { return _accessory; }
- (UITableViewCellAccessoryType)accessoryType { return _accessoryType7; }
- (void)setAccessoryType:(UITableViewCellAccessoryType)type { _accessoryType7=type; [self setNeedsLayout]; }
- (void)setAccessoryView:(UIView *)view { if(view==_accessory)return; [_accessory removeFromSuperview]; _accessory=view; if(view)[self.contentView addSubview:view]; [self setNeedsLayout]; }
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if((self=[super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])) { _rowStyle=style; _cardInset=0; self.backgroundColor=RT7Surface(); self.backgroundView=nil; UIView *selected=[[UIView alloc] init]; selected.backgroundColor=[UIColor colorWithWhite:.9 alpha:1]; self.selectedBackgroundView=selected;
        [super textLabel].hidden=YES; [super detailTextLabel].hidden=YES; [super imageView].hidden=YES;
        _title=[[UILabel alloc] init]; _title.font=RT7Font(17,NO); _title.textColor=RT7Text(); _title.backgroundColor=[UIColor clearColor];
        _detail=[[UILabel alloc] init]; _detail.font=RT7Font(15,NO); _detail.textColor=RT7SecondaryText(); _detail.backgroundColor=[UIColor clearColor]; _icon=[[UIImageView alloc] init]; _icon.contentMode=UIViewContentModeScaleAspectFit; _chevron=[[UIImageView alloc] init];
        for(UIView *view in @[_title,_detail,_icon,_chevron])[self.contentView addSubview:view];
        _divider=[CALayer layer]; [self.contentView.layer addSublayer:_divider];
    } return self;
}
- (void)setFirstInGroup:(BOOL)value { _firstInGroup=value; [self setNeedsLayout]; }
- (void)setLastInGroup:(BOOL)value { _lastInGroup=value; [self setNeedsLayout]; }
- (void)setCardInset:(CGFloat)value { _cardInset=0; [self setNeedsLayout]; }
- (void)layoutSubviews {
    [super layoutSubviews]; self.contentView.frame=self.bounds; CGFloat w=self.bounds.size.width,h=self.bounds.size.height,left=15,right=w-15;
    BOOL chevron=!_accessory && _accessoryType7!=UITableViewCellAccessoryNone; _chevron.hidden=!chevron;
    if(chevron) { _chevron.image=RT7Icon(_accessoryType7==UITableViewCellAccessoryCheckmark ? @"check" : @"chevron",16,_accessoryType7==UITableViewCellAccessoryCheckmark ? RT7Primary() : RT7Outline()); _chevron.frame=CGRectMake(w-29,(h-16)/2,16,16); right-=25; }
    if(_accessory) { CGSize size=_accessory.bounds.size; if(size.width<1 || size.height<1)size=[_accessory sizeThatFits:CGSizeMake(120,h)]; _accessory.frame=CGRectMake(right-size.width,(h-size.height)/2,size.width,size.height); right-=size.width+12; }
    _icon.hidden=!_icon.image; if(_icon.image) { _icon.frame=CGRectMake(15,(h-29)/2,29,29); left=59; }
    CGFloat detail=_rowStyle==UITableViewCellStyleValue1 ? MIN(MAX(0,(right-left)*.45),[_detail sizeThatFits:CGSizeMake(140,h)].width) : 0;
    if(_rowStyle==UITableViewCellStyleSubtitle && _detail.text.length) { _title.frame=CGRectMake(left,(h-41)/2,MAX(0,right-left),23); _detail.frame=CGRectMake(left,(h-41)/2+23,MAX(0,right-left),18); }
    else { _title.frame=CGRectMake(left,0,MAX(0,right-left-(detail ? detail+8 : 0)),h); _detail.frame=CGRectMake(right-detail,0,detail,h); }
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _divider.hidden=self.lastInGroup; _divider.backgroundColor=RT7Outline().CGColor; _divider.frame=CGRectMake(left,h-1/[UIScreen mainScreen].scale,MAX(0,w-left),1/[UIScreen mainScreen].scale); [CATransaction commit];
}
@end
@implementation RT7Slider
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:frame]))RT7ConfigureSlider(self); return self; }
@end
@implementation RT7SegmentedControl
- (instancetype)initWithItems:(NSArray *)items { if((self=[super initWithItems:items])) { self.tintColor=RT7Primary(); self.layer.cornerRadius=4; self.layer.borderColor=RT7Primary().CGColor; self.layer.borderWidth=1; self.clipsToBounds=YES; UIImage *clear=RT7Shape(CGSizeMake(2,2),[UIColor clearColor],0); [self setBackgroundImage:clear forState:UIControlStateNormal barMetrics:UIBarMetricsDefault]; [self setBackgroundImage:RT7Shape(CGSizeMake(2,2),RT7Primary(),0) forState:UIControlStateSelected barMetrics:UIBarMetricsDefault]; [self setDividerImage:RT7Shape(CGSizeMake(1,1),RT7Primary(),0) forLeftSegmentState:0 rightSegmentState:0 barMetrics:UIBarMetricsDefault]; [self setTitleTextAttributes:@{UITextAttributeFont:RT7Font(13,NO),UITextAttributeTextColor:RT7Primary(),UITextAttributeTextShadowColor:[UIColor clearColor]} forState:UIControlStateNormal]; [self setTitleTextAttributes:@{UITextAttributeTextColor:[UIColor whiteColor]} forState:UIControlStateSelected]; } return self; }
@end
@implementation RT7BarButtonItem
- (instancetype)initWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action {
    RT7Button *button=[[RT7Button alloc] initWithFrame:CGRectMake(0,0,MAX(40,MIN(160,ceil([title sizeWithFont:RT7Font(17,NO)].width)+8)),40)]; [button setTitle:title forState:UIControlStateNormal]; [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside]; return [super initWithCustomView:button];
}
- (instancetype)initWithImage:(UIImage *)image style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action { RT7Button *button=[[RT7Button alloc] initWithFrame:CGRectMake(0,0,36,40)]; [button setImage:image forState:UIControlStateNormal]; [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside]; return [super initWithCustomView:button]; }
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)item target:(id)target action:(SEL)action {
    NSString *icon=item==UIBarButtonSystemItemAdd ? @"add" : item==UIBarButtonSystemItemCompose ? @"edit" : item==UIBarButtonSystemItemSearch ? @"search" : item==UIBarButtonSystemItemTrash ? @"trash" : item==UIBarButtonSystemItemStop ? @"close" : nil;
    if(icon)return [self initWithImage:RT7Icon(icon,24,RT7Primary()) style:UIBarButtonItemStylePlain target:target action:action];
    NSString *title=item==UIBarButtonSystemItemRefresh ? @"Обновить" : item==UIBarButtonSystemItemCancel ? @"Отмена" : item==UIBarButtonSystemItemDone ? @"Готово" : item==UIBarButtonSystemItemEdit ? @"Изм." : item==UIBarButtonSystemItemSave ? @"Сохранить" : @"Далее";
    return [self initWithTitle:title style:UIBarButtonItemStylePlain target:target action:action];
}
- (void)setEnabled:(BOOL)value { [super setEnabled:value]; if([self.customView isKindOfClass:[UIControl class]])((UIControl *)self.customView).enabled=value; }
- (void)setTitle:(NSString *)title { [super setTitle:title]; if([self.customView isKindOfClass:[UIButton class]])[(UIButton *)self.customView setTitle:title forState:UIControlStateNormal]; }
@end
@implementation RT7SearchBar
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:frame])) { self.backgroundImage=RT7Shape(CGSizeMake(2,2),[UIColor colorWithWhite:.98 alpha:1],0); self.tintColor=RT7Primary(); [self setSearchFieldBackgroundImage:[RT7Shape(CGSizeMake(20,20),RT7SurfaceVariant(),5) resizableImageWithCapInsets:UIEdgeInsetsMake(6,6,6,6)] forState:UIControlStateNormal]; [self setImage:RT7Icon(@"search",16,RT7SecondaryText()) forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal]; } return self; }
@end
@implementation RT7TableView
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style { if((self=[super initWithFrame:frame style:UITableViewStylePlain])) { extern void TGUI7RecordGroupedTable(id,BOOL); TGUI7RecordGroupedTable(self,style==UITableViewStyleGrouped); self.backgroundView=nil; self.backgroundColor=style==UITableViewStyleGrouped ? RT7Canvas() : RT7Surface(); self.separatorStyle=UITableViewCellSeparatorStyleNone; self.rowHeight=44; } return self; }
@end
@implementation RT7TableController { UITableViewStyle _requestedStyle; }
- (instancetype)initWithStyle:(UITableViewStyle)style { if((self=[super initWithStyle:style]))_requestedStyle=style; return self; }
- (void)loadView { self.tableView=[[RT7TableView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame style:_requestedStyle]; self.tableView.dataSource=self; self.tableView.delegate=self; self.view=self.tableView; if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])self.edgesForExtendedLayout=0; if([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)])self.automaticallyAdjustsScrollViewInsets=NO; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; RT7PrepareScreen(self); }
@end
extern BOOL TGPresentLegacyFlatDialog(id,BOOL);
extern BOOL TGDismissLegacyFlatDialog(id,NSInteger,BOOL);
static char RT7DialogKey;
void TGAssociateFlatDialog(id owner,id dialog) { objc_setAssociatedObject(owner,&RT7DialogKey,dialog,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@implementation RT7AlertView
- (void)show { TGPresentLegacyFlatDialog(self,NO); }
- (BOOL)isVisible { return objc_getAssociatedObject(self,&RT7DialogKey)!=nil; }
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated { TGDismissLegacyFlatDialog(objc_getAssociatedObject(self,&RT7DialogKey),index,animated); }
@end
@implementation RT7ActionSheet
- (void)showInView:(UIView *)view { TGPresentLegacyFlatDialog(self,YES); }
- (void)showFromTabBar:(UITabBar *)bar { [self showInView:bar]; }
- (void)showFromToolbar:(UIToolbar *)bar { [self showInView:bar]; }
- (BOOL)isVisible { return objc_getAssociatedObject(self,&RT7DialogKey)!=nil; }
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated { TGDismissLegacyFlatDialog(objc_getAssociatedObject(self,&RT7DialogKey),index,animated); }
@end

@implementation RT7TabBarItem { NSString *_sevenBadge; }
- (NSString *)badgeValue { return _sevenBadge; }
- (void)setBadgeValue:(NSString *)value { _sevenBadge=[value copy]; [super setBadgeValue:nil]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RT7TabBadgeChanged" object:self]; }
@end
