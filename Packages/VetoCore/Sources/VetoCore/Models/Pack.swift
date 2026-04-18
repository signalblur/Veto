import Foundation

public struct Pack: Sendable, Codable, Equatable {
    public let id: String
    public let version: String
    public let displayName: String
    public let threshold: Int
    public let rules: [Rule]

    public init(id: String, version: String, displayName: String, threshold: Int, rules: [Rule]) {
        self.id = id
        self.version = version
        self.displayName = displayName
        self.threshold = threshold
        self.rules = rules
    }
}

public struct Rule: Sendable, Codable, Equatable {
    public let id: String
    public let weight: Int
    public let match: MatchExpression

    public init(id: String, weight: Int, match: MatchExpression) {
        self.id = id
        self.weight = weight
        self.match = match
    }
}

public indirect enum MatchExpression: Sendable, Equatable {
    case regex(String)
    case any([MatchExpression])
    case all([MatchExpression])
}

extension MatchExpression: Codable {
    private enum CodingKeys: String, CodingKey {
        case regex, any, all
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = container.allKeys
        guard keys.count == 1 else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "MatchExpression requires exactly one of {regex, any, all}, got \(keys.map(\.stringValue))"
            ))
        }
        switch keys[0] {
        case .regex:
            self = .regex(try container.decode(String.self, forKey: .regex))
        case .any:
            self = .any(try container.decode([MatchExpression].self, forKey: .any))
        case .all:
            self = .all(try container.decode([MatchExpression].self, forKey: .all))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .regex(let pattern):
            try container.encode(pattern, forKey: .regex)
        case .any(let children):
            try container.encode(children, forKey: .any)
        case .all(let children):
            try container.encode(children, forKey: .all)
        }
    }
}
