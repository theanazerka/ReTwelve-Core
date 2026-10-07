#!/bin/sh
set -eu

demo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
root="$demo_dir/sticker-codecs"
archive="$root/dist/libwebp-1.5.0.tar.gz"
sdk="${THEOS:-$HOME/theos}/sdks/iPhoneOS16.5.sdk"
prefix="$root/out"
mkdir -p "$root/dist" "$root/src" "$root/build" "$prefix"
if [ ! -f "$archive" ]; then
    curl -L --fail --silent --show-error \
        https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.5.0.tar.gz \
        -o "$archive"
fi
actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
if [ "$actual" != 7d6fab70cf844bf6769077bd5d7a74893f8ffd4dfb42861745750c63c2a5c92c ]; then
    echo "Checksum mismatch: libwebp" >&2
    exit 1
fi
if [ ! -d "$root/src/libwebp-1.5.0" ]; then tar -xzf "$archive" -C "$root/src"; fi
if [ -f "$prefix/lib/libwebpdecoder.a" ]; then exit 0; fi
cd "$root/build"
CC="$(xcrun --find clang)" \
CFLAGS="-target armv7-apple-ios6.0 -isysroot $sdk -O2 -fPIC" \
LDFLAGS="-target armv7-apple-ios6.0 -isysroot $sdk" \
"$root/src/libwebp-1.5.0/configure" --host=arm-apple-darwin --prefix="$prefix" \
    --disable-shared --enable-static --enable-libwebpdecoder \
    --disable-libwebpmux --disable-libwebpdemux --disable-png --disable-jpeg --disable-gif
make -j4
make install
