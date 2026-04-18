import SwiftUI
import VetoCore

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = .welcome

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content

                Divider()

                HStack {
                    if step != .welcome {
                        Button("Back") { step = step.previous() }
                    }
                    Spacer()
                    Button(primaryLabel) {
                        if let next = step.next() {
                            step = next
                        } else {
                            model.markOnboardingComplete()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: WelcomeStep()
        case .categories: CategoriesStep()
        case .enable: EnableInSettingsStep()
        }
    }

    private var primaryLabel: String {
        step.next() == nil ? "Done" : "Continue"
    }
}

private enum Step: CaseIterable {
    case welcome, categories, enable

    func next() -> Step? {
        switch self {
        case .welcome: return .categories
        case .categories: return .enable
        case .enable: return nil
        }
    }

    func previous() -> Step {
        switch self {
        case .welcome: return .welcome
        case .categories: return .welcome
        case .enable: return .categories
        }
    }
}

private struct WelcomeStep: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Welcome to Veto")
                    .font(.largeTitle.bold())
                Text("Veto routes political fundraising texts to your Junk folder. Everything happens on your device.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    bullet("Zero network — Veto's filter has no internet permission and never can.")
                    bullet("Zero telemetry — nothing is collected, ever.")
                    bullet("Contacts are never seen — iOS only invokes Veto for senders you don't already know.")
                    bullet("Open source — every byte is reproducible from the GitHub source tree.")
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
            Text(text)
        }
    }
}

private struct CategoriesStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Text("Choose categories")
                    .font(.title2.bold())
                Text("Each category is independent. Donations is on by default; turn the rest on as you need them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section {
                ForEach(model.packs, id: \.id) { pack in
                    Toggle(isOn: Binding(
                        get: { model.settings.enabledPacks.contains(pack.id) },
                        set: { v in Task { await model.setPackEnabled(id: pack.id, enabled: v) } }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.displayName).font(.body)
                            Text(packDescription(pack.id))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func packDescription(_ id: String) -> String {
        switch id {
        case "donations": return "Campaign fundraising asks (ActBlue, WinRed, PACs, candidates)."
        case "gotv": return "Get-out-the-vote reminders. Use cautiously — civic reminders can look similar."
        case "surveys": return "Political survey blasts (\"quick poll about the election…\")."
        case "advocacy": return "Named advocacy orgs (ACLU, Sierra Club, Heritage, etc.) asking for money."
        default: return ""
        }
    }
}

private struct EnableInSettingsStep: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Enable in iOS Settings")
                    .font(.largeTitle.bold())
                Text("Apple requires you to manually flip one switch. Veto cannot enable itself.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    step(1, "Open the iOS Settings app")
                    step(2, "Messages → Unknown & Spam")
                    step(3, "SMS Filtering → tap Veto")
                    step(4, "Return here")
                }
                .padding(.top, 8)

                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Open Settings now", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 16)
            }
            .padding()
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n).")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(text).font(.body)
        }
    }
}
