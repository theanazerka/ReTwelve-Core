# ReTwelve — 0.13.14

Display name and bundle name: ReTwelve. Bundle identifier and Debian package identifier: com.anazerka.retwelve. The internal executable/build target remains TelegramCodeDemo. Settings footer now uses ReTwelve.

User-provided airplane icon copied to Branding/AppIconSource.png; cropped by one pixel on each side to square and resized using sips. Legacy 57/114 and settings 29/58 icons plus modern resolution variants are registered in both legacy CFBundleIconFiles and iOS 5+ CFBundleIcons/CFBundlePrimaryIcon. Pixels are fully opaque. UIPrerenderedIcon disables extra system gloss; iOS supplies the normal rounded home-screen mask.

Apple references:
https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/iPhoneOSKeys.html
https://developer.apple.com/library/archive/qa/qa1686/_index.html

Armv7 build passed. Verified packaged display name, bundle identifier, minimum iOS, icon registration, icon opacity, 57/114 dimensions, architecture and IPA ZIP integrity. No device connected at packaging time; physical appearance has not been verified. New identifier installs separately from the previous application.
