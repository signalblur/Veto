#!/usr/bin/env bash
#
# verify-build.sh
#
# End-to-end verifier. Given an expected hash from a device's About screen,
# clones the published source at the matching commit, builds it
# deterministically, computes the resource hash, and compares.
#
# Usage:
#   scripts/verify-build.sh <git-sha> <expected-hash>
# Example:
#   scripts/verify-build.sh a1b2c3d4 sha256:7f3e9c2a...
#
# Exits 0 on match, 1 on mismatch, >1 on error.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  cat <<EOF >&2
Usage: $0 <git-sha> <expected-hash>

Look up <git-sha> on the device's About screen ("Source: a1b2c3d4").
Look up <expected-hash> on the same screen ("Bundle: sha256:7f3e...").

Both must come from the same install. The script does not need network
access beyond the initial clone.
EOF
  exit 2
fi

GIT_SHA="$1"
EXPECTED="$2"

if [[ ! "$GIT_SHA" =~ ^[0-9a-f]{7,40}$ ]]; then
  echo "Error: <git-sha> must be a 7-40 character lowercase hex Git commit SHA (got: $GIT_SHA)." >&2
  echo "Branch names, tags, and other refs are not accepted: build attestation requires an immutable commit." >&2
  exit 2
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [[ -z "$REPO_URL" ]]; then
  REPO_URL=$(grep -m1 'VetoSourceRepoURL' "$WORKDIR" 2>/dev/null || echo "")
fi
if [[ -z "$REPO_URL" ]]; then
  echo "Cannot determine repo URL. Run from inside the Veto repo or pass the URL via VETO_REPO_URL env var." >&2
  exit 2
fi

echo "Cloning $REPO_URL @ $GIT_SHA into $WORKDIR..."
git clone --quiet "$REPO_URL" "$WORKDIR/veto"
cd "$WORKDIR/veto"
git checkout --quiet "$GIT_SHA"

echo "Building deterministic release..."
./scripts/build-release.sh

ACTUAL=$(./scripts/bundle-hash.sh "build/Veto.xcarchive/Products/Applications/Veto.app")

echo
echo "Expected: $EXPECTED"
echo "Actual:   $ACTUAL"

if [[ "$EXPECTED" == "$ACTUAL" ]]; then
  echo
  echo "MATCH: the device is running the source tree at $GIT_SHA."
  exit 0
fi

echo
echo "MISMATCH. The device is NOT running an unmodified copy of source $GIT_SHA, OR the build environment differs (Xcode version, SDK, etc.)." >&2
exit 1
