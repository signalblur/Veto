#!/usr/bin/env bash
#
# embed-source-sha.sh
#
# Writes the current git commit SHA and repo URL into the host app's
# generated Info.plist as VetoSourceSHA / VetoSourceRepoURL. Invoked
# as a pre-build script by the Veto target. Uses /usr/libexec/PlistBuddy
# which ships with macOS — no extra dependency.
#
# This is what makes the device-side About screen able to display
# "Source: a1b2c3d4" tied to a specific public commit.

set -euo pipefail

if [[ -z "${SRCROOT:-}" ]]; then
  echo "embed-source-sha.sh: SRCROOT not set; this script is intended to run as an Xcode build phase" >&2
  exit 1
fi

cd "$SRCROOT"

SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")

# Normalize git@github.com:owner/repo.git → https://github.com/owner/repo
case "$REPO_URL" in
  git@github.com:*)
    REPO_URL="https://github.com/${REPO_URL#git@github.com:}"
    REPO_URL="${REPO_URL%.git}"
    ;;
  https://github.com/*)
    REPO_URL="${REPO_URL%.git}"
    ;;
esac

INFO_PLIST="${TARGET_BUILD_DIR:-$BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "embed-source-sha.sh: Info.plist not found at $INFO_PLIST" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :VetoSourceSHA $SHA" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :VetoSourceSHA string $SHA" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Set :VetoSourceRepoURL $REPO_URL" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :VetoSourceRepoURL string $REPO_URL" "$INFO_PLIST"

# Stamp file for Xcode dependency tracking.
mkdir -p "$DERIVED_FILE_DIR"
echo "$SHA" > "$DERIVED_FILE_DIR/.veto-source-sha-stamp"
