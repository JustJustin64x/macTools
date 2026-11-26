#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
[ "${MACTOOLS_SKIP_AUTO_INSTALL:-0}" = '1' ] && exit 0
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo 'macTools: Lokale Installation verschoben, da noch nicht commitete Änderungen vorliegen.'
    exit 0
fi
base="${1:-HEAD^}"
if git rev-parse --verify "$base" >/dev/null 2>&1; then
    changes="$(git diff --name-only "$base" HEAD)"
else
    changes="$(git ls-tree -r --name-only HEAD)"
fi
if ! printf '%s\n' "$changes" | /usr/bin/grep -Eq '^(Sources/|Resources/|Package.swift$|scripts/|Tools/.*\.(m|c|swift)$)'; then
    echo 'macTools: Keine installierbaren Codeänderungen.'
    exit 0
fi
printf 'macTools: Code-Update wird getestet, gebaut und installiert …\n'
make test
"$project_dir/scripts/install.sh"
