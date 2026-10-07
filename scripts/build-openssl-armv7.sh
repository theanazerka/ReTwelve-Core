#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir/telegram-mtproto"

# The upstream script expects relative paths. Passing an absolute output path
# makes OpenSSL prepend the working directory to its install prefix.
bash submodules/openssl/build-openssl-bazel.sh \
  ../openssl-armv7 submodules/openssl armv7
