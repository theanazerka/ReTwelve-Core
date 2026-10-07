# FlatUIKit theme 0.14.1

The optional flat theme uses the MIT licensed FlatUIKit source at commit
63fea9a86cadb2180173e29bf75fa978ec999fc6. UI7Kit's global runtime patch is no
longer linked. The saved TGUseUI7Kit preference is retained for compatibility.
The binary remains armv7 with iOS 6 deployment target and SDK 6 linkage.

## Navigation follow-up

0.14.0 opened on the test iPhone 5 (iOS 8.4.1), but the user reported a crash
when opening chats. The available CrashReporter report was for a different,
older bundle (0.13.0); it does not establish the cause of this new failure.

0.14.1 removes reparenting of UINavigationItem.titleView and UIBarButtonItem
customView during native navigation transitions. Independent proxy controls
mirror the source labels and images and forward taps to the source control.
Proxy content is updated only when its bounds or source content changes.
Bringing the flat panel to the front is conditional to prevent repeated
hierarchy changes during layout. An uncaught exception handler saves diagnostic
stack information to Library/Caches/ReTwelve-last-exception.txt.

Build and package completed. Device installation and chat-opening verification
are tracked separately; a successful build does not establish crash resolution.
