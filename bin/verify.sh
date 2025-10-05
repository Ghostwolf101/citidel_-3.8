#!/usr/bin/env bash
set -euo pipefail
f="${1:?path to file}"
expect="${2:?sha256 hex}"
actual="$(sha256sum "$f" | awk '{print $1}')"
[[ "$actual" == "$expect" ]] || { echo "FAIL sha256 $f"; exit 1; }
mkdir -p "$HOME/citadel_onboard/manifests"
echo "$actual  $f" | tee "$HOME/citadel_onboard/manifests/$(basename "$f").sha256"

