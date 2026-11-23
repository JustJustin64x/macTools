#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app_dir="$project_dir/dist/macTools.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$app_dir/Contents/Helpers"
cp "$bin_dir/macTools" "$app_dir/Contents/MacOS/macTools"
clang -Wall -Wextra -Werror -O2 -mmacosx-version-min=14.0 \
    -I Sources/FinderKeys/include Sources/FinderKeys/FinderKeys.m Tools/finder-keys/main.m \
    -framework AppKit -framework ApplicationServices -framework Carbon \
    -o "$app_dir/Contents/Helpers/finder_keys"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
swift scripts/generate-icon.swift "$project_dir/dist/AppIcon.iconset"
iconutil -c icns "$project_dir/dist/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
# Finder/iCloud can attach metadata to generated bundles in Documents.
# Clear only build output before signing; source files are untouched.
xattr -cr "$app_dir"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --identifier io.github.justjustin64x.macTools.finder-keys "$app_dir/Contents/Helpers/finder_keys"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --identifier io.github.justjustin64x.macTools "$app_dir"
codesign --verify --strict "$app_dir"
printf 'App erstellt: %s\n' "$app_dir"
