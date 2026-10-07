#import "TGTheme.h"
#import "TGUI7Runtime.h"
#import "Telegram27/RT27HeaderCollectionItemView.h"
#import "Telegram27/RT27CommentCollectionItemView.h"
#import <objc/runtime.h>
static char TGGroupedTableKey;
void TGUI7RecordGroupedTable(id table, BOOL grouped) { objc_setAssociatedObject(table, &TGGroupedTableKey, @(grouped), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

NSString *const TGThemeChangedNotification = @"TGThemeChangedNotification";
static int TGModernThemeCached = -1;
BOOL TGModernThemeEnabled(void) {
    // Keep the unfinished Telegram 2.7 theme out of the app until its screens
    // have been brought to the same level. Clear older installs' saved toggle.
    if (TGModernThemeCached < 0) {
        TGModernThemeCached = 0;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TGUseUI7Kit"]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"TGUseUI7Kit"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    return NO;
}
void TGSetModernThemeEnabled(BOOL enabled) {
    (void)enabled;
    TGModernThemeCached = 0;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"TGUseUI7Kit"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGUI7ApplyRuntime(NO);
    [[NSNotificationCenter defaultCenter] postNotificationName:TGThemeChangedNotification object:nil];
}
// DefaultDayPresentationTheme.swift in Telegram-iOS is the source for these values.
UIColor *TGModernBlue(void) { return [UIColor colorWithRed:0 green:126.0/255 blue:229.0/255 alpha:1]; }
UIColor *TGModernCanvas(void) { return [UIColor colorWithRed:239.0/255 green:239.0/255 blue:244.0/255 alpha:1]; }
UIColor *TGModernSecondaryText(void) { return [UIColor colorWithRed:142.0/255 green:142.0/255 blue:147.0/255 alpha:1]; }
UIColor *TGModernSeparator(void) { return [UIColor colorWithRed:200.0/255 green:199.0/255 blue:204.0/255 alpha:1]; }
UIColor *TGModernMutedBadge(void) { return [UIColor colorWithRed:182.0/255 green:182.0/255 blue:187.0/255 alpha:1]; }
UIImage *TGFlatImage(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(2, 2), CGColorGetAlpha(color.CGColor) >= 1, 0);
    [color setFill]; UIRectFill(CGRectMake(0, 0, 2, 2));
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}
UIImage *TGModernBubbleImage(BOOL outgoing) {
    // Telegram 2.7 TGTextMessageBackgroundViewModel's original phone assets/caps.
    static UIImage *incomingImage,*outgoingImage; static dispatch_once_t once;
    dispatch_once(&once,^{
        incomingImage=[[UIImage imageNamed:@"Telegram27/ModernBubbleIncomingFull.png"] stretchableImageWithLeftCapWidth:23 topCapHeight:16];
        outgoingImage=[[UIImage imageNamed:@"Telegram27/ModernBubbleOutgoingFull.png"] stretchableImageWithLeftCapWidth:17 topCapHeight:16];
    });
    return outgoing ? outgoingImage : incomingImage;
}
UIImage *TGModernSearchImage(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIImage *raw=[UIImage imageNamed:@"Telegram27/SearchInputFieldLight.png"];
        image=[raw stretchableImageWithLeftCapWidth:(int)(raw.size.width/2) topCapHeight:1];
    });
    return image;
}
UIImage *TGModernTabImage(NSInteger index) {
    static UIImage *contacts, *chats, *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        contacts = [UIImage imageNamed:@"ModernTelegram/TabContacts"];
        chats = [UIImage imageNamed:@"ModernTelegram/TabChats"];
        settings = [UIImage imageNamed:@"ModernTelegram/TabSettings"];
    });
    return index == 0 ? contacts : index == 1 ? chats : index == 2 ? settings : nil;
}

BOOL TGTableIsGrouped(UITableView *table) {
    NSNumber *grouped = objc_getAssociatedObject(table, &TGGroupedTableKey);
    return TGModernThemeEnabled() && grouped ? grouped.boolValue : table.style == UITableViewStyleGrouped;
}

CGFloat TGModernSectionHeight(NSString *text, CGFloat width, BOOL header) {
    if (!text.length) return header ? 16 : 8;
    CGFloat size=header ? 14 : 13;
    NSString *display=header ? text.uppercaseString : text;
    return ceil([display sizeWithFont:[UIFont systemFontOfSize:size] constrainedToSize:CGSizeMake(MAX(1,width-30),CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height)+20;
}
UIView *TGModernSectionView(NSString *text, CGFloat width, CGFloat height, BOOL header) {
    UIView *container=[[UIView alloc] initWithFrame:CGRectMake(0,0,width,height)];
    container.backgroundColor=TGModernCanvas(); container.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    if (!text.length) return container;
    RT27CollectionItemView *source;
    if (header) {
        NSString *display=text.uppercaseString;
        CGFloat textHeight=ceil([display sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(MAX(1,width-30),CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height);
        // The original collection header has one line. Long questions and section
        // descriptions need the same measured width and height as their header.
        if (textHeight>20) {
            UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(15,8,MAX(0,width-30),MAX(0,height-16))];
            label.autoresizingMask=UIViewAutoresizingFlexibleWidth;
            label.backgroundColor=[UIColor clearColor]; label.font=[UIFont systemFontOfSize:14];
            label.textColor=RT27ColorRGB(0x6d6d72); label.numberOfLines=0;
            label.lineBreakMode=NSLineBreakByWordWrapping; label.text=display;
            [container addSubview:label]; return container;
        }
        RT27HeaderCollectionItemView *view=[[RT27HeaderCollectionItemView alloc] initWithFrame:CGRectMake(0,MAX(0,height-20),width,20)];
        [view setTitle:display]; source=view;
    } else {
        RT27CommentCollectionItemView *view=[[RT27CommentCollectionItemView alloc] initWithFrame:container.bounds];
        [view setAttributedText:[[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:RT27SystemFontOfSize(13),NSForegroundColorAttributeName:RT27ColorRGB(0x6d6d72)}]];
        view.calculatedSize=CGSizeMake(width,height); source=view;
    }
    source.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    [source setItemPosition:0]; source.backgroundView.hidden=YES; source.selectedBackgroundView.hidden=YES;
    [container addSubview:source]; return container;
}
