# MtProtoKit for iOS 6

This workspace builds the current Telegram `MtProtoKit` and
`OpenSSLEncryptionProvider` sources as an armv7 static library with an iOS 6.0
deployment target. It uses the iPhoneOS 16.5 SDK headers for compilation because
the iOS 6 SDK cannot parse the current sources. The probe is linked against the
iOS 6 SDK to catch direct references to unavailable symbols. Device runtime
testing is still required.

## Build

```sh
./scripts/build-openssl-armv7.sh
make -j4
make smoke-link
make probe-link
```

Outputs:

- `.theos/obj/debug/armv7/MtProtoKitIOS6.a`
- `openssl-armv7/out/lib/libcrypto.a`
- `.theos/obj/debug/armv7/link_smoke` (link check, not an installable app)
- `.theos/obj/debug/armv7/mtproto-probe` (signed command line probe for a jailbroken iOS 6 device)

On the device, run `mtproto-probe IP PORT DC_ID API_ID` using a **test DC** address
from your Telegram API development tools page. It attempts to create an auth key
and reports success or failure within 90 seconds. Add `--prod` only when using a
production DC address. The probe keeps the key in memory and does not log it.

When linking an iOS app, include both `.a` files, the public headers under
`telegram-mtproto/submodules/{MtProtoKit,EncryptionProvider,OpenSSLEncryptionProvider}/PublicHeaders`,
and the frameworks and libraries listed in `smoke-link` in the Makefile.

`compat/os/lock.h` replaces `os_unfair_lock` with iOS 6's `OSSpinLock`. This is
only a compatibility bridge; a production client should review lock contention
and priority inversion. `compat/MTHttpRequestOperation.m` uses
`NSURLConnection` because `NSURLSession` starts at iOS 7. Its disposable
suppresses delivery after cancellation but does not stop an in-flight request.

The library is the MTProto transport and cryptography layer. The app below adds
login and basic chats. The library itself still needs device level testing
across network conditions.

## Telegram Legacy for iOS 6

The `demo/` application requests a code, signs in with it, supports Telegram's
SRP based 2FA password, stores MTProto auth keys in the iOS Keychain with a
protected Library copy for older device compatibility, lists the first 50
dialogs per folder, displays the latest 50 messages in a chat, and sends text
and voice messages. Incoming Ogg/Opus voice messages play through statically linked
libogg, libopus, and opusfile; holding the microphone button records and sends Opus.
The chat list starts loading avatars before their rows become visible.
Static WebP stickers display in chats using a bundled armv7 libwebp decoder;
animated TGS and video WebM stickers display Telegram's still preview when
available. Sticker files are cached on disk after download. Sticker animation
and sending stickers are not implemented.
It uses TL schema layer 229 from the Telegram Desktop source
(https://github.com/telegramdesktop/tdesktop/blob/dev/Telegram/SourceFiles/mtproto/scheme/api.tl). App credentials are read from
`demo/LocalConfig.h` (ignored by Git). The server chooses how to deliver a code.

```sh
./demo/scripts/build-voice-codecs.sh
./demo/scripts/build-sticker-codec.sh
make -C demo clean FINALPACKAGE=1 package
./demo/scripts/package-ipa.sh
```

The installable package is
`demo/packages/com.anazerka.telegramcodedemo_0.8.0_iphoneos-arm.deb`.
An IPA of the same app is `demo/TelegramCodeDemo-iOS6.ipa` for installation
methods that accept jailbroken iOS 6 IPA files.
Install it on a jailbroken iOS 6 device with your package manager, then refresh
the home screen icon with `uicache` if needed. The executable is linked against
the iOS 6 SDK and has an iOS 6.0 deployment target. The Opus encode/decode path
was tested on macOS with a one-second sample; device recording, playback, and
upload still need testing on iOS 6. Code delivery was confirmed
by the user, as were sign in and chat access with the previous build. The new
classic interface, layer 229, communities, forum topics, and cold launch session restoration still need a device test.
The chat view hides the tabs; read-only channels show a notifications control instead of the composer. Visible dialogs
fetch small profile photos from their media datacenters, showing placeholders
until photos arrive. Group messages show sender avatars, photo messages decode
to at most 480 pixels, and channel posts remain left aligned with author
signatures at the bottom. Tapping the chat name opens an action panel based on
the original Telegram assets. Dialogs and message histories
are cached in the app Library for offline reading after an initial online sync.
Text message bubbles use the original Telegram image assets and its 40×31 pt
minimum size, 5 pt vertical padding, 26 pt combined horizontal padding, and
3 pt row margin.
Voice bubbles show a play/pause circle, the voice message's 5-bit waveform,
duration, and message time. New outgoing voice messages include a generated
waveform in their Telegram document attributes.
The supplied microphone and paper-plane icons appear in the composer. Voice
playback updates its button without reloading message rows. The chat uses the
original iOS Telegram `TGTableView` and `TGConversationItemView` code from the
user-provided sources: the list is inverted, the newest message occupies row 0,
and inserted messages use the original cell translation animation. Text messages
appear immediately, then reconcile with the server response. The chat table
resizes above the keyboard so its newest messages remain visible. The copied
classes are covered by the original GPL v2 or later license in
`demo/Resources/OriginalTelegram/LICENSE`.
While foregrounded, dialogs poll every 10 seconds; the open chat checks its latest
message every 5 seconds and reloads full history when it changes or once per minute.
Background push updates are not implemented. This is an initial client: other media,
full pagination, live
updates in the UI, and account creation are not implemented yet.

The classic UI uses selected images from the original Telegram iPhone sources
provided by the user. Those assets and the accompanying GPL version 2 license
are in `demo/Resources/OriginalTelegram/`.
The older mini-thumbnail JPEG header and its MIT license remain bundled in
`demo/Resources/`, though the interface no longer stretches those thumbnails.
