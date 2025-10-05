#!/usr/bin/env bash
set -euo pipefail
SRC="${1:?quarantine file}"
SHA="${2:?sha256}"

ROOT="$HOME/citadel_onboard"
"$ROOT/bin/verify.sh" "$SRC" "$SHA"
base="$(basename "$SRC")"
mv "$SRC" "$ROOT/inspected/$base"
case "$base" in
  *.json|*.toml|*.txt|*.md)
    python3 "$ROOT/bin/chunk_text.py" "$ROOT/inspected/$base"
    ;;
esac
echo "Promoted $base"

