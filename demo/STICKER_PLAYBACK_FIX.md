# Sticker panel and playback — 0.13.2

The sender still sends the original Telegram document. The reported loss of animation occurs in this client's playback, not at the recipient.

- The rlottie parsed-model cache previously used `ios6-sticker` for every file. Its key now includes the SHA-256 of the decompressed JSON.
- Each decoded frame array carries the original timeline duration; limiting frame count no longer changes playback speed.
- Failed downloads/decode attempts can retry after a delay. A visible cell preserves its frames when the memory cache evicts that animation.
- The input panel now has five sticker columns at 320 points, a compact set ribbon, a search shortcut, and icon controls using the provided modern Telegram assets. Thumbnails in the panel remain static to limit work on older devices.

Validation: armv7 package build and arm64 compile/link succeeded. `tests/TGStickerAnimationCacheTest.mm` loaded the real IntroPhone and Anvil TGS files sequentially with the same rlottie library, checked each timeline/FPS, and verified that rendered frames change. The fixtures have 180 and 47 frames respectively, exposing an incorrectly shared parsed model.

Build the host rlottie library with `-DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -DLOTTIE_MODULE=OFF -DLOTTIE_THREAD=OFF -DCMAKE_CXX_FLAGS=-Wno-error=sign-compare`. Then run:

```sh
clang++ -std=c++11 -fobjc-arc -Wno-deprecated-declarations -I demo/sticker-codecs/rlottie/inc demo/tests/TGStickerAnimationCacheTest.mm /tmp/twelve-rlottie-host/librlottie.a -framework Foundation -lz -o /tmp/twelve-sticker-cache-test
/tmp/twelve-sticker-cache-test SystemTGS/IntroPhone.tgs SystemTGS/Anvil.tgs
```

Device playback and panel appearance still need verification. WebM was not supported in 0.13.2; support added in 0.13.3 is documented in `VIDEO_STICKERS_FIX.md`.
