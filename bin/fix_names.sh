#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/citadel_onboard"

for dir in inspected chunks; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*; do
    [ -e "$f" ] || continue
    new="${f// /_}"
    if [[ "$f" != "$new" ]]; then
      echo "Renaming: $f -> $new"
      mv "$f" "$new"
      git add "$new"
      git rm -f --cached "$f" 2>/dev/null || true
    fi
  done
done

