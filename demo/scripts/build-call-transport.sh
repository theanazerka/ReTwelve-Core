#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$ROOT/call-transport/src/libjuice"
OUTPUT="$ROOT/call-transport/out"
SDK="${THEOS:-$HOME/theos}/sdks/iPhoneOS6.1.sdk"
CC=$(xcrun --find clang)

mkdir -p "$OUTPUT/obj" "$OUTPUT/lib"
for file in "$SOURCE"/src/*.c; do
    name=${file##*/}
    "$CC" -target armv7-apple-ios6.0 -isysroot "$SDK" -std=c11 -Os \
        -DNO_SERVER -DUSE_NETTLE=0 -DJUICE_STATIC \
        -I"$SOURCE/include" -I"$SOURCE/include/juice" -I"$SOURCE/src" \
        -c "$file" -o "$OUTPUT/obj/${name%.c}.o"
done
/usr/bin/libtool -static -o "$OUTPUT/lib/libjuice.a" "$OUTPUT"/obj/*.o
echo "Built $OUTPUT/lib/libjuice.a"
