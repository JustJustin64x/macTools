#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"
"$project_dir/scripts/install-app.sh" "$project_dir/dist/macTools.app"
# Enable deployment hooks only in this checkout, preserving any unrelated hooks.
existing_hooks="$(git -C "$project_dir" config --local --get core.hooksPath || true)"
if [ -z "$existing_hooks" ] || [ "$existing_hooks" = '.githooks' ]; then
    git -C "$project_dir" config --local core.hooksPath .githooks
else
    printf 'Vorhandene Git-Hooks bleiben unverändert: %s\n' "$existing_hooks"
fi
