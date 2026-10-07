#pragma once
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../vendor/UI7/SevenSwitch/SevenSwitch.h"

#ifdef __cplusplus
extern "C" {
#endif

// One presentation system for every screen, including iOS 6 / armv7.
UIColor *RT7Primary(void);
UIColor *RT7OnPrimary(void);
UIColor *RT7PrimaryContainer(void);
UIColor *RT7Surface(void);
UIColor *RT7Canvas(void);
UIColor *RT7SurfaceVariant(void);
UIColor *RT7Text(void);
UIColor *RT7SecondaryText(void);
UIColor *RT7Outline(void);
UIColor *RT7Error(void);
UIColor *RT7BubbleColor(NSInteger index);
UIImage *RT7Wallpaper(NSInteger index);
UIFont *RT7Font(CGFloat size, BOOL medium);
UIImage *RT7Shape(CGSize size, UIColor *color, CGFloat radius);
UIImage *RT7Icon(NSString *name, CGFloat size, UIColor *color);
UIImage *RT7Asset(NSString *name, UIImage *original);
void RT7ConfigureSlider(UISlider *slider);
void RT7Animate(CALayer *layer, NSString *key, id from, id to, NSTimeInterval duration);
void RT7SlidePanel(UIView *panel, UIView *scrim, BOOL show, void (^completion)(void));
void RT7PrepareScreen(UIViewController *controller);

#ifdef __cplusplus
}
#endif

@interface RT7Button : UIButton
@end
@interface RT7TextField : UITextField
@end
@interface RT7Switch : SevenSwitch
@end

// A single real table cell, with direct controls and vector card geometry.
@interface RT7ListCell : UITableViewCell
@property(nonatomic) BOOL firstInGroup,lastInGroup;
@property(nonatomic) CGFloat cardInset;
@end

#ifdef __cplusplus
extern "C" {
#endif
UIImage *RT7ImageNamed(NSString *name);
#ifdef __cplusplus
}
#endif
@interface RT7Slider : UISlider @end
@interface RT7SegmentedControl : UISegmentedControl @end
@interface RT7BarButtonItem : UIBarButtonItem @end
@interface RT7SearchBar : UISearchBar @end
@interface RT7TableView : UITableView @end
@interface RT7TableController : UITableViewController @end
@interface RT7AlertView : UIAlertView @end
@interface RT7ActionSheet : UIActionSheet @end

@interface RT7TabBarItem : UITabBarItem @end
