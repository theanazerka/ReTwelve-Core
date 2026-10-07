#ifndef TG_UI7_UIKIT_POLICY_H
#define TG_UI7_UIKIT_POLICY_H

// Must match the SDK recorded by the linker in demo/Makefile. SDK 6 preserves
// classic UIKit on iOS 7/8. Global UI7Kit internals are supported only on iOS 6.
#define TG_LINKED_UIKIT_SDK_MAJOR 6
static inline int TGUI7NeedsBackportForVersions(int systemMajor, int linkedSDKMajor) {
    (void)linkedSDKMajor;
    return systemMajor < 7;
}
#endif
