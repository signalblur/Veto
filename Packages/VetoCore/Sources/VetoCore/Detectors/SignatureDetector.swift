import Foundation

public struct SignatureDetector: Detector {
    private let compiledPacks: [CompiledPack]

    public init(packs: [Pack]) throws {
        self.compiledPacks = try packs.map(CompiledPack.compile)
    }

    public func evaluate(_ msg: InboundMessage) async -> DetectionResult {
        for pack in compiledPacks {
            var totalScore = 0
            var bestRuleId: String?
            var bestWeight = -1
            for rule in pack.rules where rule.matches(msg.body) {
                totalScore += rule.weight
                if rule.weight > bestWeight {
                    bestWeight = rule.weight
                    bestRuleId = rule.id
                }
            }
            if totalScore >= pack.threshold, let ruleId = bestRuleId {
                return .match(ruleId: ruleId, confidence: 1.0)
            }
        }
        return .pass
    }
}

private struct CompiledPack: Sendable {
    let id: String
    let threshold: Int
    let rules: [CompiledRule]

    static func compile(_ pack: Pack) throws -> CompiledPack {
        guard !pack.rules.isEmpty else {
            throw PackLoadError.emptyRules(packId: pack.id)
        }
        var seenIds = Set<String>()
        var compiled: [CompiledRule] = []
        compiled.reserveCapacity(pack.rules.count)
        for rule in pack.rules {
            if !seenIds.insert(rule.id).inserted {
                throw PackLoadError.duplicateRuleId(ruleId: rule.id, packId: pack.id)
            }
            compiled.append(try CompiledRule.compile(rule))
        }
        return CompiledPack(id: pack.id, threshold: pack.threshold, rules: compiled)
    }
}

private struct CompiledRule: Sendable {
    let id: String
    let weight: Int
    let tree: CompiledMatchTree

    static func compile(_ rule: Rule) throws -> CompiledRule {
        let tree = try CompiledMatchTree.compile(rule.match, ruleId: rule.id)
        return CompiledRule(id: rule.id, weight: rule.weight, tree: tree)
    }

    func matches(_ body: String) -> Bool {
        tree.matches(body)
    }
}

// @unchecked: Regex<> is value-typed, immutable, and thread-safe per Apple docs; stdlib has not yet declared Sendable.
private indirect enum CompiledMatchTree: @unchecked Sendable {
    case regex(Regex<AnyRegexOutput>)
    case any([CompiledMatchTree])
    case all([CompiledMatchTree])

    static func compile(_ expr: MatchExpression, ruleId: String) throws -> CompiledMatchTree {
        switch expr {
        case .regex(let pattern):
            do {
                return .regex(try Regex(pattern))
            } catch {
                throw PackLoadError.invalidRegex(ruleId: ruleId, pattern: pattern, underlying: "\(error)")
            }
        case .any(let children):
            return .any(try children.map { try compile($0, ruleId: ruleId) })
        case .all(let children):
            return .all(try children.map { try compile($0, ruleId: ruleId) })
        }
    }

    func matches(_ body: String) -> Bool {
        switch self {
        case .regex(let regex):
            return body.contains(regex)
        case .any(let children):
            return children.contains { $0.matches(body) }
        case .all(let children):
            return children.allSatisfy { $0.matches(body) }
        }
    }
}
