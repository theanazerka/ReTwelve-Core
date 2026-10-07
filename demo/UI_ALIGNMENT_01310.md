# UI alignment — 0.13.10 / build 110

## Changed

- Shared TGClassicTableController for settings, profiles, accounts, privacy, storage, group management, invitations, contact tools, sticker catalog, custom emoji, folders, file picker and poll details. Grouped headers and footers use measured multiline text with consistent original-style fonts and margins. Plain lists retain separators and a white background. Added screens avoid extending beneath navigation bars.
- Profile information uses full-width caption/value rows; actions use independent default-style cells instead of empty Value2 caption columns. Long music titles truncate inside padded buttons.
- Wallpaper thumbnails and captions use actual cell content bounds, including checkmark space. Bubble color samples stretch inside the same preview rectangle. Profile editor fields track cell bounds.
- Standard grouped cells share 16/13 point title/subtitle defaults with original background artwork. Account subtitle rows are 60 points.
- Creation/contact action rows center their icons and reserve space for disclosure arrows. Channel title input vertically centers text. Legacy form keyboard insets use the actual keyboard intersection with the controller.
- Sticker rail and toolbar controls are 44 points high. Sticker cells use at least four columns at 320 points rather than five tiny cells; pack titles remain over the grid. Recent title resets when its selected installed pack disappears. Custom emoji pack grids avoid navigation bar overlap.
- Attachment category buttons are 44 points high in a 60-point strip; sheet bounds/center stay stable during animation. Sheet height is capped by available host bounds.
- Dialog previews reserve space based on the actual unread badge width. File labels use content bounds with accessory space already removed by UIKit.

## Verification

The armv7 iOS 6 application compiled, linked and packaged successfully. IPA version/build, architecture, bundled original row art and ZIP integrity verified. Existing linker warnings remain. No compatible old iPhone was connected: only a modern device was present. Physical visual review, keyboard interactions and transitions remain unverified. This is a shared layout correction pass, not a claim that every existing screen has been visually reviewed.
