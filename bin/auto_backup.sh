#!/usr/bin/env bash
set -euo pipefail
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$HOME/citadel_onboard_backups"
mkdir -p "$DEST"
tar -C "$HOME" -czf "$DEST/citadel_$TS.tgz" citadel_onboard
# keep last 7
ls -1t "$DEST"/citadel_*.tgz | tail -n +8 | xargs -r rm -f

