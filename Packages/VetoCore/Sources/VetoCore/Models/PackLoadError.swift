import Foundation

public enum PackLoadError: Error, Sendable, Equatable {
    case invalidRegex(ruleId: String, pattern: String, underlying: String)
    case duplicateRuleId(ruleId: String, packId: String)
    case emptyRules(packId: String)
}
