import Foundation
import IdentityLookup
import VetoCore

#if canImport(FoundationModels)
import FoundationModels
#endif

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
            let allPacks = try await store.loadPacks()
            let enabledPacks = allPacks.filter { settings.enabledPacks.contains($0.id) }
            let allowedSenders = try await store.loadAllowedSenders()

            var detectors: [any Detector] = [
                AllowedSenderDetector(trustedSenders: allowedSenders),
                try SignatureDetector(packs: enabledPacks),
            ]
            if settings.smartDetection.coreMLEnabled {
                detectors.append(CoreMLDetector(provider: makeCoreMLProvider()))
            }
            if settings.smartDetection.foundationModelsEnabled, foundationModelsAvailable() {
                detectors.append(FoundationModelsDetector(provider: makeFoundationModelsProvider()))
            }

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

    // v1 ships without a bundled CoreML model. The provider returns nil so the detector
    // emits .pass. v1.1 will replace this with VetoClassifier.mlmodelc + NLModel inference.
    private func makeCoreMLProvider() -> CoreMLDetector.ConfidenceProvider {
        { _ in nil }
    }

    private func makeFoundationModelsProvider() -> FoundationModelsDetector.DonationAskProvider {
#if canImport(FoundationModels)
        if #available(iOS 18.1, *) {
            return { body in
                await Self.classifyWithFoundationModels(body: body)
            }
        }
#endif
        return { _ in nil }
    }

    private func foundationModelsAvailable() -> Bool {
#if canImport(FoundationModels)
        if #available(iOS 18.1, *) {
            return SystemLanguageModel.default.availability == .available
        }
#endif
        return false
    }

#if canImport(FoundationModels)
    @available(iOS 18.1, *)
    private static func classifyWithFoundationModels(body: String) async -> Bool? {
        do {
            let session = LanguageModelSession(instructions: """
                You are a binary classifier. Given an SMS message body, decide whether it is an unsolicited \
                political fundraising or campaign-donation request from a candidate, PAC, or political advocacy \
                organization. Respond with exactly one word: yes or no. Do not explain.
                """)
            let response = try await withTaskTimeout(milliseconds: 800) {
                try await session.respond(to: body)
            }
            let trimmed = response.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("yes")
        } catch {
            return nil
        }
    }

    private static func withTaskTimeout<T: Sendable>(
        milliseconds: UInt64,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
                throw CancellationError()
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }
#endif
}

private struct LoadedState: Sendable {
    let engine: Engine
    let settings: Settings
    let historyLog: HistoryLog
}
