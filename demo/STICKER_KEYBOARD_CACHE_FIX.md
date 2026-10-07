# Sticker keyboard preview cache — 0.13.8

The keyboard owned an isolated image NSCache. A keyboard created for a different chat started empty and decoded every visible preview again, even where the original bytes were already cached.

Preview images now live in a bounded cache owned by the account client (4 MiB, at most 128 entries). Only visible grid items and visible pack icons are pinned while the keyboard is on screen. Pins are removed when the keyboard detaches; neither full animation frames nor entire packs are retained.

Prepared transparent PNG previews (maximum 128 pixels) are persisted under the account's existing media cache. The load path is shared memory cache, then background disk read, then source-byte fetch and decode. These files have the sticker- prefix so existing storage sizing and sticker-cache removal include them. Clearing the sticker cache also clears the shared preview memory cache. The decoder continues saving completed previews if the initiating keyboard disappears.

Unchanged recent/favorite document IDs no longer reload the grid or reset its scroll position after metadata refresh. Failed downloads retry when the keyboard reopens.

Armv7 compilation and IPA packaging are verified. Repeated opening, chat switching and restart behavior still require device observation.
