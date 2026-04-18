# VetoCore

Local SwiftPM package providing the on-device classification engine for Veto, an iOS SMS filter that routes political fundraising texts to the Junk folder.

## In v1.0 of this package

- `InboundMessage`, `Decision`, `AllowReason`, `Settings` value types (all `Sendable`).
- `Detector` protocol and `DetectionResult` enum.
- `Engine` — ordered detector chain with master kill-switch and confidence threshold.
- `AllowedSenderDetector` — exact-string match against an immutable trusted-sender set; emits `.explicitAllow(.trustedSender)` to short-circuit the chain.
- `Pack` / `Rule` / `MatchExpression` Codable models with strict JSON decoding (a single `MatchExpression` object must contain exactly one of `regex` / `any` / `all`).
- `SignatureDetector` — sums weights of matching rules per pack; emits `.match(ruleId, confidence: 1.0)` when a pack's score crosses its `threshold`. The highest-weight matching rule provides the reported `ruleId`. Compiles regexes once at construction; `PackLoadError` reports invalid regex / duplicate rule id / empty pack with rule-id context.

The engine is pure Swift built on Foundation alone. It compiles for iOS 17+ and macOS 14+ and runs in the host app, the Message Filter Extension, and the test target without modification.

## Pending in later increments

- `HistoryLog` append/compaction (Increment 4)
- `AppGroupStore` + `BundleHasher` (Increment 5)
- `CoreMLDetector`, `FoundationModelsDetector` (Increment 10)

## Hard contract

This package and every target that imports it must hold these invariants:

- **No network.** No `URLSession`, no `Network.framework`, no third-party HTTP client.
- **No logging.** No `print`, `os_log`, `Logger`, or `NSLog` — message body, sender, and user-authored patterns must never reach a log call site, even in `#if DEBUG`.
- **No third-party dependencies.** Foundation only. (`swift-testing` is a test-only declared dependency required by the toolchain.)
- **Sendable everywhere.** Swift 6 strict concurrency; every public type explicitly conforms.
- **Test isolation.** Tests construct synthetic `InboundMessage` instances from string literals inside the test file. No test reads from `~/Library/Messages/`, `~/Library/SMS/`, `~/Library/Containers/com.apple.MobileSMS/`, or any path that could intersect real user message data. When file I/O is needed (e.g. `HistoryLog` in Increment 4), the only acceptable base directory is `FileManager.default.temporaryDirectory`. See the project root `CLAUDE.md` "Test isolation" section for the full forbidden-path list and discipline.

## Tests

Swift Testing (`@Test`, `#expect`). Runs on host without a simulator:

```
cd Packages/VetoCore && swift test
```
