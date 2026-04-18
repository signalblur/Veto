import Foundation

public struct HistoryEntry: Sendable, Equatable {
    public let timestamp: Date
    public let sender: String
    public let action: HistoryAction
    public let bodyHash: String
    public var undone: Bool

    public init(timestamp: Date, sender: String, action: HistoryAction, bodyHash: String, undone: Bool) {
        self.timestamp = timestamp
        self.sender = sender
        self.action = action
        self.bodyHash = bodyHash
        self.undone = undone
    }
}

public enum HistoryAction: Sendable, Equatable {
    case none
    case allow(reason: String)
    case junk(ruleId: String)
}

extension HistoryEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case timestamp = "ts"
        case sender
        case action
        case ruleId
        case allowReason
        case bodyHash
        case undone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ts = try container.decode(Int.self, forKey: .timestamp)
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(ts))
        self.sender = try container.decode(String.self, forKey: .sender)
        self.bodyHash = try container.decode(String.self, forKey: .bodyHash)
        self.undone = try container.decodeIfPresent(Bool.self, forKey: .undone) ?? false

        let actionStr = try container.decode(String.self, forKey: .action)
        switch actionStr {
        case "none":
            self.action = .none
        case "junk":
            let ruleId = try container.decode(String.self, forKey: .ruleId)
            self.action = .junk(ruleId: ruleId)
        case "allow":
            let reason = try container.decode(String.self, forKey: .allowReason)
            self.action = .allow(reason: reason)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .action,
                in: container,
                debugDescription: "unknown action discriminator: \(actionStr)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Int(timestamp.timeIntervalSince1970), forKey: .timestamp)
        try container.encode(sender, forKey: .sender)
        try container.encode(bodyHash, forKey: .bodyHash)
        try container.encode(undone, forKey: .undone)
        switch action {
        case .none:
            try container.encode("none", forKey: .action)
        case .junk(let ruleId):
            try container.encode("junk", forKey: .action)
            try container.encode(ruleId, forKey: .ruleId)
        case .allow(let reason):
            try container.encode("allow", forKey: .action)
            try container.encode(reason, forKey: .allowReason)
        }
    }
}
