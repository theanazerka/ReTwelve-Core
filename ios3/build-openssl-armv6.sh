#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
arch=${1:-armv6}
case "$arch" in armv6|armv7) ;; *) echo "usage: $0 [armv6|armv7]" >&2; exit 2 ;; esac
sdk="${THEOS:-$HOME/theos}/sdks/iPhoneOS3.1.3.sdk"
archive="$project_dir/telegram-mtproto/submodules/openssl/openssl-1.1.1d.tar.gz"
build_dir="$script_dir/out/openssl-$arch"
source_dir="$build_dir/openssl-1.1.1d"
prefix="$build_dir/install"

test -f "$sdk/SDKSettings.plist"
test -f "$archive"
mkdir -p "$build_dir/cross"
ln -sfn "$(dirname "$sdk")" "$build_dir/cross/SDKs"
if [ ! -d "$source_dir" ]; then
    tar -xzf "$archive" -C "$build_dir"
fi
cd "$source_dir"
export CROSS_TOP="$build_dir/cross"
export CROSS_SDK="iPhoneOS3.1.3.sdk"
export CC="xcrun clang"
export CFLAGS="-arch $arch -miphoneos-version-min=3.1.3"

if [ ! -f Makefile ]; then
    ./Configure iphoneos-cross \
        no-shared no-asm no-engine no-async no-tests no-ssl no-ssl3 no-comp \
        --prefix="$prefix"
fi
make -j4 build_libs
make install_sw
