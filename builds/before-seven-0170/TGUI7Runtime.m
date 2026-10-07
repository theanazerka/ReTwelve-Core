#import "TGUI7Runtime.h"
#import "TGTheme.h"
extern void TGUI7InstallResourceAdapters(void);
extern void TGUI7InstallPublicControlAdapters(void);
void TGUI7ApplyRuntime(BOOL enabled) {
    // The theme uses Telegram 2.7 source views and public UIKit constructors.
    // Nothing in UIKit's private implementation is replaced on either OS.
}
void TGUI7PrepareApplication(void) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"TGUseUI7Kit":@NO}];
    TGUI7InstallResourceAdapters(); TGUI7InstallPublicControlAdapters();
    NSLog(@"ReTwelve launch: Material UIKit ready, OS=%@ flat=%d globalPatch=0",[UIDevice currentDevice].systemVersion,TGModernThemeEnabled());
}
