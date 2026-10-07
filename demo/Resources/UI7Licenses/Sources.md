# UI7Kit sources used by ReTwelve

- UI7Kit: https://github.com/youknowone/UI7Kit, commit `db5ccea255fdf5476a8466fe288a82a6d603de1b`.
- FoundationExtension 1.0.0: https://github.com/youknowone/FoundationExtension, commit `ad03d2f1bb6e0d3b29b57afc6d082d203d8e98aa`.
- SevenSwitch 1.3.0: https://github.com/bvogelzang/SevenSwitch, commit `49546b689f865d5c76a4125d738a9e1aa74cc5b4`.
- GIKPopoverBackgroundView: https://github.com/GiK/GIKPopoverBackgroundView, commit `112184b71a2cdd3bca7ec8d4e12539cfc3d95166`.
- cdebug: https://github.com/youknowone/cdebug, commit `f9c47753e1ffbfca752dd2b1f38361d189a94002`.
- UIKitResources: https://github.com/youknowone/UIKitResources, commit `61298b6941c0dc619a0f92ad47242b000401821b`.

## Integration changes

- MRC for UI7Kit/FoundationExtension/UIKitExtension; ARC for SevenSwitch/GIKPopover.
- Prefix header and qualified Foundation imports for the Theos build.
- Runtime OS detection skips legacy UIKit patches on iOS 7 and later.
- The app measures its own table headers/footers. UI7TableView's delegate-class
  rewriting and visible-cell hook are disabled. Its native flat table styling
  remains enabled, with grouped semantics recorded under a stable app key.
- UIWindow uses native UIView tint lookup on iOS 7+.
- Correctly typed BOOL/enumeration private selector calls in tab bar item decoding.
- Flat legacy button title color adapter in UI7Button.

All upstream copyright notices and source licenses are retained. SevenSwitch's and GIKPopover's MIT licenses are also retained as separate files.
Notices are included in Resources/UI7Licenses for the binary distribution.
