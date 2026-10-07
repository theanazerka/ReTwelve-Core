# WebM sticker playback — 0.13.3

The previous release handled only Lottie/TGS animations. The chat classified WebM sticker documents correctly but downloaded only their preview and never decoded the video.

This release downloads the original WebM document through the existing media cache and renders VP9 plus its alpha stream using FFmpeg's `libvpx-vp9` decoder. Frames are scaled to 160 pixels on Retina (128 otherwise), converted to premultiplied BGRA, and played by the existing sticker view with the source duration. Decoding uses the serial background sticker queue. TGS playback remains supported.

The decoder accepts only bounded VP9 WebM sticker inputs: at most 512 KB, 512 × 512 pixels, approximately three seconds. It limits output frames, preserves aspect ratio, and releases demuxer, codec, scaler, packet and pixel buffers on failure. Malformed input leaves the downloaded thumbnail visible instead of installing an incomplete animation.

Validation used these original Telegram fixtures:

- `Telegram-iOS/Tests/AnimationCacheTest/Resources/sticker.webm`: 58 rendered frames, 2.417 seconds.
- `Telegram-iOS/Telegram/WatchApp/Assets/SampleStickers/sticker_vp9.webm`: 19 rendered frames, 0.800 seconds.

Both produced changing frames with transparent and opaque pixels and valid premultiplied colors. Truncated and invalid files were rejected. These are host checks; device smoothness still needs verification.

Dependencies are built by `scripts/build-video-sticker-codecs.sh armv7`, `arm64`, or `host`. It uses the user's FFmpeg 7.1.1 sources and libvpx 1.15.0 from https://github.com/webmproject/libvpx/tree/v1.15.0, downloaded into `sticker-codecs/src/libvpx`. The build enables only the required VP9 decoder and Matroska/WebM demuxer, with no network support. Notices are included in `Resources/Licenses`. Source files, static libraries and application object files remain available locally for relinking.

Host regression test:

```sh
clang -std=c11 -isysroot "$(xcrun --sdk macosx --show-sdk-path)" -I demo/sticker-codecs/video-host/include demo/TGVideoStickerDecoder.c demo/tests/TGVideoStickerDecoderTest.c demo/sticker-codecs/video-host/lib/libavformat.a demo/sticker-codecs/video-host/lib/libavcodec.a demo/sticker-codecs/video-host/lib/libswscale.a demo/sticker-codecs/video-host/lib/libavutil.a demo/sticker-codecs/video-host/lib/libvpx.a -lm -lpthread -o /tmp/twelve-webm-test
/tmp/twelve-webm-test /Users/anazerka/Telegram-iOS/Tests/AnimationCacheTest/Resources/sticker.webm /Users/anazerka/Telegram-iOS/Telegram/WatchApp/Assets/SampleStickers/sticker_vp9.webm
```
