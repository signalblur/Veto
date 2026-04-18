#!/usr/bin/env bash
#
# setup-xcode-project.sh
#
# One-shot scaffold for Veto.xcodeproj. Reads project.yml at the repo root
# and asks XcodeGen to generate the .xcodeproj. Run after a fresh clone, or
# any time project.yml changes.
#
# Requires:
#   - Xcode 16 or later (full app, not just Command Line Tools)
#   - XcodeGen: brew install xcodegen
#
# This script does NOT install Xcode — that has to come from the App Store.
# It does check for XcodeGen and offer to install it via Homebrew.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! xcode-select --print-path 2>/dev/null | grep -q "Xcode.app"; then
  cat <<EOF >&2
Veto requires the full Xcode app, not just Command Line Tools.

Current developer directory: $(xcode-select --print-path 2>/dev/null || echo unset)

To fix:
  1. Install Xcode from the App Store (>15 GB).
  2. Launch it once and accept the license.
  3. Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

Then re-run this script.
EOF
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "XcodeGen not found. Install it now via Homebrew? [y/N]"
    read -r reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      brew install xcodegen
    else
      echo "Cannot proceed without XcodeGen. Install with: brew install xcodegen" >&2
      exit 1
    fi
  else
    cat <<EOF >&2
XcodeGen not found and Homebrew is not installed.

Install Homebrew: https://brew.sh
Then: brew install xcodegen
EOF
    exit 1
  fi
fi

xcodegen generate --spec project.yml

cat <<EOF
Veto.xcodeproj generated. Open with:
  open Veto.xcodeproj

To run unit tests for VetoCore (no simulator needed):
  cd Packages/VetoCore && swift test

To build the iOS app for a connected device or simulator:
  xcodebuild -project Veto.xcodeproj -scheme Veto -destination 'generic/platform=iOS' build
EOF
