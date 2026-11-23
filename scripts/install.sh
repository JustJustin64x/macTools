#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"
install_dir="$HOME/Applications"
mkdir -p "$install_dir"
# Keep the installed bundle at its stable path so privacy bookmarks don't follow
# a moved old app. Backups are not named .app to avoid duplicate app registration.
if [ -e "$install_dir/macTools.app" ]; then
    backup_dir="$HOME/Library/Application Support/macTools/Backups"
    mkdir -p "$backup_dir"
    ditto "$install_dir/macTools.app" "$backup_dir/macTools-$(date +%Y%m%d-%H%M%S)-$$.app.backup"
fi
ditto "$project_dir/dist/macTools.app" "$install_dir/macTools.app"
codesign --verify --strict "$install_dir/macTools.app"
printf 'Installiert: %s\n' "$install_dir/macTools.app"
