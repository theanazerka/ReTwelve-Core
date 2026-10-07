# 0.13.11: settings tab bar regression and player layout

The shared table controller introduced a hidesBottomBarWhenPushed=YES default for all controllers, including root Settings. The custom tab container honored this flag at the root, so switching to Settings hid the tab bar. Removed that initializer default; viewWillAppear now explicitly derives it from whether the controller is pushed. Root Settings explicitly opts out. The custom tab container additionally ignores this flag for navigation roots, while the expanded music overlay may still hide the bar.

The player now reserves 198 points below artwork: a 94-point progress/repeat/profile/shuffle panel and a 104-point transport/volume panel. These controls no longer cover artwork or shrink with cover size. Progress and volume use native iOS slider artwork and 31-point control frames. Playback controls stay visible. Child layout is established before the expansion animation. The navigation title uses two rows.

Verification: armv7 build and IPA integrity/version/architecture checks passed. Screenshot capture via USB was unavailable because the screenshot service requires a mounted developer image, so no physical visual verification is claimed.
