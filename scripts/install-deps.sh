#!/usr/bin/env bash
# Create .venv once and reinstall only when requirement files change.  Usage: install-deps.sh [test|security|all]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
mode="${1:-test}"; files=()
case "$mode" in test) files=(tests/requirements-test.txt);; security) files=(security/requirements-security.txt);;
  all) files=(tests/requirements-test.txt security/requirements-security.txt);; *) echo "usage: $0 test|security|all"; exit 2;; esac
[ -d .venv ] || python3 -m venv .venv
stamp=".venv/.stamp-$mode"; sum="$(cat app/requirements.txt "${files[@]}" | sha256sum | cut -d' ' -f1)"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$sum" ]; then echo "dependencies up to date ($mode) - skipping install"; exit 0; fi
.venv/bin/pip install --quiet --upgrade pip
for f in "${files[@]}"; do .venv/bin/pip install --quiet -r "$f"; done
echo "$sum" > "$stamp"; echo "dependencies installed ($mode)"
