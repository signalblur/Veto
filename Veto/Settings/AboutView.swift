import SwiftUI
import VetoCore

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: appBuild)
                if let sha = sourceSHA {
                    LabeledContent("Source") {
                        if let url = sourceCommitURL {
                            Link(String(sha.prefix(8)), destination: url)
                                .font(.body.monospaced())
                        } else {
                            Text(sha.prefix(8))
                                .font(.body.monospaced())
                        }
                    }
                }
            }

            if model.bundleHash != nil || model.modelHash != nil {
                Section {
                    if let hash = model.bundleHash {
                        AttestationRow(label: "Bundle", hash: hash)
                    }
                    if let hash = model.modelHash {
                        AttestationRow(label: "ML model", hash: hash)
                    }
                } header: {
                    Text("Runtime attestation")
                } footer: {
                    Text("These hashes are computed at runtime over the bundled signature packs, ML model files, and Info.plist (with signing fields stripped). They identify the resources running on this device independent of Apple's App Store re-signing.")
                }
            }

            if let url = verifyDocsURL {
                Section {
                    Link(destination: url) {
                        Label("How to verify this build", systemImage: "checkmark.shield")
                    }
                }
            }

            Section {
                Text("Veto is open source under the MIT license. It runs entirely on your device. Nothing is collected, sent, or analyzed remotely.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    private var sourceSHA: String? {
        Bundle.main.infoDictionary?["VetoSourceSHA"] as? String
    }

    private var sourceRepoURL: String? {
        Bundle.main.infoDictionary?["VetoSourceRepoURL"] as? String
    }

    private var sourceCommitURL: URL? {
        guard let repo = sourceRepoURL, let sha = sourceSHA else { return nil }
        return URL(string: "\(repo)/commit/\(sha)")
    }

    private var verifyDocsURL: URL? {
        guard let repo = sourceRepoURL else { return nil }
        return URL(string: "\(repo)/blob/main/docs/verify.md")
    }
}

private struct AttestationRow: View {
    let label: String
    let hash: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline)
            Text(hash)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }
}
