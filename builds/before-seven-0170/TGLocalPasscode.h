#import <UIKit/UIKit.h>
BOOL TGLocalPasscodeEnabled(void);
UIViewController *TGLocalPasscodeSettings(void);
@interface TGLocalPasscodeGate : UIViewController
@property (nonatomic, copy) void (^unlocked)(void);
@end
