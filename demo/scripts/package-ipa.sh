#!/bin/sh
set -eu

demo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app="$demo_dir/.theos/_/Applications/TelegramCodeDemo.app"
output="$demo_dir/TelegramCodeDemo-iOS6.ipa"

if [ ! -f "$app/TelegramCodeDemo" ] || [ ! -f "$app/Info.plist" ]; then
    echo "Build the app first: make -C demo clean FINALPACKAGE=1 package" >&2
    exit 1
fi

mkdir -p "$demo_dir/dist/Payload"
rm -rf "$demo_dir/dist/Payload/TelegramCodeDemo.app"
ditto "$app" "$demo_dir/dist/Payload/TelegramCodeDemo.app"
cd "$demo_dir/dist"
zip -q -r -FS "$output" Payload
echo "$output"
