#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/citadel_onboard"
INS="$ROOT/inspected"
MAN="$ROOT/manifests"
LOG="$ROOT/logs"
ALW="$MAN/allowlist.txt"
DEN="$MAN/denylist.txt"
file="${1:?relative path in inspected/ or absolute}"

[[ "$file" == /* ]] || file="$INS/$file"
[[ -f "$file" ]] || { echo "No such file: $file"; exit 1; }

mkdir -p "$LOG"
exec >>"$LOG/safe_run.log" 2>&1
echo "[$(date -Iseconds)] START $file"

# denylist scan
if grep -E -q "$(paste -sd'|' "$DEN")" "$file"; then
  echo "DENY: forbidden token found"; exit 1
fi

# allowlist check (first word of each non-comment line)
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue
  cmd="$(echo "$line" | awk '{print $1}')"
  grep -qx "$cmd" "$ALW" || { echo "BLOCK: $cmd not in allowlist"; exit 1; }
done < "$file"

# restricted environment
export PATH="/usr/bin:/bin"
umask 077
bash "$file"
rc=$?
echo "[$(date -Iseconds)] END $file rc=$rc"
exit $rc

