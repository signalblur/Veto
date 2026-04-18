import Foundation

public enum Decision: Sendable, Equatable {
    case none
    case allow(reason: AllowReason)
    case junk(ruleId: String, confidence: Double)
}
