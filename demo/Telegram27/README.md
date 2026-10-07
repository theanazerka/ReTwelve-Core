# Telegram 2.7 interface port

Source: `/Users/anazerka/Downloads/Telegram-2.7/`.
Original copyright notices are retained. Telegram sources are GNU GPL v2 or later; see `LICENSE`. `upstream/` contains unmodified source files; `manifest.json` records paths and SHA-256 hashes.

## Compiled original interface classes

The `RT27` prefix separates these classes from the classic Telegram interface:

- Modern button, toolbar/back/bar buttons and their highlight behavior.
- Main tab bar (extracted from `TGMainTabsController.m`).
- Dialog list cell, date/text rendering and badges.
- Contacts cell and its selection control.
- Conversation title, title icons and typing indicator drawing.
- Profile and group information rows.
- Collection list, variant, button, check, header and comment rows.
- Text field, timer target and animation completion delegate.

233 original PNG resources live in `Resources/Telegram27/`. Conversation bubble images/caps, composer graphics, search field, tab icons and navigation icons use these resources directly. The legacy artwork adapter excludes this namespace.

## Compatibility changes

`RT27Compat` supplies namespaced fonts/colors, current screen/OS checks and Russian strings. Import dependencies on the old Telegram data engine are replaced with the existing ReTwelve data/cache API. `RT27LetteredAvatarView` is an image/cache bridge. The dialog cell receives prepared preview strings instead of decoding the old media model. The typing indicator keeps original drawing but uses a timer instead of POP.

`RT27ComposerView` ports the original input panel construction, assets, cap insets and layout equations. It embeds ReTwelve's text editing, draft, entity formatting and recording controls; it is not the whole original 938-line input controller. `RT27TableRowAdapter` embeds original collection rows in existing table controllers. Navigation uses independent original controls and title replicas, preserving UIKit ownership during transitions.

This is an interface port, not a replacement of ReTwelve's network engine. Features absent from Telegram 2.7 (topics, profile music, modern channel options, etc.) retain their controllers and share the theme adapters. FlatUIKit remains only for public control/dialog backports on iOS 6. Classic theme preference and backend are retained.

## Build

0.15.1 / build 151; armv7, iOS 6 minimum, linked against iPhoneOS6.1 SDK. Build gate: `make -C demo package`.

A successful build does not verify rendering or interaction on the device. Device validation should cover chat opening/back navigation, contacts selection, Settings/Appearance theme switching and text input growth.

## 0.15.1 reference-screen adaptation

The modern Settings root uses a centered profile header, inset rounded groups and original icons supplied in `newtgres`. Community and compose controllers use `RT27SheetController`, an iOS 6 child-controller container with dimming, top corner clipping and upward/downward transitions. The classic routes still use ordinary navigation. Opening a chat from either sheet dismisses it before pushing the chat on the originating navigation controller.

The sheet is excluded from the tab controller's content-height resizing. Group clipping is limited to first/last rows and cached by bounds to avoid regenerating masks on every layout. Community peer cells now use their actual inset width. Search filters community rows locally. Contact action cells are ported from the supplied 2.7 source; the contact action uses the existing contact import request and refreshes the contact list after saving.

Device visual validation remains required; the reference screenshots describe layout and do not establish that every feature shown in a modern client exists here.
