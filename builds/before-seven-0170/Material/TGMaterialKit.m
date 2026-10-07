#import "TGMaterialKit.h"
#import <objc/runtime.h>
#include <math.h>

static UIColor *TGColor(unsigned int hex) { return [UIColor colorWithRed:((hex>>16)&255)/255.0 green:((hex>>8)&255)/255.0 blue:(hex&255)/255.0 alpha:1]; }
UIColor *TGMaterialPrimary(void) { return TGColor(0x6750A4); }
UIColor *TGMaterialOnPrimary(void) { return TGColor(0xFFFFFF); }
UIColor *TGMaterialPrimaryContainer(void) { return TGColor(0xEADDFF); }
UIColor *TGMaterialSurface(void) { return TGColor(0xFFFBFE); }
UIColor *TGMaterialCanvas(void) { return TGColor(0xF7F2FA); }
UIColor *TGMaterialSurfaceVariant(void) { return TGColor(0xECE6F0); }
UIColor *TGMaterialText(void) { return TGColor(0x1D1B20); }
UIColor *TGMaterialSecondaryText(void) { return TGColor(0x625B71); }
UIColor *TGMaterialOutline(void) { return TGColor(0xCAC4D0); }
UIColor *TGMaterialError(void) { return TGColor(0xB3261E); }
UIColor *TGMaterialBubbleColor(NSInteger index) { unsigned int colors[]={0xEADDFF,0xD6EDD0,0xD8E2FF,0xFFD9E4,0xE8DEFF,0xF5E3A3,0xFFDBC9}; return TGColor(colors[MAX(0,MIN(6,index))]); }
UIImage *TGMaterialWallpaper(NSInteger index) {
 static NSArray *images; static dispatch_once_t once; dispatch_once(&once,^{
 NSMutableArray *items=[NSMutableArray array];
 for(NSInteger i=0;i<3;i++) {
  CGSize size=CGSizeMake(320,568); UIGraphicsBeginImageContextWithOptions(size,YES,0); [i==1 ? TGMaterialSurface() : TGMaterialCanvas() setFill]; UIRectFill((CGRect){CGPointZero,size});
  if(i==2) { [[TGMaterialPrimaryContainer() colorWithAlphaComponent:.55] setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-140,-110,420,420)] fill]; [[TGMaterialSurfaceVariant() colorWithAlphaComponent:.7] setFill]; [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(135,320,270,270) cornerRadius:90] fill]; }
  [items addObject:UIGraphicsGetImageFromCurrentImageContext()]; UIGraphicsEndImageContext();
 }
 images=[items copy]; }); return images[MAX(0,MIN(2,index))];
}
UIFont *TGMaterialFont(CGFloat size, BOOL medium) { return [UIFont fontWithName:medium ? @"HelveticaNeue-Medium" : @"HelveticaNeue" size:size] ?: [UIFont systemFontOfSize:size]; }

