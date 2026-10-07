#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${1:-armv7}
FFSOURCE=/Users/anazerka/Telegram-iOS/submodules/ffmpeg/Sources/FFMpeg/ffmpeg-7.1.1
PREFIX="$ROOT/sticker-codecs/video-$ARCH"
BUILD="$ROOT/sticker-codecs/build-video-$ARCH"
CLANG=$(xcrun --find clang)
if [ "$ARCH" = armv7 ]; then
 SDK=/Users/anazerka/theos/sdks/iPhoneOS6.1.sdk
 FLAGS="-arch armv7 -isysroot $SDK -miphoneos-version-min=6.0"
 FFARCH=arm
elif [ "$ARCH" = arm64 ]; then
 SDK=$(xcrun --sdk iphoneos --show-sdk-path)
 FLAGS="-arch arm64 -isysroot $SDK -miphoneos-version-min=12.0"
 FFARCH=aarch64
else
 SDK=$(xcrun --sdk macosx --show-sdk-path)
 FLAGS="-isysroot $SDK"
 FFARCH=$(uname -m)
fi
mkdir -p "$BUILD/vpx" "$BUILD/ffmpeg" "$PREFIX"
cd "$BUILD/vpx"
CC="$CLANG" CXX="$(xcrun --find clang++)" CFLAGS="$FLAGS -O2" CXXFLAGS="$FLAGS -O2" LDFLAGS="$FLAGS" \
 "$ROOT/sticker-codecs/src/libvpx/configure" --target=generic-gnu --prefix="$PREFIX" \
 --disable-examples --disable-tools --disable-docs --disable-unit-tests --disable-shared \
 --disable-vp8 --disable-vp9-encoder --disable-webm-io --disable-runtime-cpu-detect --enable-pic
make -j4
make install
cd "$BUILD/ffmpeg"
CROSS=""
if [ "$ARCH" != host ]; then CROSS="--enable-cross-compile --target-os=darwin --arch=$FFARCH"; fi
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" "$FFSOURCE/configure" $CROSS --cc="$CLANG" --prefix="$PREFIX" \
 --host-cc="$CLANG" --host-cflags="-isysroot $(xcrun --sdk macosx --show-sdk-path)" --host-ldflags="-isysroot $(xcrun --sdk macosx --show-sdk-path)" \
 --extra-cflags="$FLAGS -I$PREFIX/include -Dstatic_assert=_Static_assert" --extra-ldflags="$FLAGS -L$PREFIX/lib" --extra-libs=-lvpx \
 --disable-autodetect --disable-programs --disable-doc --disable-debug --disable-shared --enable-static --enable-pic \
 --disable-everything --disable-asm --disable-network --disable-avdevice --disable-avfilter \
 --disable-swresample --enable-avcodec --enable-avformat --enable-avutil --enable-swscale \
 --enable-libvpx --enable-decoder=libvpx_vp9 --enable-demuxer=matroska --enable-protocol=file
make -j4
make install
