import Foundation
import IdentityLookup
import VetoCore

actor ExtensionRuntime {
    static let shared = ExtensionRuntime()

    private static let appGroupIdentifier = "group.com.liesabove.veto"

    private let containerURL: URL?
    private var loaded: LoadedState?

    private init() {
        self.containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ExtensionRuntime.appGroupIdentifier
        )
    }

    func classify(sender: String, body: String) async -> ILMessageFilterAction {
        guard let containerURL else { return .none }
        let state = await ensureLoaded(containerURL: containerURL)
        guard let state else { return .none }

        let msg = InboundMessage(sender: sender, body: body)
        let decision = await state.engine.classify(msg, settings: state.settings)

        let entry = DecisionMapping.makeHistoryEntry(
            decision: decision,
            sender: sender,
            bodyHash: DecisionMapping.bodyHash(body)
        )
        try? await state.historyLog.append(entry)

        return ilAction(for: decision)
    }

    private func ensureLoaded(containerURL: URL) async -> LoadedState? {
        if let loaded { return loaded }
        let store = AppGroupStore(containerURL: containerURL)
        do {
            let settings = try await store.loadSettings()
            let packs = try await store.loadPacks()
            let allowedSenders = try await store.loadAllowedSenders()

            let detectors: [any Detector] = [
                AllowedSenderDetector(trustedSenders: allowedSenders),
                try SignatureDetector(packs: packs),
            ]
            let engine = Engine(detectors: detectors)
            let log = HistoryLog(url: containerURL.appendingPathComponent("history.jsonl"))

            let state = LoadedState(engine: engine, settings: settings, historyLog: log)
            self.loaded = state
            return state
        } catch {
            return nil
        }
    }

    private func ilAction(for decision: Decision) -> ILMessageFilterAction {
        switch decision {
        case .none: return .none
        case .allow: return .allow
        case .junk: return .junk
        }
    }
}

private struct LoadedState: Sendable {
    let engine: Engine
    let settings: Settings
    let historyLog: HistoryLog
}
