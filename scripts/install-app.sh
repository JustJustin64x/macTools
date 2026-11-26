#!/bin/bash
# Shared installer for local builds and downloaded releases. No build tools needed.
set -euo pipefail
incoming_app="$(cd "${1:?Aufruf: install-app.sh /Pfad/macTools.app}" && pwd)"
installed_app="$HOME/Applications/macTools.app"
support_dir="$HOME/Library/Application Support/macTools"
log_dir="$HOME/Library/Logs/macTools/updates"
agent_dir="$HOME/Library/LaunchAgents"
domain="gui/$(id -u)"
update_label="io.github.justjustin64x.macTools.updates"
mkdir -p "$(dirname "$installed_app")" "$support_dir/Backups" "$log_dir" "$agent_dir"
identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$incoming_app/Contents/Info.plist")"
[ "$identifier" = 'io.github.justjustin64x.macTools' ] || { echo 'Falsches App-Paket.' >&2; exit 1; }
install_lock="$support_dir/Install.lock"
if ! mkdir "$install_lock" 2>/dev/null; then
    lock_pid="$(cat "$install_lock/pid" 2>/dev/null || true)"
    case "$lock_pid" in
        ''|*[!0-9]*) echo 'Eine macTools-Installation läuft bereits.' >&2; exit 1 ;;
    esac
    if kill -0 "$lock_pid" 2>/dev/null; then echo 'Eine macTools-Installation läuft bereits.' >&2; exit 1; fi
    rm -f "$install_lock/pid"
    rmdir "$install_lock"
    mkdir "$install_lock"
