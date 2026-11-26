#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
configuration="${CONFIGURATION:-release}"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/macTools-build.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT
app_dir="$build_root/macTools.app"
parts_dir="$project_dir/dist/parts"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$app_dir/Contents/Helpers" "$parts_dir"
main_bins=(); updater_bins=(); helper_bins=(); launcher_bins=()
for arch in ${MACTOOLS_ARCHS:-$(uname -m)}; do
    case "$arch" in arm64|x86_64) ;; *) echo "Unbekannte Architektur: $arch" >&2; exit 1 ;; esac
    mkdir -p "$parts_dir/$arch"
    swift build -c "$configuration" --arch "$arch"
    bin_dir="$(swift build -c "$configuration" --arch "$arch" --show-bin-path)"
    main_bins+=("$bin_dir/macTools")
    updater_bins+=("$bin_dir/MacToolsUpdate")
    clang -arch "$arch" -Wall -Wextra -Werror -O2 -mmacosx-version-min=14.0 \
        -I Sources/FinderKeys/include Sources/FinderKeys/FinderKeys.m Tools/finder-keys/main.m \
        -framework AppKit -framework ApplicationServices -framework Carbon \
        -o "$parts_dir/$arch/finder_keys"
    clang -arch "$arch" -Wall -Wextra -Werror -O2 -mmacosx-version-min=14.0 \
        scripts/Launcher.m -framework Foundation -o "$parts_dir/$arch/macToolsLauncher"
    helper_bins+=("$parts_dir/$arch/finder_keys")
    launcher_bins+=("$parts_dir/$arch/macToolsLauncher")
done
combine() {
    local output="$1"; shift
    if [ "$#" -eq 1 ]; then cp "$1" "$output"; else lipo -create "$@" -output "$output"; fi
}
combine "$app_dir/Contents/MacOS/macTools" "${main_bins[@]}"
combine "$app_dir/Contents/Helpers/macToolsUpdate" "${updater_bins[@]}"
combine "$app_dir/Contents/Helpers/finder_keys" "${helper_bins[@]}"
combine "$app_dir/Contents/Helpers/macToolsLauncher" "${launcher_bins[@]}"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp scripts/install-app.sh "$app_dir/Contents/Resources/install-app.sh"
chmod +x "$app_dir/Contents/Resources/install-app.sh"
commit="$(git rev-parse HEAD 2>/dev/null || echo local)"
epoch="$(git log -1 --format=%ct 2>/dev/null || date +%s)"
if [ -n "$(git status --porcelain --untracked-files=normal 2>/dev/null)" ]; then commit="$commit-dirty"; epoch="$(date +%s)"; fi
/usr/bin/plutil -replace CFBundleShortVersionString -string "${MACTOOLS_VERSION:-0.2.0}" "$app_dir/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "${MACTOOLS_BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}" "$app_dir/Contents/Info.plist"
/usr/bin/plutil -insert MacToolsCommit -string "$commit" "$app_dir/Contents/Info.plist"
/usr/bin/plutil -insert MacToolsSourceEpoch -integer "$epoch" "$app_dir/Contents/Info.plist"
swift scripts/generate-icon.swift "$project_dir/dist/AppIcon.iconset"
iconutil -c icns "$project_dir/dist/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
xattr -cr "$app_dir"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --identifier io.github.justjustin64x.macTools.finder-keys "$app_dir/Contents/Helpers/finder_keys"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --identifier io.github.justjustin64x.macTools.updater "$app_dir/Contents/Helpers/macToolsUpdate"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --identifier io.github.justjustin64x.macTools.LauncherBinary "$app_dir/Contents/Helpers/macToolsLauncher"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --identifier io.github.justjustin64x.macTools "$app_dir"
codesign --verify --deep --strict "$app_dir"
mkdir -p "$project_dir/dist/macTools.app"
/usr/bin/rsync -ac --delete "$app_dir/" "$project_dir/dist/macTools.app/"
printf 'App erstellt: %s\n' "$project_dir/dist/macTools.app"
