# ReTwelve: iOS 7 presentation

The application creates its presentation components explicitly with public UIKit APIs.
It runs on iOS 6 / armv7; an iOS 7-only UIKit framework cannot be loaded on iOS 6.

- RT7UIKit: flat controls, directly laid out rows, table controllers, bar items, alerts, search and sliders.
- SevenSwitch: original bundled UI7Kit dependency, compiled directly, with retained MIT license.
- RT7RootController: native UITabBarController containment and UINavigationController page transitions.
- RT7ComposeController: contacts, recipient selection and group composition.
- Conversation composer: new 44 pt panel, thin field border and flat accessory controls.
- Modal community/compose screens: native vertical UIKit presentation.

Material components and global UIKit constructor/resource swizzles were removed from the application build.
Remaining TG / RT27 class names preserve controller callbacks and Telegram transport integrations.
UI7Kit's global private UIKit patches are not enabled.

0.17.0 was compiled and packaged. No device UI testing or FPS measurement was performed for this update, as requested.
