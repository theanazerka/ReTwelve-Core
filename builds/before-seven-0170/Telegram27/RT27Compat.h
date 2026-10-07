#pragma once
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "../Material/TGMaterialKit.h"
#include <math.h>
#include <float.h>
@class RT27CollectionItem;
#define RT27ColorRGB(v) [UIColor colorWithRed:((v>>16)&255)/255.0 green:((v>>8)&255)/255.0 blue:(v&255)/255.0 alpha:1]
#define RT27ColorRGBA(v,a) [UIColor colorWithRed:((v>>16)&255)/255.0 green:((v>>8)&255)/255.0 blue:(v&255)/255.0 alpha:(a)]
#define RT27Floor(v) floor(v)
#define RT27Ceil(v) ceil(v)
#define RT27RetinaPixel (1.0/[UIScreen mainScreen].scale)
static inline CGFloat RT27RetinaFloor(CGFloat v) { CGFloat scale=[UIScreen mainScreen].scale; return floor(v*scale)/scale; }
static inline BOOL RT27IsRetina(void) { return [UIScreen mainScreen].scale>1; }
static inline BOOL RT27IsPad(void) { return UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad; }
static inline BOOL RT27IsLocaleArabic(void) { return NO; }
static inline BOOL RT27IsRTL(void) { return NO; }
static inline int RT27OSMajorVersion(void) { return [[[UIDevice currentDevice] systemVersion] intValue]; }
static inline BOOL RT27StringCompare(id a,id b) { return a==b || [a isEqual:b]; }
static inline BOOL RT27ObjectCompare(id a,id b) { return a==b || [a isEqual:b]; }
static inline UIFont *RT27SystemFontOfSize(CGFloat size) { return TGMaterialFont(size,NO); }
static inline UIFont *RT27MediumSystemFontOfSize(CGFloat size) { return TGMaterialFont(size,YES); }
static inline UIFont *RT27BoldSystemFontOfSize(CGFloat size) { return TGMaterialFont(size,YES); }
static inline UIColor *RT27AccentColor(void) { return TGMaterialPrimary(); }
static inline UIColor *RT27SelectionColor(void) { return TGMaterialPrimaryContainer(); }
static inline UIColor *RT27SeparatorColor(void) { return TGMaterialOutline(); }
#ifdef __cplusplus
extern "C" {
#endif
NSString *RT27Localized(NSString *key);
#ifdef __cplusplus
}
#endif
@interface UIImage (RT27Resources)
+ (UIImage *)rt27_imageNamed:(NSString *)name;
@end
@interface RT27StringUtils : NSObject
+ (NSString *)stringWithLocalizedNumberCharacters:(NSString *)string;
+ (NSString *)stringWithLocalizedNumber:(int)number;
@end
@interface RT27ViewController : UIViewController
+ (BOOL)useExperimentalRTL;
+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation;
@end
static inline CGSize RT27ScreenSize(void) { CGSize s=[UIScreen mainScreen].bounds.size; return CGSizeMake(MIN(s.width,s.height),MAX(s.width,s.height)); }
typedef NS_ENUM(NSInteger, RT27MessageDeliveryState) { RT27MessageDeliveryStateDelivered, RT27MessageDeliveryStatePending, RT27MessageDeliveryStateFailed };
@interface RT27DateUtils : NSObject
+ (NSString *)stringForMessageListDate:(int)date;
@end
static inline BOOL RT27Use12hDateFormat(void) { return NO; }
#define RT27RemoteImageContentHintLoadFromDiskSynchronously 1
@protocol RT27ModernGalleryTransitionView <NSObject>
- (UIImage *)transitionImage;
@end
@interface RT27ActionHandle : NSObject
@property(nonatomic,copy) void (^action)(NSString *,id);
- (void)requestAction:(NSString *)action options:(id)options;
@end
@interface RT27User : NSObject
@property(nonatomic,copy) NSString *firstName,*lastName;
@end
