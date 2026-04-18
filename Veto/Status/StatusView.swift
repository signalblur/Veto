import SwiftUI
import VetoCore

struct StatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle("Filter political donations", isOn: Binding(
                        get: { model.settings.masterEnabled },
                        set: { newValue in
                            Task { await model.setMasterEnabled(newValue) }
                        }
                    ))
                    .font(.headline)
                }

                Section {
                    if model.settings.masterEnabled {
                        statusRow(
                            symbol: "checkmark.shield.fill",
                            color: .green,
                            title: "Filtering active",
                            subtitle: "Veto runs automatically when iOS receives a message from a sender not in your Contacts."
                        )
                    } else {
                        statusRow(
                            symbol: "exclamationmark.shield.fill",
                            color: .orange,
                            title: "Paused",
                            subtitle: "Veto is installed but not filtering. Re-enable above, or disable system-wide in iOS Settings."
                        )
                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            Label("Open iOS Settings", systemImage: "arrow.up.forward.app")
                        }
                    }
                } header: {
                    Text("Status")
                }

                Section {
                    LabeledContent("Last 7 days") {
                        Text("\(model.junkedCountInLast(days: 7))")
                            .monospacedDigit()
                    }
                    ForEach(model.packs, id: \.id) { pack in
                        LabeledContent(pack.displayName) {
                            Text("\(model.junkedCount(forPack: pack.id, last: 7))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Activity")
                }
            }
            .navigationTitle("Veto")
            .refreshable { await model.reloadHistory() }
        }
    }

    @ViewBuilder
    private func statusRow(symbol: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
