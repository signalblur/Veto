import Foundation

public enum DetectionResult: Sendable, Equatable {
    case match(ruleId: String, confidence: Double)
    case pass
    case explicitAllow(reason: AllowReason)
}
