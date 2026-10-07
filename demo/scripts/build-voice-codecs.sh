#!/bin/sh
set -eu

demo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
root="$demo_dir/voice-codecs"
sdk="${THEOS:-$HOME/theos}/sdks/iPhoneOS16.5.sdk"
clang=$(xcrun --find clang)
prefix="$root/out"
mkdir -p "$root/dist" "$root/src" "$prefix"

fetch_source() {
    name="$1"
    url="$2"
    sha="$3"
    archive="$root/dist/$name.tar.gz"
    if [ ! -f "$archive" ]; then curl -L --fail --silent --show-error "$url" -o "$archive"; fi
    actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
    if [ "$actual" != "$sha" ]; then echo "Checksum mismatch: $name" >&2; exit 1; fi
    if [ ! -d "$root/src/$name" ]; then tar -xzf "$archive" -C "$root/src"; fi
}

fetch_source libogg-1.3.5 https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz 0eb4b4b9420a0f51db142ba3f9c64b333f826532dc0f48c6410ae51f4799b664
fetch_source opus-1.5.2 https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz 65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1
fetch_source opusfile-0.12 https://downloads.xiph.org/releases/opus/opusfile-0.12.tar.gz 118d8601c12dd6a44f52423e68ca9083cc9f2bfe72da7a8c1acb22a80ae3550b

export CC="$clang"
export CFLAGS="-target armv7-apple-ios6.0 -isysroot $sdk -O2 -fPIC"
export CPPFLAGS="-I$prefix/include"
export LDFLAGS="-target armv7-apple-ios6.0 -isysroot $sdk -L$prefix/lib"
export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"

build_one() {
    name="$1"
    source_name="$2"
    library_name="$3"
    shift 3
    if [ -f "$prefix/lib/lib${library_name}.a" ]; then return; fi
    mkdir -p "$root/build/$name"
    cd "$root/build/$name"
    "$root/src/$source_name/configure" --host=arm-apple-darwin --prefix="$prefix" \
        --disable-shared --enable-static "$@"
    make -j4
    make install
}

build_one ogg libogg-1.3.5 ogg
build_one opus opus-1.5.2 opus --disable-extra-programs --disable-doc
build_one opusfile opusfile-0.12 opusfile --disable-http --disable-examples
