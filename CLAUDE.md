# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Veto is an open-source iOS SMS filter that routes political campaign texts to the Junk folder. It runs entirely on-device with no network calls and no tracking.

At the time this file was written the repo contains only `README.md`, `LICENSE`, `.gitignore`, and this file. There is no Xcode project yet. Update this file with build/test commands once the project is scaffolded.

## Non-negotiable constraints

These are product-defining requirements — they affect architecture, not just style. Do not relax them without explicit user approval.

1. **iOS-native only.** Swift + SwiftUI. No cross-platform frameworks, no web views for app UI.
2. **Standard library first.** Prefer `Foundation`/`Swift` stdlib over third-party packages. Every new SPM dependency must be justified; the default answer is "no dependency."
3. **Zero telemetry, zero data collection.** No analytics SDKs, no crash reporters that phone home, no remote config, no A/B frameworks. Do not add `URLSession` calls from the Message Filter Extension (it won't have network entitlement anyway — see below).
4. **On-device classification only.** Patterns and rules ship inside the binary or are user-authored locally. No server-side ML, no remote rule updates.

## Architecture reality: iOS SMS filtering

iOS only allows SMS filtering through `IdentityLookup` / `ILMessageFilter` — a **Message Filter Extension** target. This is the architectural spine of the app and is non-obvious to anyone who hasn't shipped one:

- The extension is a separate target from the main app, with its own bundle ID and entitlement (`com.apple.developer.IdentityLookup.message-filter`).
- Apple invokes the extension only for messages from senders **not** in the user's Contacts.
- The extension's `ILMessageFilterExtension` subclass returns an `ILMessageFilterAction` (`.allow`, `.junk`, `.promotion`, `.transaction`, etc.). On iOS 16+, use `ILMessageFilterActionResponse` with a `subAction` for sub-categorization.
- The extension runs in a **strict sandbox**: no UI, tight memory/CPU budget, and **no network by default**. Network is only permitted via a declared `ILMessageFilterExtensionNetworkURL` in `Info.plist` that points to a server the user configures — Veto must not use this. The extension should be fully synchronous and local.
- The extension cannot share memory with the host app. Configuration (user-defined patterns, enabled rule sets) is passed via an **App Group** shared container (`group.<bundle-id>`). The host SwiftUI app writes config; the extension reads it.
- User must manually enable the filter in Settings → Messages → Unknown & Spam → SMS Filtering. The app should explain this; it cannot enable itself.

### Expected target layout (once scaffolded)

- `Veto/` — SwiftUI host app. Handles pattern management UI, onboarding, enable-instructions, shared-container writes.
- `VetoFilterExtension/` — `ILMessageFilterExtension` subclass. Reads patterns from the App Group, classifies, returns action. Must stay small, allocation-light, and free of `os_log` calls with PII.
- `VetoCore/` (SPM local package) — pure-Swift classification engine shared by both targets. No UIKit/SwiftUI imports. This is the only code that should have unit tests that run without a simulator.

Keep classification logic in `VetoCore` so the extension stays a thin adapter. The extension target is the worst place to debug — push logic into the testable package.

## Privacy implications for code review

When reviewing any diff, flag these as violations:

- Any `import` of a networking library in the extension target.
- Any `URLSession`, `NSURLConnection`, `Network.framework`, or third-party HTTP client in either target.
- Any analytics/crash SDK (Firebase, Sentry, Amplitude, Mixpanel, TelemetryDeck, etc.).
- Any `print`/`os_log`/`Logger` that logs message body content, sender, or user-authored patterns — even in debug builds. Assume logs can leak.
- Any persistence outside the App Group container or `UserDefaults(suiteName:)` tied to the group.

## Test isolation (CRITICAL — read before adding any file I/O)

`swift test` on macOS runs **outside the App Sandbox by default**. The test process inherits the user's full file-read permissions, including their iMessage/SMS history. The safety contract below is the only thing standing between an untested code path and a real message read.

### Forbidden paths — production AND test code

No file at any of these locations may ever be opened, read, written, listed, or referenced (even as a path string) by any code in this repository:

- `~/Library/Messages/` — macOS Messages.app SQLite store (`chat.db`, attachments, drafts)
- `~/Library/SMS/` — legacy SMS store
- `~/Library/Containers/com.apple.MobileSMS/` — Messages app sandbox container
- `~/Library/Group Containers/group.com.apple.MobileSMS/` — Messages group container
- `~/Library/Mobile Documents/com~apple~MobileSMS/` — iCloud-synced messages
- `~/Library/Application Support/AddressBook/` — Contacts (we already exclude Contacts permission entirely; this reinforces it)
- Any path under `~/Library/CoreDuet/`, `~/Library/Suggestions/`, `~/Library/Assistant/` — system-derived data that may contain message excerpts

### Required path discipline for tests that need temporary files

When a test (e.g. `HistoryLog` tests in Increment 4) needs to write to disk, it MUST:

1. Use only `FileManager.default.temporaryDirectory` as the base directory — never anything derived from `NSHomeDirectory()`, `FileManager.default.urls(for: .documentDirectory, ...)`, `FileManager.default.url(for: .applicationSupportDirectory, ...)`, or any `App Group` container.
2. Append a per-test unique component: `.appendingPathComponent("VetoCoreTests-\(UUID().uuidString)")`.
3. Clean up in test teardown — `try? FileManager.default.removeItem(at: testDir)`.
4. Never accept a path from environment variables, command-line arguments, or any external source. All test paths must be constructed in-code from `FileManager.default.temporaryDirectory`.

### Required defenses

- **Pre-commit grep**: any PR introducing the strings `Library/Messages`, `MobileSMS`, `chat.db`, `addressbook`, `NSHomeDirectory`, or `urls(for: .documentDirectory` must be rejected unless explicitly justified for a host-app feature that operates only on the App Group container at runtime (never tests). When in doubt, refuse.
- **Test fakes are synthetic**: every `InboundMessage` in tests must be constructed from string literals defined in the test file. No fixture loading from disk. No reading message corpora from `~/`. Corpus files (when added in Increment 6) live under `tests/corpus/` inside the repo and contain only **anonymized templates** (e.g. `"Trump 2028: chip in $AMOUNT"`) — never real message captures.
- **CI verification**: the GitHub Actions release workflow (Increment 11) will grep for the forbidden patterns above and fail the build if any appear in production or test source.

This is non-negotiable. If a future feature legitimately requires reading from one of the forbidden paths, halt and ask the maintainer first.

## Commit style

Per global instructions: imperative mood, ≤72-char subject, one logical change per commit. Don't push to `main` — feature branches + PRs.
