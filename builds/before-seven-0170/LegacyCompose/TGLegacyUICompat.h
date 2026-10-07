#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-function"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <float.h>
#define UIColorRGBA(rgb,a) [UIColor colorWithRed:(((rgb)>>16)&255)/255.0 green:(((rgb)>>8)&255)/255.0 blue:((rgb)&255)/255.0 alpha:(a)]
#define UIColorRGB(rgb) UIColorRGBA(rgb,1.0)
#define TGLog(...) NSLog(__VA_ARGS__)
static inline BOOL TGIsRetina(void) { return [UIScreen mainScreen].scale > 1.0; }
static inline int iosMajorVersion(void) { return [[[UIDevice currentDevice] systemVersion] intValue]; }
static inline CGFloat TGAnimationSpeedFactor(void) { return 1.0; }
FOUNDATION_EXPORT NSString *TGLegacyLocalized(NSString *key);
#define TGLocalized(key) TGLegacyLocalized(key)
#define TGLocalizedStatic(key) TGLegacyLocalized(key)
FOUNDATION_EXPORT NSString *TGEncodeText(NSString *text, int shift);
@class TGClient, TGUser;
@interface UIViewController (TGLegacyModernInsets)
- (void)setEdgesForExtendedLayout:(NSUInteger)edges;
@end
@interface TGDateUtils : NSObject
+ (NSString *)stringForRelativeLastSeen:(int)timestamp;
@end
@protocol TGBarItemSemantics <NSObject>
- (bool)backSemantics;
@optional
- (float)barButtonsOffset;
@end
@interface ASHandle : NSObject
@property (nonatomic, weak) id delegate;
- (instancetype)initWithDelegate:(id)delegate releaseOnMainThread:(BOOL)mainThread;
- (void)requestAction:(NSString *)action options:(NSDictionary *)options;
- (void)reset;
@end
@interface TGViewController : UIViewController
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic) SEL backAction;
@property (nonatomic) BOOL ignoreKeyboardWhenAdjustingScrollViewInsets;
@property (nonatomic, readonly) UIEdgeInsets controllerCleanInset;
@property (nonatomic, readonly) UIEdgeInsets controllerInset;
@property (nonatomic, strong) NSArray *scrollViewsForAutomaticInsetsAdjustment;
@property (nonatomic, readonly) BOOL navigationBarShouldBeHidden;
- (void)setBackAction:(SEL)action animated:(BOOL)animated;
- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated;
- (void)setExplicitTableInset:(UIEdgeInsets)inset scrollIndicatorInset:(UIEdgeInsets)indicator;
- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset;
- (BOOL)_updateControllerInset:(BOOL)animated;
+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation;
@end
@interface TGHacks : NSObject
+ (void)setTextFieldClearOffset:(UITextField *)field offset:(CGFloat)offset;
+ (void)setTextFieldPlaceholderColor:(UITextField *)field color:(UIColor *)color;
@end
@interface TGInterfaceAssets : NSObject
+ (instancetype)instance;
- (UIColor *)linesBackground;
- (UIImage *)smallAvatarPlaceholder:(int64_t)uid;
- (UIImage *)smallAvatarPlaceholderGeneric;
- (UIImage *)avatarPlaceholderGeneric;
- (UIImage *)dialogListSearchIcon;
+ (UIImage *)groupedCellSingle;
+ (UIImage *)groupedCellSingleHighlighted;
+ (UIImage *)groupedCellTop;
+ (UIImage *)groupedCellTopHighlighted;
+ (UIImage *)groupedCellMiddle;
+ (UIImage *)groupedCellMiddleHighlighted;
+ (UIImage *)groupedCellBottom;
+ (UIImage *)groupedCellBottomHighlighted;
@end
static inline BOOL TGUse12hDateFormat(void) { return NO; }
@interface TGLegacyContactStore : NSObject
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *users;
+ (instancetype)shared;
- (TGUser *)userForId:(int64_t)uid;
- (void)loadContacts:(void (^)(NSArray *, NSString *))completion;
- (void)avatarForURL:(NSString *)url completion:(void (^)(UIImage *))completion;
@end
