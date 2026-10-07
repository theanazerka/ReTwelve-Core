# ReTwelve 0.13.15 — optional UI7Kit theme

Settings → Appearance → Style iOS 7. Default: off. Preference: TGUseUI7Kit.
The old hidden TGModernTheme preference is intentionally not reused.

## Implementation

Actual UI7Kit source and dependencies are compiled into the armv7 application.
On iOS 6, enabling the theme applies the library's UIKit patches once. Original
and themed entry points are captured, including inherited implementations and
class methods. Later switches restore/reapply those entry points without
repatching the library or overwriting its original-method backups. Added tint
compatibility APIs remain available but do not restyle classic screens.

On iOS 7+ native UIKit controls provide the flat style; legacy private internals
are never patched. The app's custom views follow the same theme preference.

Switching rebuilds the root navigation screens after the control event finishes,
returns to Appearance, reuses the existing TGClient/session, and reattaches the
music player without stopping audio. Media/document caches remain on TGClient.

## Styled surfaces

Navigation/tab bars, UIKit buttons/switches/search/text fields/tables/alerts/action
sheets/segments/sliders/pickers; dialogs and chat bubbles/composer; settings and
profiles; contacts/group/channel creation; attachment/file/photo picker chrome;
sticker panel; login/tour; player and mini player.

Original resource names are attached to images and retained through cap resizing.
Legacy backgrounds are flattened when assigned to image views/buttons, rather
than replacing originals in caches. Thus switching back retains classic artwork.
Artwork/photos/animations remain original content. No live blur is introduced.

## Verification

- armv7 iOS 6 package builds successfully with the real vendor sources.
- TGUI7MethodStateTest exercises repeated enable/disable, inherited instance and
  class methods, parent isolation and preservation of UI7Kit backup selectors.
- IPA metadata, included UI7 resources and ZIP integrity checked after packaging.
- No compatible phone was connected. Layout and library behavior on an actual
  iOS 6 device still require a device check; a host runtime test is not a UIKit
  rendering or old-device performance test.
