#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/citadel_onboard"
Q="$ROOT/quarantine"
INS="$ROOT/inspected"
BIN="$ROOT/bin"
MAN="$ROOT/manifests"
LOG="$ROOT/logs"

mkdir -p "$INS" "$MAN" "$LOG"
sleep 2  # tiny debounce to let sidecars land

DATA_EXT_REGEX='\.((jsonl?)|(toml)|(yaml)|(yml)|(txt)|(mdx?)|(csv)|(tsv)|(ini)|(conf)|(log))$'
PARAMS_SUFFIX='.params.sh'

process_pair () {
  local f="$1"
  local base="$(basename "$f")"
  local sha_file="$f.sha256"

  [[ -f "$sha_file" ]] || { echo "SKIP: no sha256 sidecar for $base"; return 0; }
  local hash; hash="$(awk '{print $1; exit}' "$sha_file")"
  [[ "${#hash}" -eq 64 ]] || { echo "SKIP: bad sha256 for $base"; return 0; }

  echo "[onboard] verify $base"
  "$BIN/verify.sh" "$f" "$hash" || { echo "FAIL verify $base"; return 1; }

  echo "[onboard] promote $base -> inspected/"
  mv -f "$f" "$INS/$base"

  # normalize names
  [ -x "$BIN/fix_names.sh" ] && "$BIN/fix_names.sh" || true

  local dest="$INS/$base"
  [[ -f "$dest" ]] || dest="$INS/${base// /_}"

  # ACTION: data -> chunk; params -> safe_run (with denylist)
  local mode="data"
  local lower_dest="$(echo "$dest" | tr 'A-Z' 'a-z')"

  case "$lower_dest" in
    *.vault|*.key|*.pem|*.crt|*.der|*.so|*.bin|*.exe)
      echo "[onboard] skip binary/secret-like file: $dest"
      mode="skipped"
      ;;
    *.params.sh)
      echo "[onboard] denylist scan $(basename "$dest")"
      if grep -F -f "$ROOT/manifests/denylist.txt" "$dest"; then
        echo "✗ DENYLIST violation in $(basename "$dest"). Skipping execution."
        mode="denied"
        return 1
      fi
      echo "[onboard] safe_run $(basename "$dest")"
      if "$BIN/safe_run.sh" "$(basename "$dest")"; then
        mode="params"
      else
        echo "FAIL safe_run $(basename "$dest")"
        return 1
      fi
      ;;
    *)
      if [[ "$lower_dest" =~ $DATA_EXT_REGEX ]]; then
        echo "[onboard] chunk $dest"
        python3 "$BIN/chunk_text.py" "$dest" || true
        mode="data"
      else
        if file -b "$dest" | grep -qi 'text'; then
          echo "[onboard] chunk (sniffed text) $dest"
          python3 "$BIN/chunk_text.py" "$dest" || true
          mode="data"
        else
          echo "[onboard] treat as read-only non-text (no exec, no chunk): $dest"
          mode="read-only"
        fi
      fi
      ;;
  esac

  echo "[onboard] commit receipts"
  (
    cd "$ROOT"
    [ -x "$BIN/fix_names.sh" ] && "$BIN/fix_names.sh" || true
    git -c core.hooksPath=/dev/null add -A
    git -c core.hooksPath=/dev/null commit -m "Auto onboard: $(basename "$dest") [$mode]" || true
  )

  cp -f "$sha_file" "$MAN/$(basename "$dest").sha256" 2>/dev/null || true
  (
    cd "$ROOT"
    git -c core.hooksPath=/dev/null add "manifests/$(basename "$dest").sha256" || true
    git -c core.hooksPath=/dev/null commit -m "Track sha256 for $(basename "$dest")" || true
  )

  rm -f "$sha_file" || true
  echo "[onboard] done $(basename "$dest")"
}

shopt -s nullglob
for f in "$Q"/*; do
  [[ -f "$f" ]] || continue
  [[ "$f" == *.sha256 ]] && continue
  process_pair "$f"
done
