#import <UIKit/UIKit.h>
#ifdef __cplusplus
extern "C" {
#endif
void RT27PresentSheet(UIViewController *presenter, UIViewController *content, BOOL compact);
void RT27DismissSheet(UIViewController *controller, void (^completion)(void));
void RT27NavigateFromSheet(UIViewController *controller, UIViewController *next);
// Freeze the rendered panel for its slide; live table updates resume afterwards.
void RT27AnimatePanel(UIView *panel, UIView *dimmer, BOOL presenting, void (^completion)(void));
#ifdef __cplusplus
}
#endif
