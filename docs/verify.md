# Verifying a Veto build

The Veto iOS app's About screen shows three values:

```
Source:    a1b2c3d4
Bundle:    sha256:7f3e9c2a...
ML model:  sha256:9c2a8b1d...
```

This page explains how to verify those values come from a specific public commit on this repository.

## What attestation actually proves

Apple re-signs every binary distributed through the App Store, so the `.ipa` byte content on your device cannot equal the `.ipa` content on GitHub. A device-side hash of the executable would change every time Apple rotates a signature.

Veto sidesteps this by hashing only the **resources** that drive its behavior:

- The four signature pack JSONs (`donations.json`, `gotv.json`, `surveys.json`, `advocacy.json`)
- Every file inside `VetoClassifier.mlmodelc/` (when bundled — v1 ships without the model)

These are the inputs to the classification engine. They are not touched by Apple's re-signing. If the bundled hash on your device equals the hash a third party computes from the public source tree, **the patterns running on your device come from that source tree** — even though the binary differs.

This is honest about its limits: it doesn't prove the executable's machine code matches. It proves the resources do.

## Quick verify (one command)

If you have Xcode 16+ and Homebrew installed:

```bash
git clone https://github.com/<owner>/<repo>.git
cd veto
scripts/verify-build.sh <git-sha-from-About> <hash-from-About>
```

The script clones, checks out the commit, builds deterministically, computes the resource hash, and compares.

Exit code 0 = match. Exit code 1 = mismatch.

## Manual verify (step by step)

1. **Look up the values on the device:** open Veto → Settings → About. Copy the `Source` (8-char SHA) and the `Bundle` hash.

2. **Clone the repo at the matching commit:**
   ```bash
   git clone https://github.com/<owner>/<repo>.git veto-verify
   cd veto-verify
   git checkout <Source-SHA>
   ```

3. **Install prerequisites** (one-time):
   - Xcode 16 or later (full app, from App Store)
   - `brew install xcodegen`

4. **Build deterministically:**
   ```bash
   scripts/build-release.sh
   ```
   The script sets `SOURCE_DATE_EPOCH` to the commit's timestamp and uses `CODE_SIGNING_ALLOWED=NO` so Apple's signing pipeline doesn't introduce variance.

5. **Compute the resource hash:**
   ```bash
   scripts/bundle-hash.sh build/Veto.xcarchive/Products/Applications/Veto.app
   ```

6. **Compare** to the `Bundle` value from the About screen. They must be byte-identical.

## What "reproducible" relies on

For the hashes to match, the build environment must match what produced the public release:

- **Xcode version**: pinned in `.github/workflows/release.yml` (currently 16.0). If you build on a different Xcode, the Swift compiler will emit slightly different binary code — the BUNDLE hash won't change, because we hash only resources, but the executable will differ.
- **Bundled signature packs**: identical because they are checked-in JSON files. Any modification before commit changes the hash.
- **`.mlmodelc` (when present)**: deterministic compilation by `coremlc`.

The bash hashing logic in `scripts/bundle-hash.sh` mirrors the Swift logic in `Packages/VetoCore/Sources/VetoCore/Hashing/BundleHasher.swift` exactly: each resource is included as `filename + 0x0A + bytes + 0x0A`, packs are sorted lexicographically by filename, model files are sorted by relative path. Both produce the same `sha256:` value for the same inputs.

## Reporting a mismatch

If your verification produces a different hash than your device displays:

1. **Re-check the SHA**: the device shows the first 8 chars; make sure you checked out the full SHA the device claims.
2. **Re-check Xcode**: `xcodebuild -version` must match the version in `.github/workflows/release.yml`.
3. **Re-check the source tree**: `git status` should be clean inside your `veto-verify` clone.

If all three are right and the hashes still differ, file a public issue. A persistent mismatch may mean a release was published from a different commit than its tag claims.
