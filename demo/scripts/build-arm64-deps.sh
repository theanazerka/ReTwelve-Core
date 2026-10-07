#!/bin/sh
set -eu

demo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sdk="${THEOS:-$HOME/theos}/sdks/iPhoneOS16.5.sdk"
clang=$(xcrun --find clang)
target=arm64-apple-ios12.0

voice="$demo_dir/voice-codecs"
voice_prefix="$voice/out-arm64"
mkdir -p "$voice_prefix" "$voice/build-arm64"
export CC="$clang"
export CFLAGS="-target $target -isysroot $sdk -O2 -fPIC"
export LDFLAGS="-target $target -isysroot $sdk -L$voice_prefix/lib"
export CPPFLAGS="-I$voice_prefix/include"
export PKG_CONFIG_LIBDIR="$voice_prefix/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
build_voice() {
    name="$1"; source="$2"; library="$3"; shift 3
    if [ -f "$voice_prefix/lib/lib$library.a" ]; then return; fi
    mkdir -p "$voice/build-arm64/$name"
    cd "$voice/build-arm64/$name"
    "$voice/src/$source/configure" --host=aarch64-apple-darwin --prefix="$voice_prefix" \
        --disable-shared --enable-static "$@"
    make -j4
    make install
}
build_voice ogg libogg-1.3.5 ogg
build_voice opus opus-1.5.2 opus --disable-extra-programs --disable-doc
build_voice opusfile opusfile-0.12 opusfile --disable-http --disable-examples

webp="$demo_dir/sticker-codecs"
webp_prefix="$webp/out-arm64"
if [ ! -f "$webp_prefix/lib/libwebpdecoder.a" ]; then
    mkdir -p "$webp/build-arm64" "$webp_prefix"
    cd "$webp/build-arm64"
    CC="$clang" CFLAGS="-target $target -isysroot $sdk -O2 -fPIC" \
        LDFLAGS="-target $target -isysroot $sdk" \
        "$webp/src/libwebp-1.5.0/configure" --host=aarch64-apple-darwin \
        --prefix="$webp_prefix" --disable-shared --enable-static \
        --enable-libwebpdecoder --disable-libwebpmux --disable-libwebpdemux \
        --disable-png --disable-jpeg --disable-gif
    make -j4
    make install
fi

juice="$demo_dir/call-transport"
if [ ! -f "$juice/out-arm64/lib/libjuice.a" ]; then
    mkdir -p "$juice/out-arm64/obj" "$juice/out-arm64/lib"
    for file in "$juice"/src/libjuice/src/*.c; do
        name=${file##*/}
        "$clang" -target "$target" -isysroot "$sdk" -std=c11 -Os \
            -DNO_SERVER -DUSE_NETTLE=0 -DJUICE_STATIC \
            -I"$juice/src/libjuice/include" -I"$juice/src/libjuice/include/juice" \
            -I"$juice/src/libjuice/src" -c "$file" \
            -o "$juice/out-arm64/obj/${name%.c}.o"
    done
    /usr/bin/libtool -static -o "$juice/out-arm64/lib/libjuice.a" "$juice"/out-arm64/obj/*.o
fi

if [ ! -f "$juice/build/libsrtp-arm64/libsrtp2.a" ]; then
    cmake -S "$juice/src/libsrtp" -B "$juice/build/libsrtp-arm64" -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DBUILD_SHARED_LIBS=OFF -DENABLE_OPENSSL=OFF -DCMAKE_BUILD_TYPE=Release
    cmake --build "$juice/build/libsrtp-arm64" --target srtp2 -j4
fi

if [ ! -f "$webp/build-rlottie-arm64/librlottie.a" ]; then
    cmake -S "$webp/rlottie" -B "$webp/build-rlottie-arm64" -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_CXX_FLAGS='-Wno-error=sign-compare -U__ARM_NEON__'
    cmake --build "$webp/build-rlottie-arm64" --target rlottie -j4
fi
