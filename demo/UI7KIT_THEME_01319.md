# ReTwelve 0.13.19 — public control styling

The 0.13.18 recovery stays in place: UI7Kit's global backport runs only on actual iOS 6. iOS 7/8 use theme-gated public UIKit adapters, avoiding the global tint/private UIKit hooks that hung 0.13.17.

Changes for compatibility UIKit on iOS 7/8:
- Flat switches through SevenSwitch, buttons, bar buttons, text fields, segmented controls, sliders and progress bars.
- Plain grouped-list rendering while retaining application grouped-table semantics, flat selection and accessories.
- Search field styling.
- On iOS 8, native UIAlertController is resolved dynamically for confirmations, text input and action sheets; the binary keeps SDK 6 / deployment target 6.0. Button indices and delegate callbacks are forwarded, with text copied back before the click callback.
- Diagnostics after theme root replacement.

Validation:
- armv7 build/package succeeded.
- Theme method restoration / inherited methods / class methods / OS boundary host regression tests passed.
- IPA metadata: com.anazerka.retwelve, version 0.13.19, build 119, minimum iOS 6.0.
- Mach-O: LC_VERSION_MIN_IPHONEOS version 6.0, SDK 6.0.
- Physical installation attempted but failed: the previous iPhone UDID is currently unavailable to usbmux. Device launch, visual appearance and interaction in this version remain unverified.

IPA: demo/dist/ReTwelve-0.13.19-ios6.ipa.
