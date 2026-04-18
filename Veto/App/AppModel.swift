import Foundation
import Observation
import VetoCore

@MainActor
@Observable
final class AppModel {
    static let appGroupIdentifier = "group.com.magoniaresearch.veto"

    let containerURL: URL?
    private let store: AppGroupStore?
    private let historyLog: HistoryLog?

    var settings: Settings = Settings(masterEnabled: true, threshold: 0.5)
    var allowedSenders: Set<String> = []
    var historyEntries: [HistoryEntry] = []
    var packs: [Pack] = []
    var hasCompletedOnboarding: Bool = false

    var bundleHash: String?
    var modelHash: String?

    init(containerURL: URL?) {
        self.containerURL = containerURL
        if let url = containerURL {
            self.store = AppGroupStore(containerURL: url)
            self.historyLog = HistoryLog(url: url.appendingPathComponent("history.jsonl"))
        } else {
            self.store = nil
            self.historyLog = nil
        }
    }

    static func live() -> AppModel {
        let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
        return AppModel(containerURL: url)
    }

    func bootstrap() async {
        await loadFromStore()
        await installBundledPacksIfNeeded()
        loadOnboardingState()
        await computeAttestationHashes()
    }

    func loadFromStore() async {
        guard let store else { return }
        if let s = try? await store.loadSettings() { settings = s }
        if let a = try? await store.loadAllowedSenders() { allowedSenders = a }
        if let p = try? await store.loadPacks() { packs = p }
        await reloadHistory()
    }

    func reloadHistory() async {
        guard let historyLog else { return }
        if let entries = try? await historyLog.entries() {
            historyEntries = entries.reversed()
        }
    }

    func installBundledPacksIfNeeded() async {
        guard let store, packs.isEmpty else { return }
        try? await store.installPacks(from: BundledPacks.allURLs())
        if let p = try? await store.loadPacks() { packs = p }
    }

    func setMasterEnabled(_ enabled: Bool) async {
        settings.masterEnabled = enabled
        try? await store?.saveSettings(settings)
    }

    func setPackEnabled(id: String, enabled: Bool) async {
        if enabled {
            settings.enabledPacks.insert(id)
        } else {
            settings.enabledPacks.remove(id)
        }
        try? await store?.saveSettings(settings)
    }

    func setCoreMLEnabled(_ enabled: Bool) async {
        settings.smartDetection.coreMLEnabled = enabled
        try? await store?.saveSettings(settings)
    }

    func setFoundationModelsEnabled(_ enabled: Bool) async {
        settings.smartDetection.foundationModelsEnabled = enabled
        try? await store?.saveSettings(settings)
    }

    func addTrustedSender(_ sender: String) async {
        let trimmed = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? await store?.addAllowedSender(trimmed)
        allowedSenders.insert(trimmed)
    }

    func removeTrustedSenders(_ senders: [String]) async {
        for sender in senders {
            try? await store?.removeAllowedSender(sender)
            allowedSenders.remove(sender)
        }
    }

    func markEntryUndone(_ entry: HistoryEntry) async {
        try? await historyLog?.markUndone(bodyHash: entry.bodyHash, sender: entry.sender)
        if let index = historyEntries.firstIndex(of: entry) {
            historyEntries[index].undone = true
        }
    }

    func junkedCountInLast(days: Int) -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return historyEntries.filter { $0.timestamp >= cutoff && entryIsJunk($0) }.count
    }

    func junkedCount(forPack packId: String, last days: Int) -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        return historyEntries.filter { entry in
            guard entry.timestamp >= cutoff, !entry.undone else { return false }
            if case .junk(let ruleId) = entry.action {
                return ruleId.hasPrefix("\(packId).")
            }
            return false
        }.count
    }

    func markOnboardingComplete() {
        UserDefaults(suiteName: AppModel.appGroupIdentifier)?.set(true, forKey: "veto.onboarding.completed")
        hasCompletedOnboarding = true
    }

    private func loadOnboardingState() {
        let defaults = UserDefaults(suiteName: AppModel.appGroupIdentifier)
        hasCompletedOnboarding = defaults?.bool(forKey: "veto.onboarding.completed") ?? false
    }

    private func computeAttestationHashes() async {
        let packURLs = BundledPacks.allURLs()
        let modelURL = Bundle.main.url(forResource: "VetoClassifier", withExtension: "mlmodelc")
        if let hash = try? BundleHasher.canonicalHash(packURLs: packURLs, modelDirectoryURL: modelURL) {
            bundleHash = hash
        }
        if let modelURL, let hash = try? BundleHasher.canonicalHash(modelDirectoryURL: modelURL) {
            modelHash = hash
        }
    }

    private func entryIsJunk(_ entry: HistoryEntry) -> Bool {
        if case .junk = entry.action, !entry.undone { return true }
        return false
    }
}
