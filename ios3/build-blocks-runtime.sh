#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sdk="${THEOS:-$HOME/theos}/sdks/iPhoneOS3.1.3.sdk"
for arch in armv6 armv7; do
    output="$script_dir/out/$arch"
    mkdir -p "$output"
    for source in data runtime; do
        xcrun clang -target "$arch-apple-ios3.1.3" -isysroot "$sdk" \
            -miphoneos-version-min=3.1.3 -std=gnu99 -O2 \
            -I"$script_dir/blocks-runtime" \
            -c "$script_dir/blocks-runtime/$source.c" -o "$output/$source.o"
    done
    xcrun ar rcs "$output/libBlocksRuntime.a" "$output/data.o" "$output/runtime.o"
done
