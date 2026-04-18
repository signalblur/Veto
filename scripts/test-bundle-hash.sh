#!/usr/bin/env bash
#
# test-bundle-hash.sh
#
# CI determinism check. Builds twice in a row and asserts the bundle hash
# is byte-identical. Catches regressions in build reproducibility before
# they reach a release.

set -euo pipefail

cd "$(dirname "$0")/.."

scripts/build-release.sh
HASH1=$(scripts/bundle-hash.sh build/Veto.xcarchive/Products/Applications/Veto.app)

scripts/build-release.sh
HASH2=$(scripts/bundle-hash.sh build/Veto.xcarchive/Products/Applications/Veto.app)

echo "Build 1: $HASH1"
echo "Build 2: $HASH2"

if [[ "$HASH1" != "$HASH2" ]]; then
  echo "Build is NOT reproducible. Hashes differ." >&2
  exit 1
fi

echo "Build is reproducible."