fi
printf '%s\n' "$$" > "$install_lock/pid"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/macTools-install.XXXXXX")"
backup_app=''
modified=0
restart_gui=0
stopped_labels=()
stopped_plists=()
cleanup() {
    local status=$?
    trap - EXIT
    if [ "$status" -ne 0 ] && [ "$modified" -eq 1 ] && [ -n "$backup_app" ]; then
        echo 'Installation fehlgeschlagen; vorherige App wird wiederhergestellt.' >&2
        /usr/bin/rsync -ac --delete "$backup_app/" "$installed_app/" || true
    fi
    for ((i=0; i<${#stopped_labels[@]}; i++)); do
        /bin/launchctl bootstrap "$domain" "${stopped_plists[$i]}" 2>/dev/null || true
    done
    if [ "$restart_gui" -eq 1 ]; then /usr/bin/open "$installed_app" || true; fi
    /bin/rm -rf "$work_dir"
    rm -f "$install_lock/pid"
    rmdir "$install_lock" 2>/dev/null || true
    exit "$status"
}
trap cleanup EXIT
# Stage outside Documents/iCloud and validate before touching the live app.
/usr/bin/ditto "$incoming_app" "$work_dir/macTools.app"
# File-provider metadata in Documents is not code and may appear after signing.
# Strip only attributes forbidden by codesign, on the disposable staged copy.
/usr/bin/xattr -dr com.apple.FinderInfo "$work_dir/macTools.app" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.ResourceFork "$work_dir/macTools.app" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict "$work_dir/macTools.app"
if [ -d "$installed_app" ]; then
    backup_app="$support_dir/Backups/macTools-$(date +%Y%m%d-%H%M%S)-$$.app.backup"
    /usr/bin/ditto "$installed_app" "$backup_app"
fi
# Keep byte-identical helpers running. Their Accessibility grant remains tied to
# the same signed executable. Restart only tools whose actual helper changed.
shopt -s nullglob
for plist in "$agent_dir"/io.github.justjustin64x.macTools.*.plist; do
    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || true)"
    [ "$label" = "$update_label" ] && continue
    helper="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null || true)"
    case "$helper" in "$installed_app"/Contents/Helpers/*) ;; *) continue ;; esac
    relative="${helper#"$installed_app/"}"
    [ "${plist##*/}" = "$label.plist" ] || continue
    service_status="$(/bin/launchctl print "$domain/$label" 2>/dev/null || true)"
    if [ -f "$helper" ] && [ -f "$work_dir/macTools.app/$relative" ] && cmp -s "$helper" "$work_dir/macTools.app/$relative" && printf '%s' "$service_status" | grep -q 'state = running'; then continue; fi
    if [ -n "$service_status" ]; then /bin/launchctl bootout "$domain/$label"; fi
    stopped_labels+=("$label")
    stopped_plists+=("$plist")
 done
# macTools stores settings outside its bundle; it has no unsaved documents.
gui_pids="$(/usr/bin/pgrep -f -x "$installed_app/Contents/MacOS/macTools" || true)"
if [ -n "$gui_pids" ]; then
    restart_gui=1
    for pid in $gui_pids; do kill -TERM "$pid"; done
fi
modified=1
# --checksum avoids rewriting unchanged signed helpers; --delete removes stale
# bundle resources. The enclosing installed .app directory is never moved.
/usr/bin/rsync -ac --delete "$work_dir/macTools.app/" "$installed_app/"
/usr/bin/codesign --verify --deep --strict "$installed_app"

# A small, stable native starter in /Applications makes the current app visible
# to Spotlight without moving the existing helper/Accessibility paths.
launcher_root="/Applications"
if [ ! -w "$launcher_root" ]; then launcher_root="$HOME/Applications"; fi
launcher_app="$launcher_root/macTools.app"
if [ "$launcher_app" != "$installed_app" ]; then
    mkdir -p "$launcher_app/Contents/MacOS" "$launcher_app/Contents/Resources"
    if ! cmp -s "$installed_app/Contents/Helpers/macToolsLauncher" "$launcher_app/Contents/MacOS/macToolsLauncher"; then
        cp "$installed_app/Contents/Helpers/macToolsLauncher" "$launcher_app/Contents/MacOS/macToolsLauncher"
    fi
    cp "$installed_app/Contents/Resources/AppIcon.icns" "$launcher_app/Contents/Resources/AppIcon.icns"
    cat > "$launcher_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.justjustin64x.macTools.Launcher</string>
<key>CFBundleName</key><string>macTools</string>
<key>CFBundleDisplayName</key><string>macTools</string>
<key>CFBundleExecutable</key><string>macToolsLauncher</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
    /usr/bin/codesign --force --sign - --identifier io.github.justjustin64x.macTools.Launcher "$launcher_app"
    /usr/bin/codesign --verify --strict "$launcher_app"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$launcher_app"
    /usr/bin/mdimport "$launcher_app" || true
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$installed_app"
/usr/bin/mdimport "$installed_app" || true

update_plist="$work_dir/$update_label.plist"
/usr/bin/plutil -create xml1 "$update_plist"
/usr/bin/plutil -insert Label -string "$update_label" "$update_plist"
/usr/bin/plutil -insert ProgramArguments -json '[]' "$update_plist"
/usr/bin/plutil -insert ProgramArguments.0 -string "$installed_app/Contents/Helpers/macToolsUpdate" "$update_plist"
/usr/bin/plutil -insert ProgramArguments.1 -string '--automatic' "$update_plist"
/usr/bin/plutil -insert RunAtLoad -bool YES "$update_plist"
/usr/bin/plutil -insert StartInterval -integer 900 "$update_plist"
/usr/bin/plutil -insert StandardOutPath -string "$log_dir/stdout.log" "$update_plist"
/usr/bin/plutil -insert StandardErrorPath -string "$log_dir/stderr.log" "$update_plist"
cp "$update_plist" "$agent_dir/$update_label.plist"
chmod 644 "$agent_dir/$update_label.plist"
# Never unload the updater that may currently be installing this very update.
if ! /bin/launchctl print "$domain/$update_label" >/dev/null 2>&1; then
    /bin/launchctl bootstrap "$domain" "$agent_dir/$update_label.plist"
fi
printf 'Installiert: %s\nSpotlight-Starter: %s\nAutomatische GitHub-Prüfung: alle 15 Minuten und bei Anmeldung.\n' "$installed_app" "$launcher_app"