UIImage *TGMaterialShape(CGSize size, UIColor *color, CGFloat radius) {
    size.width=MAX(2,size.width); size.height=MAX(2,size.height);
    UIGraphicsBeginImageContextWithOptions(size,NO,0);
    [color setFill]; [[UIBezierPath bezierPathWithRoundedRect:(CGRect){CGPointZero,size} cornerRadius:MIN(radius,MIN(size.width,size.height)/2)] fill];
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image;
}
static void TGLine(CGContextRef ctx, CGFloat x, CGFloat y, CGFloat dx, CGFloat dy) { CGContextMoveToPoint(ctx,x,y); CGContextAddLineToPoint(ctx,dx,dy); }
UIImage *TGMaterialIcon(NSString *name, CGFloat size, UIColor *color) {
    static NSCache *cache; static dispatch_once_t once; dispatch_once(&once,^{ cache=[[NSCache alloc] init]; cache.countLimit=180; });
    NSString *key=[NSString stringWithFormat:@"%@/%g/%@",name,size,color]; UIImage *image=[cache objectForKey:key]; if(image)return image;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size,size),NO,0); CGContextRef c=UIGraphicsGetCurrentContext(); CGContextScaleCTM(c,size/24,size/24);
    CGContextSetStrokeColorWithColor(c,color.CGColor); CGContextSetFillColorWithColor(c,color.CGColor); CGContextSetLineWidth(c,1.8); CGContextSetLineCap(c,kCGLineCapRound); CGContextSetLineJoin(c,kCGLineJoinRound);
    if([name isEqual:@"close"]) { TGLine(c,6,6,18,18); TGLine(c,18,6,6,18); }
    else if([name isEqual:@"back"]) { TGLine(c,20,12,4,12); TGLine(c,4,12,11,5); TGLine(c,4,12,11,19); }
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
UIImage *TGMaterialAsset(NSString *path, UIImage *original) {
    if(!original)return nil; NSString *n=[[path lastPathComponent] stringByDeletingPathExtension];
    BOOL legacy=[path hasPrefix:@"OriginalTelegram/"] || [path hasPrefix:@"Telegram27/"] || [path hasPrefix:@"UI7Theme/"] || [path hasPrefix:@"NewTelegram/"] || [path hasPrefix:@"Modern"] || [path hasPrefix:@"StickerKeyboard/"] || [n hasPrefix:@"Input"];
    if(!legacy)return original;
    if([n rangeOfString:@"Background"].location!=NSNotFound || [n rangeOfString:@"Linen" options:NSCaseInsensitiveSearch].location!=NSNotFound || [n hasPrefix:@"Header"] || [n hasPrefix:@"LoginHeader"] || [n hasPrefix:@"GalleryTopPanel"] || [n hasPrefix:@"GalleryBottomPanel"] || [n hasPrefix:@"ImagePickerPanel"] || [n hasPrefix:@"ConversationInputPanel"] || [n hasPrefix:@"ToolbarBackground"]) return TGMaterialShape(original.size,TGMaterialCanvas(),0);
    if([n rangeOfString:@"Shadow"].location!=NSNotFound || [n hasSuffix:@"_Corners"] || [n hasPrefix:@"BackButton"] || [n hasPrefix:@"HeaderButton"] || [n hasPrefix:@"SendButton"] || [n hasPrefix:@"MenuGrayButton"] || [n hasPrefix:@"MenuRedButton"] || [n hasPrefix:@"LoginButton"] || [n hasPrefix:@"ActionMenuButton"] || [n hasPrefix:@"GroupedAction"] || [n hasPrefix:@"ImagePickerBlueButton"] || [n hasPrefix:@"ImagePickerGrayButton"]) return TGMaterialShape(original.size,[UIColor clearColor],0);
    if([n hasPrefix:@"GroupedCell"] || [n hasPrefix:@"TableCell"] || [n hasPrefix:@"ContactCell"] || [n hasPrefix:@"CellHighlighted"] || [n hasPrefix:@"Cell88"]) return TGMaterialShape(original.size,TGMaterialSurface(),0);
    if([n rangeOfString:@"InputField"].location!=NSNotFound || [n hasPrefix:@"LoginInput"] || [n isEqual:@"ModernConversationInput"]) return TGMaterialShape(original.size,TGMaterialSurfaceVariant(),MIN(16,original.size.height/2));
    NSDictionary *map=@{@"TabIconContacts":@"contacts",@"TabIconMessages":@"chat",@"TabIconSettings":@"settings",@"TabContacts":@"contacts",@"TabChats":@"chat",@"TabSettings":@"settings",@"ModernConversationAttach":@"attachment",@"ModernConversationMicButton":@"microphone",@"ModernNavigationAddButtonIcon":@"add",@"ModernNavigationComposeButtonIcon":@"edit",@"ModernListsDisclosureIndicator":@"chevron",@"MenuDisclosureIndicator":@"chevron",@"InputSend":@"send",@"InputVoiceRecord":@"microphone",@"InputAttach":@"add",@"Emoji":@"emoji",@"Sticker":@"sticker",@"Attachment":@"attachment",@"Muted":@"muted",@"Check":@"check",@"MusicPlayerControlPlay":@"play",@"MusicPlayerControlPause":@"pause",@"MusicPlayerControlPrevious":@"previous",@"MusicPlayerControlNext":@"next",@"MusicPlayerControlRepeat":@"repeat",@"MusicPlayerControlShuffle":@"shuffle",@"MusicPlayerControlShare":@"share"};
    NSString *base=[n componentsSeparatedByString:@"_"].firstObject; NSString *icon=map[n] ?: map[base];
    if(!icon) { if([n hasPrefix:@"TabContacts"])icon=@"contacts"; else if([n hasPrefix:@"TabChats"])icon=@"chat"; else if([n hasPrefix:@"TabSettings"])icon=@"settings"; else if([n hasPrefix:@"Emoji"])icon=@"emoji"; else if([n hasPrefix:@"MessageCheck"])icon=@"check"; else if([n hasPrefix:@"ModernConversationMic"])icon=@"microphone"; }
    if([n hasPrefix:@"ImagePickerSelect"] || [n hasPrefix:@"ModernContactSelection"] || [n hasPrefix:@"ImagePickerThumbnalSelect"]) {
        BOOL checked=[n rangeOfString:@"Checked"].location!=NSNotFound; CGFloat side=MAX(28,MIN(original.size.width,original.size.height));
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(side,side),NO,0); CGRect circle=CGRectInset(CGRectMake(0,0,side,side),3,3);
        UIBezierPath *p=[UIBezierPath bezierPathWithOvalInRect:circle]; [checked ? TGMaterialPrimary() : [TGMaterialText() colorWithAlphaComponent:.24] setFill]; [p fill]; [TGMaterialOnPrimary() setStroke]; p.lineWidth=2; [p stroke];
        if(checked)[TGMaterialIcon(@"check",side-12,TGMaterialOnPrimary()) drawInRect:CGRectInset(circle,3,3)]; UIImage *mark=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return mark;
    }
    if(!icon) {
        NSDictionary *parts=@{@"Camera":@"camera",@"Photo":@"gallery",@"Stickers":@"sticker",@"Wallpaper":@"gallery",@"Privacy":@"lock",@"Passport":@"person",@"Watch":@"device",@"Devices":@"device",@"Data":@"file",@"Support":@"chat",@"Notifications":@"settings",@"Proxy":@"settings",@"Search":@"search",@"Compose":@"edit",@"AddMember":@"group",@"NewGroup":@"group",@"Invite":@"person",@"Encrypted":@"lock",@"Disclosure":@"chevron",@"RecordVideo":@"camera",@"Microphone":@"microphone",@"Favorite":@"bookmark",@"Recent":@"music",@"Keyboard":@"chat",@"Delete":@"back",@"GIF":@"gallery"};
        if([n rangeOfString:@"Icon"].location!=NSNotFound || [n hasPrefix:@"Settings"] || [n hasPrefix:@"Modern"] || [path hasPrefix:@"StickerKeyboard/"]) {
            for(NSString *part in parts)if([n rangeOfString:part options:NSCaseInsensitiveSearch].location!=NSNotFound){ icon=parts[part]; break; }
        }
    }
    if([n rangeOfString:@"AvatarPlaceholder"].location!=NSNotFound || [n isEqual:@"SettingsAddPhoto"] || [n hasPrefix:@"ProfilePhotoPlaceholder"]) {
        CGSize size=original.size; UIGraphicsBeginImageContextWithOptions(size,NO,0); [TGMaterialPrimaryContainer() setFill]; [[UIBezierPath bezierPathWithOvalInRect:(CGRect){CGPointZero,size}] fill]; CGFloat d=MIN(size.width,size.height)*.55; [TGMaterialIcon(@"person",d,TGMaterialPrimary()) drawInRect:CGRectMake((size.width-d)/2,(size.height-d)/2,d,d)]; UIImage *avatar=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return avatar;
    }
    if(icon)return TGMaterialIcon(icon,MIN(28,MAX(18,MIN(original.size.width,original.size.height))),TGMaterialPrimary());
    return original;
}
void TGMaterialAnimate(CALayer *layer, NSString *key, id from, id to, NSTimeInterval duration) {
    CABasicAnimation *animation=[CABasicAnimation animationWithKeyPath:key]; animation.fromValue=from; animation.toValue=to; animation.duration=duration; animation.timingFunction=[CAMediaTimingFunction functionWithControlPoints:.2 :.0 :.0 :1];
    [layer addAnimation:animation forKey:[@"material." stringByAppendingString:key]];
}
void TGMaterialSlidePanel(UIView *panel, UIView *scrim, BOOL show, void (^completion)(void)) {
    CGFloat distance=MAX(panel.bounds.size.height,panel.superview.bounds.size.height-CGRectGetMinY(panel.frame));
    // Animate the composited layer directly. Never render tables into a bitmap.
    panel.userInteractionEnabled=NO;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    [CATransaction setCompletionBlock:^{ panel.userInteractionEnabled=YES; if(completion)completion(); }];
    CATransform3D start=show ? CATransform3DMakeTranslation(0,distance,0) : CATransform3DIdentity;
    CATransform3D end=show ? CATransform3DIdentity : CATransform3DMakeTranslation(0,distance,0);
    panel.layer.transform=end; scrim.layer.opacity=show ? 1 : 0;
    TGMaterialAnimate(panel.layer,@"transform",[NSValue valueWithCATransform3D:start],[NSValue valueWithCATransform3D:end],show ? .28 : .22);
    TGMaterialAnimate(scrim.layer,@"opacity",@(show ? 0 : 1),@(show ? 1 : 0),.22);
    [CATransaction commit];
}
void TGMaterialConfigureSlider(UISlider *slider) {
    UIImage *thumb=TGMaterialShape(CGSizeMake(20,20),TGMaterialPrimary(),10);
    UIImage *active=[TGMaterialShape(CGSizeMake(12,8),TGMaterialPrimary(),4) resizableImageWithCapInsets:UIEdgeInsetsMake(3,5,3,5)];
    UIImage *track=[TGMaterialShape(CGSizeMake(12,8),TGMaterialSurfaceVariant(),4) resizableImageWithCapInsets:UIEdgeInsetsMake(3,5,3,5)];
    for(NSNumber *s in @[@0,@1,@2]) { [slider setThumbImage:thumb forState:s.integerValue]; [slider setMinimumTrackImage:active forState:s.integerValue]; [slider setMaximumTrackImage:track forState:s.integerValue]; }
}
@implementation TGMaterialButton { CAShapeLayer *_stateLayer; }
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:frame])) { self.titleLabel.font=TGMaterialFont(15,YES); [self setTitleColor:TGMaterialPrimary() forState:UIControlStateNormal]; [self setTitleColor:TGMaterialSecondaryText() forState:UIControlStateDisabled]; self.exclusiveTouch=YES; _stateLayer=[CAShapeLayer layer]; _stateLayer.opacity=0; [self.layer addSublayer:_stateLayer]; } return self; }
- (void)layoutSubviews { [super layoutSubviews]; [CATransaction begin]; [CATransaction setDisableActions:YES]; _stateLayer.frame=self.bounds; _stateLayer.path=[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius>0 ? self.layer.cornerRadius : 12].CGPath; _stateLayer.fillColor=[TGMaterialPrimary() colorWithAlphaComponent:.14].CGColor; [CATransaction commit]; }
- (void)setHighlighted:(BOOL)highlighted {
 BOOL changed=self.highlighted!=highlighted; [super setHighlighted:highlighted]; if(!changed)return;
 [CATransaction begin]; [CATransaction setDisableActions:YES]; _stateLayer.opacity=highlighted ? 1 : 0; [CATransaction commit];
 TGMaterialAnimate(_stateLayer,@"opacity",@(highlighted ? 0 : 1),@(highlighted ? 1 : 0),.14);
 if(highlighted)TGMaterialAnimate(_stateLayer,@"transform.scale",@.9,@1,.18);
}
@end
@implementation TGMaterialTextField
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:frame])) { self.font=TGMaterialFont(16,NO); self.textColor=TGMaterialText(); self.backgroundColor=TGMaterialSurfaceVariant(); self.layer.cornerRadius=12; self.borderStyle=UITextBorderStyleNone; } return self; }
- (CGRect)textRectForBounds:(CGRect)bounds { CGFloat left=self.leftView && self.leftViewMode==UITextFieldViewModeAlways ? self.leftView.bounds.size.width : 12; CGFloat right=self.clearButtonMode!=UITextFieldViewModeNever && self.isEditing && self.text.length ? 32 : 12; return CGRectMake(bounds.origin.x+left,bounds.origin.y+6,MAX(0,bounds.size.width-left-right),MAX(0,bounds.size.height-12)); }
- (CGRect)editingRectForBounds:(CGRect)bounds { return [self textRectForBounds:bounds]; }
- (CGRect)placeholderRectForBounds:(CGRect)bounds { return [self textRectForBounds:bounds]; }
@end
@implementation TGMaterialSwitch { CALayer *_track; CALayer *_thumb; }
- (instancetype)init { return [self initWithFrame:CGRectMake(0,0,52,32)]; }
- (instancetype)initWithFrame:(CGRect)frame { if((self=[super initWithFrame:CGRectMake(frame.origin.x,frame.origin.y,52,32)])) { _track=[CALayer layer]; _track.cornerRadius=16; _track.borderWidth=2; [self.layer addSublayer:_track]; _thumb=[CALayer layer]; [self.layer addSublayer:_thumb]; self.accessibilityLabel=@"Переключатель"; self.accessibilityTraits=UIAccessibilityTraitButton; [self addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside]; [self setOn:NO animated:NO]; } return self; }
- (void)toggle { if(!self.enabled)return; [self setOn:!self.on animated:YES]; [self sendActionsForControlEvents:UIControlEventValueChanged]; }
- (void)setOn:(BOOL)on { [self setOn:on animated:NO]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated { CGPoint before=_thumb.position; _on=on; [self setNeedsLayout]; [self layoutIfNeeded]; if(animated)TGMaterialAnimate(_thumb,@"position",[NSValue valueWithCGPoint:before],[NSValue valueWithCGPoint:_thumb.position],.18); self.accessibilityValue=on ? @"Включено" : @"Выключено"; }
- (void)layoutSubviews { [super layoutSubviews]; [CATransaction begin]; [CATransaction setDisableActions:YES]; _track.frame=self.bounds; _track.backgroundColor=(self.on ? TGMaterialPrimary() : TGMaterialSurfaceVariant()).CGColor; _track.borderColor=(self.on ? TGMaterialPrimary() : TGMaterialSecondaryText()).CGColor; CGFloat d=self.on ? 24 : 16; _thumb.bounds=CGRectMake(0,0,d,d); _thumb.cornerRadius=d/2; _thumb.position=CGPointMake(self.on ? self.bounds.size.width-16 : 16,self.bounds.size.height/2); _thumb.backgroundColor=(self.on ? TGMaterialOnPrimary() : TGMaterialSecondaryText()).CGColor; self.alpha=self.enabled ? 1 : .45; [CATransaction commit]; }
@end
void TGMaterialPrepareScreen(UIViewController *controller) {
    if([controller isKindOfClass:[UINavigationController class]] || [controller isKindOfClass:[UITabBarController class]])return;
    UINavigationBar *bar=controller.navigationController.navigationBar; bar.translucent=NO; bar.tintColor=TGMaterialPrimary();
    if([bar respondsToSelector:@selector(setShadowImage:)])bar.shadowImage=TGMaterialShape(CGSizeMake(1,1),[UIColor clearColor],0);
    [bar setBackgroundImage:TGMaterialShape(CGSizeMake(2,2),TGMaterialCanvas(),0) forBarMetrics:UIBarMetricsDefault];
    bar.titleTextAttributes=@{UITextAttributeTextColor:TGMaterialText(),UITextAttributeFont:TGMaterialFont(20,YES),UITextAttributeTextShadowColor:[UIColor clearColor]};
}

@implementation TGMaterialListCell { CAShapeLayer *_cardShape; CALayer *_divider; UITableViewCellStyle _materialStyle; UILabel *_title, *_detail; UIImageView *_icon; }
- (UILabel *)textLabel { return _title; }
- (UILabel *)detailTextLabel { return _detail; }
- (UIImageView *)imageView { return _icon; }
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if((self=[super initWithStyle:style reuseIdentifier:identifier])) {
        _materialStyle=style; _cardInset=16; self.backgroundColor=[UIColor clearColor]; self.backgroundView=nil; self.selectedBackgroundView=nil; self.contentView.backgroundColor=[UIColor clearColor];
        [super textLabel].hidden=YES; [super detailTextLabel].hidden=YES; [super imageView].hidden=YES;
        _title=[[UILabel alloc] init]; _detail=[[UILabel alloc] init]; _icon=[[UIImageView alloc] init]; _icon.backgroundColor=[UIColor clearColor];
        [self.contentView addSubview:_title]; [self.contentView addSubview:_detail]; [self.contentView addSubview:_icon];
        _cardShape=[CAShapeLayer layer]; [self.layer insertSublayer:_cardShape atIndex:0]; _divider=[CALayer layer]; [self.layer addSublayer:_divider];
        self.textLabel.font=TGMaterialFont(16,NO); self.textLabel.textColor=TGMaterialText(); self.detailTextLabel.font=TGMaterialFont(12,NO); self.detailTextLabel.textColor=TGMaterialSecondaryText(); self.detailTextLabel.backgroundColor=self.textLabel.backgroundColor=[UIColor clearColor];
    } return self;
}
- (void)setFirstInGroup:(BOOL)value { _firstInGroup=value; [self setNeedsLayout]; }
- (void)setLastInGroup:(BOOL)value { _lastInGroup=value; [self setNeedsLayout]; }
- (void)setCardInset:(CGFloat)value { _cardInset=value; [self setNeedsLayout]; }
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat w=self.bounds.size.width,h=self.bounds.size.height,inset=self.cardInset;
    self.backgroundColor=self.contentView.backgroundColor=[UIColor clearColor]; self.imageView.hidden=self.imageView.image==nil;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    UIRectCorner corners=0; if(self.firstInGroup)corners|=UIRectCornerTopLeft|UIRectCornerTopRight; if(self.lastInGroup)corners|=UIRectCornerBottomLeft|UIRectCornerBottomRight;
    _cardShape.frame=self.bounds; _cardShape.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds,inset,0) byRoundingCorners:corners cornerRadii:CGSizeMake(24,24)].CGPath; _cardShape.fillColor=(self.highlighted || self.selected ? TGMaterialPrimaryContainer() : TGMaterialSurface()).CGColor;
    self.contentView.frame=self.bounds; CGFloat left=inset+16,right=w-inset-16;
    if(self.accessoryView) { CGSize size=self.accessoryView.bounds.size; self.accessoryView.frame=CGRectMake(right-size.width,(h-size.height)/2,size.width,size.height); right-=size.width+12; }
    if(self.imageView.image) { self.imageView.frame=CGRectMake(left,(h-24)/2,24,24); self.imageView.contentMode=UIViewContentModeScaleAspectFit; left+=40; }
    CGFloat detail=_materialStyle==UITableViewCellStyleValue1 ? MIN(90,[self.detailTextLabel sizeThatFits:CGSizeMake(90,h)].width) : 0;
    if(_materialStyle==UITableViewCellStyleSubtitle && self.detailTextLabel.text.length) { self.textLabel.frame=CGRectMake(left,(h-42)/2,MAX(0,right-left),24); self.detailTextLabel.frame=CGRectMake(left,(h-42)/2+24,MAX(0,right-left),18); }
    else { self.textLabel.frame=CGRectMake(left,0,MAX(0,right-left-(detail ? detail+8 : 0)),h); self.detailTextLabel.frame=CGRectMake(right-detail,0,detail,h); }
    _divider.hidden=self.lastInGroup; _divider.backgroundColor=[TGMaterialOutline() colorWithAlphaComponent:.5].CGColor; _divider.frame=CGRectMake(left,h-1/[UIScreen mainScreen].scale,MAX(0,w-inset-16-left),1/[UIScreen mainScreen].scale);
    [CATransaction commit];
}
- (void)setHighlighted:(BOOL)value animated:(BOOL)animated { [super setHighlighted:value animated:animated]; [self setNeedsLayout]; }
- (void)setSelected:(BOOL)value animated:(BOOL)animated { [super setSelected:value animated:animated]; [self setNeedsLayout]; }
@end
