# ReTwelve 0.13.16 — flat theme cleanup

The Appearance switch remains TGUseUI7Kit. The classic resources remain available.

## Changes

- The executable now declares SDK 7.0 with deployment target 6.0. Previously SDK 6.0 compatibility styling was active on iOS 7/8, while UI7Kit was deliberately skipped there. Native flat UIKit is now used on those systems; UI7Kit still patches iOS 6.
- Bars are opaque to preserve the existing screen layout. No extra tab bar animation was added.
- Original resource adapters cover grouped and album cells, selection controls, recipient tokens, placeholders, login inputs, action buttons, panel backgrounds, linen and text shadows. Highlighted images and both image resizing APIs are covered.
- Artwork caching includes the resource identity and cap insets, keeping single and double message checks distinct.
- Flat buttons use normal fonts and readable blue titles, gray disabled states and red destructive states. UIKit and UI7Kit follow the same state rules.
- Added thin separators to feature forms, channel/group creation, accounts, devices, contacts tools and profile music lists.
- Chat text has more padding, blue outgoing bubbles, neutral background by default and rounded sender avatars. Explicit wallpapers remain selectable.
- Music controls use Telegram resources, including volume icons and album placeholders. Metal textures, decorative control dividers and text shadows are removed in this theme.
- Sticker headers and pack rails use neutral colors and regular text.

## Verification

Armv7 package builds with MinimumOSVersion 6.0. Host runtime regression checks reversible inherited methods and repeated theme switches. IPA contents, metadata and ZIP integrity checked after packaging.

No compatible iPhone is connected. Device rendering, navigation transitions and iOS 6 UI7Kit behavior have not been visually verified for this release. These checks are required before calling the theme visually complete.
