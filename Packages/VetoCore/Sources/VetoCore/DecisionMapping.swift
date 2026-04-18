import Foundation
import CryptoKit

public enum DecisionMapping {
    public static func bodyHash(_ body: String) -> String {
        let digest = SHA256.hash(data: Data(body.utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func makeHistoryEntry(
        decision: Decision,
        sender: String,
        bodyHash: String,
        now: Date = Date()
    ) -> HistoryEntry {
        HistoryEntry(
            timestamp: now,
            sender: sender,
            action: historyAction(for: decision),
            bodyHash: bodyHash,
            undone: false
        )
    }

    private static func historyAction(for decision: Decision) -> HistoryAction {
        switch decision {
        case .none:
            return .none
        case .allow(let reason):
            return .allow(reason: allowReasonString(reason))
        case .junk(let ruleId, _):
            return .junk(ruleId: ruleId)
        }
    }

    private static func allowReasonString(_ reason: AllowReason) -> String {
        switch reason {
        case .trustedSender:
            return "trustedSender"
        }
    }
}
