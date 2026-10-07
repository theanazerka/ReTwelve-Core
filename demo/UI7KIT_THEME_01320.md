# ReTwelve 0.13.20 — fixes from the three phone photos

- Replaced UIRectFill after source-in blending with CGContextFillRect in navigation/button, conversation, checkmark and music icon tinting. UIRectFill overrides the blend mode, producing opaque colored rectangles in transparent regions.
- Added flat section views, including empty section spacing. Community descriptions are measured and wrapped rather than rendered in the legacy single-line blue section style.
- Replaced compatibility UIKit grouped tables created internally by UITableViewController with public plain tables in the optional flat theme on iOS 7/8, preserving grouped semantics for app layout.
- Clear backgrounds for custom chat list labels; normal 16-point font and square row background for photo/logout actions in modern settings.
- Neutral off-state track for SevenSwitch.

Validation: armv7 package built; host theme restoration/policy test passed; Mach-O deployment and SDK remain 6.0. Physical visual verification still requires reopening the app after updating. Account containers are not touched by deployment.
