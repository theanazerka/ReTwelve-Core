# 0.13.13 — archive and navigation tab bar

Archive no longer sets hidesBottomBarWhenPushed. It retains the tab bar.

During animated navigation, the tab controller now suspends manual bar visibility/frame and content container updates from willShow until didShow. UINavigationController owns the native transition, including hidesBottomBarWhenPushed; the bar is reconciled after navigation ends. This prevents the immediate disappearance introduced by the previous patch, without reintroducing a separate 0.25-second bar animation.

Inspected the supplied old TGMainTabsController and TGNavigationController sources. The local tab controller keeps its existing native UITabBar architecture rather than importing that original custom bar and its private layout hooks.

Armv7 build and IPA integrity/version/architecture checks passed. Device disconnected before packaging; this build has not been installed or visually verified.
