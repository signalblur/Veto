import Testing
import Foundation
@testable import VetoCore

@Test
func packDecodesValidJSONWithSingleRegexRule() throws {
    let json = """
    {
      "id": "donations",
      "version": "2026.04.18",
      "displayName": "Political Donations",
      "threshold": 60,
      "rules": [
        {"id": "donations.actblue", "weight": 100,
         "match": {"regex": "secure\\\\.actblue\\\\.com"}}
      ]
    }
    """
    let pack = try JSONDecoder().decode(Pack.self, from: Data(json.utf8))

    #expect(pack.id == "donations")
    #expect(pack.version == "2026.04.18")
    #expect(pack.displayName == "Political Donations")
    #expect(pack.threshold == 60)
    #expect(pack.rules.count == 1)
    #expect(pack.rules[0].id == "donations.actblue")
    #expect(pack.rules[0].weight == 100)
    #expect(pack.rules[0].match == .regex("secure\\.actblue\\.com"))
}

@Test
func packDecodesNestedAnyInsideAll() throws {
    let json = """
    {"id":"p","version":"v","displayName":"P","threshold":50,"rules":[
      {"id":"r","weight":50,"match":{"all":[
        {"any":[{"regex":"foo"},{"regex":"bar"}]},
        {"regex":"baz"}
      ]}}
    ]}
    """
    let pack = try JSONDecoder().decode(Pack.self, from: Data(json.utf8))

    #expect(pack.rules[0].match == .all([
        .any([.regex("foo"), .regex("bar")]),
        .regex("baz"),
    ]))
}

@Test
func matchExpressionDecodeRejectsMultipleKeys() {
    let json = #"{"regex":"foo","any":[{"regex":"bar"}]}"#
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(MatchExpression.self, from: Data(json.utf8))
    }
}

@Test
func matchExpressionDecodeRejectsZeroKeys() {
    let json = "{}"
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(MatchExpression.self, from: Data(json.utf8))
    }
}

@Test
func matchExpressionRoundTripsThroughEncoding() throws {
    let original: MatchExpression = .all([
        .any([.regex("foo"), .regex("bar")]),
        .regex("baz"),
    ])

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(MatchExpression.self, from: data)

    #expect(decoded == original)
}
