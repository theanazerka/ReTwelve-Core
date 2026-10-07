# Sticker keyboard (iOS 6)

Behavior reference: Telegram-iOS, ChatEntityKeyboardInputNode.swift and its panelItemGroups/contentItemGroups. The new Swift/component implementation is not compiled into this Objective-C app. TGStickerKeyboardView adapts the inline input view, scrollable grid, recent stickers and pack rail to UIKit 6 UICollectionView.

Original supplied assets copied from newtgres:
- LegacyComponentsResources.bundle/StickerKeyboardRecentTab (1x and 2x)
- ConversationInputFieldKeyboardIcon (2x)
- StickersPlaceholderIcon (2x)

The picker stays open during emoji insertion and sticker sends. Successfully sent stickers update local recents. Server catalog, recent list and pack documents use the client's account cache; image files use the existing media cache. Visible images have a two-request limit and a 4 MB decoded thumbnail cache. Animated/video stickers use static previews in the keyboard; message playback is unchanged.

There is no obsolete fullscreen picker or next/previous page navigation. Unloaded packs temporarily show their names; visible pack icons load progressively. Pack search, featured packs, GIF search and favorites are not implemented by this change.

## Expansion 0.13.0

Added native catalogue search and featured packs, install/uninstall and favorites. Keyboard also displays saved GIFs and links to @gif search. Custom emoji pack selection sends document IDs, while text currently shows the emoji fallback. Pack mutations refresh existing keyboards. Pin and Select context menu icons are rasterized from the supplied Telegram-iOS PDF originals by asset-build/render-context-icons.swift (1x and 2x).
