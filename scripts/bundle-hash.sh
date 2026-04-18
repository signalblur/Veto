#!/usr/bin/env bash
#
# bundle-hash.sh
#
# Computes the canonical resource hash of a built Veto.app bundle. The
# output MUST equal the value displayed on the device's About screen for
# the same source SHA, because both run BundleHasher.canonicalHash over
# the same input set in the same order.
#
# Canonical input (in order):
#   1. Every .json file under <App>/Packs/ (sorted by filename)
#   2. Every regular file under <App>/VetoClassifier.mlmodelc/ (sorted by
#      relative path), if present.
# Each section: filename + 0x0A + bytes + 0x0A.
#
# Usage:
#   scripts/bundle-hash.sh path/to/Veto.app
# Output:
#   sha256:<64 hex chars>

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/Veto.app" >&2
  exit 1
fi

APP_PATH="$1"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Not a directory: $APP_PATH" >&2
  exit 1
fi

PACKS_DIR="$APP_PATH/Packs"
MODEL_DIR="$APP_PATH/VetoClassifier.mlmodelc"

emit_section() {
  local name="$1"
  local path="$2"
  printf '%s\n' "$name"
  cat "$path"
  printf '\n'
}

{
  if [[ -d "$PACKS_DIR" ]]; then
    while IFS= read -r f; do
      emit_section "$(basename "$f")" "$f"
    done < <(find "$PACKS_DIR" -maxdepth 1 -name '*.json' -type f | LC_ALL=C sort)
  fi

  if [[ -d "$MODEL_DIR" ]]; then
    while IFS= read -r relpath; do
      emit_section "$relpath" "$MODEL_DIR/$relpath"
    done < <(cd "$MODEL_DIR" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
  fi
} | shasum -a 256 | awk '{print "sha256:" $1}'
