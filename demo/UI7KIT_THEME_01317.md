# ReTwelve 0.13.17 — restore optional UI7 theme

0.13.16 forced the linked SDK to 7.0, so iOS 7/8 selected native flat UIKit regardless of the Appearance preference. Switching custom assets could not restore classic system controls.

## Fix

- Removed the forced SDK 7 linker flag. The executable again records SDK 6.0 and minimum OS 6.0.
- Runtime and UI7Kit share TGUI7UIKitPolicy.h: legacy SDK compatibility must receive the backport even when the running OS is iOS 7/8. Flat styling is applied only when TGUseUI7Kit is enabled, and method snapshots are restored when disabled.
- Moved replacement of existing UIView tint accessors from UIView initialization into the captured UI7 patch. Native methods can now be restored as part of switching to classic mode.
- Registered an explicit OFF default without replacing existing preferences. Persist the user's switch value immediately; UI rebuilding continues to reuse the existing authenticated client.
- Kept the flat resource, spacing and typography improvements from 0.13.16.

## Verification

Host regression test covers iOS 6, iOS 7/8 with SDK 6, native SDK 7, inherited instance/class methods and repeated enabling/disabling. Armv7 package compiled; IPA SDK/minimum-OS metadata, icons/resources and ZIP integrity checked. Installed successfully on the connected iPhone 5 (iOS 8.4.1), and queried the installed version as 0.13.17/build 117. Device screenshot service is unavailable without a mounted developer image; actual visual switching via touch remains unverified.
