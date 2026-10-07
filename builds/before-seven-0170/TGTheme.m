#import "TGTheme.h"
#import "Material/TGMaterialKit.h"
#import <objc/runtime.h>
static char TGGroupedTableKey;
NSString *const TGThemeChangedNotification=@"TGThemeChangedNotification";
void TGUI7RecordGroupedTable(id table, BOOL grouped) { objc_setAssociatedObject(table,&TGGroupedTableKey,@(grouped),OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
// Compatibility entry point for controllers migrated to the unified presentation.
BOOL TGModernThemeEnabled(void) { return YES; }
void TGSetModernThemeEnabled(BOOL enabled) { [[NSNotificationCenter defaultCenter] postNotificationName:TGThemeChangedNotification object:nil]; }
UIColor *TGModernBlue(void) { return TGMaterialPrimary(); }
UIColor *TGModernCanvas(void) { return TGMaterialCanvas(); }
UIColor *TGModernSecondaryText(void) { return TGMaterialSecondaryText(); }
UIColor *TGModernSeparator(void) { return TGMaterialOutline(); }
UIColor *TGModernMutedBadge(void) { return TGMaterialSecondaryText(); }
UIImage *TGFlatImage(UIColor *color) { return TGMaterialShape(CGSizeMake(2,2),color,0); }
UIImage *TGModernBubbleImage(BOOL outgoing) {
    static UIImage *incoming; static NSArray *outgoingImages; static dispatch_once_t once;
    dispatch_once(&once,^{ incoming=[TGMaterialShape(CGSizeMake(32,32),TGMaterialSurface(),14) resizableImageWithCapInsets:UIEdgeInsetsMake(14,14,14,14)]; NSMutableArray *images=[NSMutableArray array]; for(NSInteger i=0;i<7;i++) [images addObject:[TGMaterialShape(CGSizeMake(32,32),TGMaterialBubbleColor(i),14) resizableImageWithCapInsets:UIEdgeInsetsMake(14,14,14,14)]]; outgoingImages=[images copy]; });
    return outgoing ? outgoingImages[MAX(0,MIN(6,[[NSUserDefaults standardUserDefaults] integerForKey:@"TGBubbleColor"]))] : incoming;
}
UIImage *TGModernSearchImage(void) { static UIImage *image; static dispatch_once_t once; dispatch_once(&once,^{ image=[TGMaterialShape(CGSizeMake(48,40),TGMaterialSurfaceVariant(),20) resizableImageWithCapInsets:UIEdgeInsetsMake(18,22,18,22)]; }); return image; }
UIImage *TGModernTabImage(NSInteger index) { return TGMaterialIcon(index==0 ? @"contacts" : index==1 ? @"chat" : @"settings",24,TGMaterialPrimary()); }
BOOL TGTableIsGrouped(UITableView *table) { NSNumber *grouped=objc_getAssociatedObject(table,&TGGroupedTableKey); return grouped ? grouped.boolValue : table.style==UITableViewStyleGrouped; }
CGFloat TGModernSectionHeight(NSString *text,CGFloat width,BOOL header) {
    if(!text.length)return header ? 16 : 8;
    return ceil([text sizeWithFont:TGMaterialFont(header ? 13 : 12,header) constrainedToSize:CGSizeMake(MAX(1,width-48),CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height)+(header ? 24 : 16);
}
UIView *TGModernSectionView(NSString *text,CGFloat width,CGFloat height,BOOL header) {
    UIView *view=[[UIView alloc] initWithFrame:CGRectMake(0,0,width,height)]; view.backgroundColor=TGMaterialCanvas(); view.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(24,header ? 12 : 6,MAX(0,width-48),MAX(0,height-(header ? 20 : 12)))]; label.autoresizingMask=UIViewAutoresizingFlexibleWidth; label.backgroundColor=[UIColor clearColor]; label.numberOfLines=0; label.font=TGMaterialFont(header ? 13 : 12,header); label.textColor=header ? TGMaterialPrimary() : TGMaterialSecondaryText(); label.text=text; [view addSubview:label]; return view;
}
