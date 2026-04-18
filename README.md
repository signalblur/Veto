# Veto

Open-source iOS SMS filter that routes political fundraising texts to your Junk folder. On-device, no network, no telemetry, no tracking — and the resources running on your device can be cryptographically tied back to the public source tree.

## What it does

Veto runs as an iOS Message Filter Extension. When you receive an SMS from a sender not in your Contacts, iOS hands the message to Veto's classifier, which decides whether to route it to your Junk folder. Everything happens on your device. The filter has no network entitlement and physically cannot make outbound requests.

Four toggleable categories ship in v1.0:

- **Donations** — campaign fundraising asks (ActBlue, WinRed, PACs, candidates)
- **Get Out The Vote** — turnout reminders, polling-place messages
- **Surveys** — political survey blasts
- **Advocacy** — named advocacy orgs (ACLU, Sierra Club, Heritage, etc.) asking for money

Donations is on by default. The other three are opt-in.

## Privacy guarantees (enforced by code, not policy)

- **No network in the filter extension.** No `URLSession`, no `Network.framework` import. CI greps the source on every PR to enforce this.
- **No telemetry.** No analytics SDKs, no crash reporters, no remote config. Ever.
- **Contacts are never touched.** Veto does not request `Contacts` permission and never can. iOS already excludes contacts at the OS level — Apple does not invoke the filter for senders in your address book — and `NSContactsUsageDescription` is grep-checked out of the source.
- **No log of message content.** The local history stores only `(timestamp, sender, action, ruleId, body-hash, undone)`. The body is never logged; not in `print`, not in `os_log`, not in `Logger`.
- **Resources verifiable against the source tree.** The About screen displays the SHA-256 of the bundled signature packs and ML model. See [docs/verify.md](docs/verify.md) for the verification workflow.

## Architecture

```
Veto/                          SwiftUI host app — onboarding, settings, history, About
VetoFilterExtension/           ILMessageFilterExtension subclass — thin adapter
Packages/VetoCore/             Pure-Swift classification engine, fully unit-tested
  Sources/VetoCore/Packs/      Bundled signature pack JSONs
scripts/                       build-release.sh, bundle-hash.sh, verify-build.sh, ...
.github/workflows/             CI (privacy greps + VetoCore tests) + Release pipeline
```

`VetoCore` is the testable spine; the iOS targets are thin adapters that delegate everything to it. See [`Packages/VetoCore/README.md`](Packages/VetoCore/README.md) for the engine internals.

## Build from source

```bash
git clone https://github.com/<owner>/<repo>.git
cd veto

# Run the pure-Swift tests immediately (no Xcode needed)
cd Packages/VetoCore && swift test

# To build the iOS app, you need Xcode 16+ from the App Store, then:
brew install xcodegen
scripts/setup-xcode-project.sh
open Veto.xcodeproj
```

## Verifying a release

If you want to check that the install on your device corresponds to a specific public commit, see [docs/verify.md](docs/verify.md). Short version:

```bash
scripts/verify-build.sh <SHA-from-About-screen> <hash-from-About-screen>
```

The script clones, builds deterministically with the committed `xcodebuild` invocation, and compares hashes. Exit 0 = match.

## License

MIT. See [LICENSE](LICENSE).
