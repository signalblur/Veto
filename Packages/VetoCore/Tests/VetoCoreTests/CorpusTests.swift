import Testing
@testable import VetoCore

fileprivate struct CorpusCase: Sendable {
    let body: String
    let expectedJunk: Bool
    let expectedMatchingPackPrefix: String?
    let label: String
}

fileprivate let corpus: [CorpusCase] = [
    // donations — positives
    CorpusCase(
        body: "Trump 2028: chip in $5 to defeat the radical left. Reply STOP to stop. https://secure.actblue.com/foo",
        expectedJunk: true,
        expectedMatchingPackPrefix: "donations.",
        label: "actblue URL plus stop opt-out"
    ),
    CorpusCase(
        body: "BREAKING: Donor match expires at MIDNIGHT. Chip in $10 to TRIPLE your impact for our campaign! Reply STOP to opt out.",
        expectedJunk: true,
        expectedMatchingPackPrefix: "donations.",
        label: "stop opt-out + money ask + urgency"
    ),
    CorpusCase(
        body: "Hi this is Jess from Senator Smith's campaign. Donate $25 by midnight to fund our ground game.",
        expectedJunk: true,
        expectedMatchingPackPrefix: "donations.",
        label: "campaign + money ask + urgency"
    ),
    CorpusCase(
        body: "Paid for by Smith for Senate. Your contribution will be tripled in the final 48 hours. Visit https://winred.com/smith",
        expectedJunk: true,
        expectedMatchingPackPrefix: "donations.",
        label: "winred URL plus FEC disclaimer"
    ),

    // donations — negatives (must NOT trigger)
    CorpusCase(
        body: "Hey did you donate to Bernie last year?",
        expectedJunk: false,
        expectedMatchingPackPrefix: nil,
        label: "friend asking about past donation"
    ),
    CorpusCase(
        body: "I'll pitch in $5 for pizza tonight",
        expectedJunk: false,
        expectedMatchingPackPrefix: nil,
        label: "friend pitch-in for pizza"
    ),
    CorpusCase(
        body: "Your DoorDash order #4823 totaling $25 is on the way",
        expectedJunk: false,
        expectedMatchingPackPrefix: nil,
        label: "commerce confirmation with dollar amount"
    ),
    CorpusCase(
        body: "Reminder: parent-teacher conference tomorrow at 6pm",
        expectedJunk: false,
        expectedMatchingPackPrefix: nil,
        label: "school reminder with tomorrow"
    ),

    // gotv — positives
    CorpusCase(
        body: "Polls close tonight at 8pm at your polling location: 123 Main St. Make a plan to vote!",
        expectedJunk: true,
        expectedMatchingPackPrefix: "gotv.",
        label: "polling place plus tonight"
    ),

    // gotv — negatives
    CorpusCase(
        body: "I'm voting for the new logo design tomorrow at our team meeting",
        expectedJunk: false,
        expectedMatchingPackPrefix: nil,
        label: "team meeting vote"
    ),

    // surveys — positives
    CorpusCase(
        body: "Quick survey from the campaign: who is your favorite primary candidate? Reply 1 or 2.",
        expectedJunk: true,
        expectedMatchingPackPrefix: "surveys.",
        label: "quick survey + primary candidate"
    ),

    // surveys — negatives
    CorpusCase(
        body: "Quick poll: pizza or sushi for tonight's dinner?",
        expectedJunk: false,
        expectedMatchingPackPrefix: nil,
        label: "casual food poll"
    ),

    // advocacy — positives
    CorpusCase(
        body: "ACLU urgent appeal: Donate $50 today to defend civil rights in the Supreme Court.",
        expectedJunk: true,
        expectedMatchingPackPrefix: "advocacy.",
        label: "named org + money ask without stop opt-out"
    ),
    CorpusCase(
        body: "Your contribution to Sierra Club will be tripled today. Stand with us to defend democracy and the climate.",
        expectedJunk: true,
        expectedMatchingPackPrefix: "advocacy.",
        label: "donor match with political theme keywords"
    ),

    // advocacy — negatives
    CorpusCase(
        body: "The local food bank is hosting a drive on Saturday — bring canned goods if you can.",
        expectedJunk: false,
        expectedMatchingPackPrefix: nil,
        label: "local food bank drive"
    ),
]

@Test
func bundledPacksLoadFromBundleModule() throws {
    let packs = try BundledPacks.loadAll()
    #expect(packs.count == 4)
    let ids = packs.map(\.id).sorted()
    #expect(ids == ["advocacy", "donations", "gotv", "surveys"])
}

@Test
func bundledPacksAreAllRegisteredInBundledPacksIdentifiers() {
    #expect(BundledPacks.identifiers.sorted() == ["advocacy", "donations", "gotv", "surveys"])
}

@Test
func bundledPacksCompileCleanlyAsSignatureDetectorChain() throws {
    let packs = try BundledPacks.loadAll()
    _ = try SignatureDetector(packs: packs)
}

@Test(arguments: corpus)
fileprivate func corpusEntryClassifiesAsExpected(_ entry: CorpusCase) async throws {
    let packs = try BundledPacks.loadAll()
    let detector = try SignatureDetector(packs: packs)
    let msg = InboundMessage(sender: "+15555550100", body: entry.body)

    let result = await detector.evaluate(msg)

    if entry.expectedJunk {
        guard case .match(let ruleId, _) = result else {
            Issue.record("[\(entry.label)] expected .match for body: \(entry.body); got \(result)")
            return
        }
        if let expectedPrefix = entry.expectedMatchingPackPrefix {
            #expect(ruleId.hasPrefix(expectedPrefix), "[\(entry.label)] matched ruleId \(ruleId) but expected prefix \(expectedPrefix)")
        }
    } else {
        if result != .pass {
            Issue.record("[\(entry.label)] expected .pass for body: \(entry.body); got \(result)")
        }
    }
}
