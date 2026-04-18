import SwiftUI
import VetoCore

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(model.packs, id: \.id) { pack in
                        PackToggleRow(pack: pack)
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Each category is an independent rule pack. Disabling one stops Veto from junking messages that only that pack would catch.")
                }

                Section {
                    Toggle("On-device classifier", isOn: Binding(
                        get: { model.settings.smartDetection.coreMLEnabled },
                        set: { v in Task { await model.setCoreMLEnabled(v) } }
                    ))
                    if foundationModelsAvailable {
                        Toggle("Apple Intelligence", isOn: Binding(
                            get: { model.settings.smartDetection.foundationModelsEnabled },
                            set: { v in Task { await model.setFoundationModelsEnabled(v) } }
                        ))
                    }
                } header: {
                    Text("Smart detection")
                } footer: {
                    Text("Both run on-device. Nothing is downloaded or transmitted. The on-device classifier ships in the app binary; Apple Intelligence (when available) is part of iOS itself.")
                }

                Section {
                    NavigationLink("Trusted senders (\(model.allowedSenders.count))") {
                        TrustedSendersView()
                    }
                } header: {
                    Text("Overrides")
                }

                Section {
                    NavigationLink("About Veto") {
                        AboutView()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var foundationModelsAvailable: Bool {
#if canImport(FoundationModels)
        if #available(iOS 18.1, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
#else
        return false
#endif
    }
}

private struct PackToggleRow: View {
    @Environment(AppModel.self) private var model
    let pack: Pack

    var body: some View {
        Toggle(pack.displayName, isOn: Binding(
            get: { model.settings.enabledPacks.contains(pack.id) },
            set: { v in Task { await model.setPackEnabled(id: pack.id, enabled: v) } }
        ))
    }
}
