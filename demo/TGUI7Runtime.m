#import "TGUI7Runtime.h"
#import "Seven/RT7UIKit.h"
void TGUI7ApplyRuntime(BOOL enabled) { (void)enabled; }
void TGUI7PrepareApplication(void) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"TGUseUI7Kit":@YES}];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
}
