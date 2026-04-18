#!/usr/bin/env bash
#
# build-release.sh
#
# Deterministic Release archive of the Veto iOS app. Intended to be byte-
# identical when run twice from the same git commit on the same Xcode
# version. Outputs to build/Veto.xcarchive.
#
# Requires:
#   - Xcode 16+ (full app, not Command Line Tools)
#   - XcodeGen: brew install xcodegen
#
# This script does NOT sign the archive. Signing is Apple's job in the App
# Store distribution flow; the unsigned .xcarchive is what we publish on
# GitHub Releases for byte-level verification.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! xcode-select --print-path 2>/dev/null | grep -q "Xcode.app"; then
  echo "Requires the full Xcode app. Run scripts/setup-xcode-project.sh for instructions." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Requires xcodegen: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate --spec project.yml --quiet

SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export SOURCE_DATE_EPOCH

mkdir -p build
if [[ -d build/Veto.xcarchive ]]; then
  trash build/Veto.xcarchive 2>/dev/null || rm -rf build/Veto.xcarchive
fi

xcodebuild \
  -project Veto.xcodeproj \
  -scheme Veto \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Veto.xcarchive \
  -quiet \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  ONLY_ACTIVE_ARCH=NO \
  OTHER_SWIFT_FLAGS='-Xfrontend -no-clang-module-breadcrumbs'

APP_PATH="build/Veto.xcarchive/Products/Applications/Veto.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but Veto.app not found at expected path: $APP_PATH" >&2
  exit 1
fi

echo "Archive ready: build/Veto.xcarchive"
echo "Bundle hash:   $(scripts/bundle-hash.sh "$APP_PATH")"
