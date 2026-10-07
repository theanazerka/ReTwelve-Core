#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$ROOT/call-transport/src/libsrtp"
BUILD="$ROOT/call-transport/build/libsrtp-armv7"
SDK="${THEOS:-$HOME/theos}/sdks/iPhoneOS6.1.sdk"

cmake -S "$SOURCE" -B "$BUILD" -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SDK" \
  -DCMAKE_OSX_ARCHITECTURES=armv7 -DCMAKE_OSX_DEPLOYMENT_TARGET=6.0 \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DBUILD_SHARED_LIBS=OFF -DENABLE_OPENSSL=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD" --target srtp2 -j4
echo "Built $BUILD/libsrtp2.a"
