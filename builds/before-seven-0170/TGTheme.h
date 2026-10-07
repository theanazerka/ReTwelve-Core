#import <UIKit/UIKit.h>
#import "Material/TGMaterialKit.h"

#ifdef __cplusplus
extern "C" {
#endif

extern NSString *const TGThemeChangedNotification;
BOOL TGModernThemeEnabled(void);
void TGSetModernThemeEnabled(BOOL enabled);
UIColor *TGModernBlue(void);
UIColor *TGModernCanvas(void);
UIColor *TGModernSecondaryText(void);
UIColor *TGModernSeparator(void);
UIColor *TGModernMutedBadge(void);
UIImage *TGFlatImage(UIColor *color);
UIImage *TGModernBubbleImage(BOOL outgoing);
UIImage *TGModernSearchImage(void);
UIImage *TGModernTabImage(NSInteger index);

UIView *TGModernSectionView(NSString *text, CGFloat width, CGFloat height, BOOL header);
CGFloat TGModernSectionHeight(NSString *text, CGFloat width, BOOL header);
BOOL TGTableIsGrouped(UITableView *table);

#ifdef __cplusplus
}
#endif
