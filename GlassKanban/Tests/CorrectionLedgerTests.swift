import XCTest

/// The rule that lets the board stand by what the user entered here, next to
/// other software writing into the same reminders.
///
/// Measured origin (10.08.2026): a calendar client with its own database
/// pushed a stale copy of records back every 19 to 55 minutes.
final class CorrectionLedgerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func state(
        title: String? = "Einkaufen",
        notes: String? = nil,
        url: String? = nil,
        due: Date? = nil,
        hasDueTime: Bool = false,
        isCompleted: Bool = false,
        isRecurring: Bool = false
    ) -> CorrectionLedger.CardState {
        CorrectionLedger.CardState(
            title: title, notes: notes, url: url, due: due,
            hasDueTime: hasDueTime, isCompleted: isCompleted, isRecurring: isRecurring)
    }

    /// The board pulled a card to "Als Nächstes": notes went from nothing to
    /// the tag.
    private func ledgerAfterPull() -> CorrectionLedger {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text(nil), wrote: .text("#next"), at: t0)
        return ledger
    }

    // MARK: - The displacement chain (13.08.2026)

    /// The measured hole the chain closes: the board rewrites a field more
    /// than once — here a hygiene pass normalising a legacy tag spelling,
    /// then the user's drag to Backlog — while the stale writer restores the
    /// *oldest* copy. With only the last displacement remembered, that copy
    /// compared as a third state and the defence dissolved.
    func testAnEchoOfAnEarlierDisplacementIsStillRecognised() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text("#alsnächstes"), wrote: .text("#next"), at: t0)
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text("#next"), wrote: .text(nil), at: t0.addingTimeInterval(60))
        let staleCopy = state(notes: "#alsnächstes")
        var observed = ledger
        observed.observe(cardID: "shop", state: staleCopy, now: t0.addingTimeInterval(120))
        XCTAssertEqual(
            observed.pendingEchoes(for: "shop", state: staleCopy, now: t0.addingTimeInterval(120))[.notes],
            .text(nil),
            "a value this board itself wrote over must be answered, not adopted")
    }

    /// A genuinely new value still withdraws the entry — the chain widens
    /// recognition of the board's own past, never tolerance for third states.
    func testAThirdStateStillWithdrawsAChainedEntry() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text("#alsnächstes"), wrote: .text("#next"), at: t0)
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text("#next"), wrote: .text(nil), at: t0.addingTimeInterval(60))
        ledger.observe(cardID: "shop", state: state(notes: "etwas Neues"), now: t0.addingTimeInterval(120))
        XCTAssertTrue(
            ledger.pendingEchoes(
                for: "shop", state: state(notes: "#alsnächstes"),
                now: t0.addingTimeInterval(180)).isEmpty)
    }

    /// What was just written must never sit in its own chain: an entry that
    /// "recognised" its own write would answer a state that is already
    /// correct.
    func testTheLatestWriteIsNotItsOwnEcho() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text(nil), wrote: .text("#next"), at: t0)
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text("#next"), wrote: .text(nil), at: t0.addingTimeInterval(60))
        XCTAssertTrue(
            ledger.pendingEchoes(
                for: "shop", state: state(notes: nil), now: t0.addingTimeInterval(120)).isEmpty)
    }

    /// The chain is bounded: only the newest displacements are kept.
    func testTheChainIsBounded() {
        var ledger = CorrectionLedger()
        let count = CorrectionLedger.maxDisplacedPerField + 3
        for index in 0..<count {
            ledger.record(cardID: "shop", field: .title,
                          replaced: .text("v\(index)"), wrote: .text("v\(index + 1)"),
                          at: t0.addingTimeInterval(Double(index)))
        }
        let now = t0.addingTimeInterval(Double(count))
        XCTAssertTrue(
            ledger.pendingEchoes(for: "shop", state: state(title: "v0"), now: now).isEmpty,
            "the oldest displacement has fallen out of the chain")
        XCTAssertEqual(
            ledger.pendingEchoes(for: "shop", state: state(title: "v3"), now: now)[.title],
            .text("v\(count)"))
    }

    // MARK: - The basic rule

    func testTheDisplacedValueComingBackIsAnEcho() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .notes,
                      replaced: .text("#next"), wrote: .text(nil), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "shop", state: state(notes: "#next"), now: t0.addingTimeInterval(60))
        XCTAssertEqual(echoes[.notes], .text(nil))
    }

    func testAThirdStateIsNotAnEcho() {
        let ledger = ledgerAfterPull()
        let echoes = ledger.pendingEchoes(
            for: "shop", state: state(notes: "etwas anderes"), now: t0.addingTimeInterval(60))
        XCTAssertTrue(echoes.isEmpty)
    }

    func testAStaleEntryIsSilent() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .title,
                      replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "shop", state: state(title: "Alt"),
            now: t0.addingTimeInterval(CorrectionLedger.staleAfter + 1))
        XCTAssertTrue(echoes.isEmpty)
    }

    /// An entry stamped in the future — a clock change, a file from another
    /// machine — is not something to act on.
    func testAnEntryFromTheFutureIsSilent() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .title,
                      replaced: .text("Alt"), wrote: .text("Neu"), at: t0.addingTimeInterval(3600))
        XCTAssertTrue(ledger.pendingEchoes(for: "shop", state: state(title: "Alt"), now: t0).isEmpty)
    }

    func testWithinTheCooldownTheBoardStaysQuietAndAfterwardsAnswersAgain() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .title,
                      replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        ledger.markAnswered(cardID: "shop", field: .title, at: t0.addingTimeInterval(60))
        XCTAssertTrue(ledger.pendingEchoes(
            for: "shop", state: state(title: "Alt"), now: t0.addingTimeInterval(120)).isEmpty)
        let later = t0.addingTimeInterval(60 + CorrectionLedger.cooldown + 1)
        XCTAssertEqual(
            ledger.pendingEchoes(for: "shop", state: state(title: "Alt"), now: later)[.title],
            .text("Neu"))
    }

    /// The pace is per field: an answered title does not silence notes.
    func testPacingIsPerField() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "c", field: .title, replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        ledger.record(cardID: "c", field: .notes, replaced: .text("#next"), wrote: .text(nil), at: t0)
        ledger.markAnswered(cardID: "c", field: .title, at: t0)
        let s = state(title: "Alt", notes: "#next")
        XCTAssertFalse(ledger.permitsWrite(cardID: "c", field: .title, state: s, now: t0))
        XCTAssertTrue(ledger.permitsWrite(cardID: "c", field: .notes, state: s, now: t0))
    }

    // MARK: - Withdrawal

    /// Somebody decided something new: the old displacement is history, and
    /// the board must not fight a user who changed their mind.
    func testAThirdStateWithdrawsTheEntry() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .title,
                      replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        ledger.observe(cardID: "shop", state: state(title: "Ganz was anderes"), now: t0)
        XCTAssertTrue(ledger.pendingEchoes(
            for: "shop", state: state(title: "Alt"), now: t0.addingTimeInterval(60)).isEmpty)
    }

    /// Seeing the displaced value is exactly the echo — observing must not
    /// eat it.
    func testObservingTheDisplacedValueKeepsTheEntry() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .title,
                      replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        ledger.observe(cardID: "shop", state: state(title: "Alt"), now: t0)
        XCTAssertFalse(ledger.pendingEchoes(
            for: "shop", state: state(title: "Alt"), now: t0.addingTimeInterval(60)).isEmpty)
    }

    func testObservingOurOwnValueKeepsTheEntry() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .title,
                      replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        ledger.observe(cardID: "shop", state: state(title: "Neu"), now: t0)
        XCTAssertFalse(ledger.pendingEchoes(
            for: "shop", state: state(title: "Alt"), now: t0.addingTimeInterval(60)).isEmpty)
    }

    /// A later write that displaces nothing still ends this field's entry —
    /// but only this field's.
    func testANoOpWriteClearsOnlyItsOwnField() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", field: .title, replaced: .text("A"), wrote: .text("B"), at: t0)
        ledger.record(cardID: "shop", field: .notes, replaced: .text("#next"), wrote: .text(nil), at: t0)
        ledger.record(cardID: "shop", field: .notes, replaced: .text(nil), wrote: .text(nil), at: t0)
        let s = state(title: "A", notes: "#next")
        let echoes = ledger.pendingEchoes(for: "shop", state: s, now: t0.addingTimeInterval(60))
        XCTAssertNil(echoes[.notes])
        XCTAssertEqual(echoes[.title], .text("B"))
    }

    // MARK: - Direction rules

    /// The card keeps its column: prose restored onto a card in "Als
    /// Nächstes" is allowed — the case the single-field build refused.
    /// Notes are defended in both directions since 13.08.2026. While the
    /// column lived in them, a restore could lift a card into a working lane
    /// nobody pulled it into, so only a restore that left the column alone or
    /// let the card fall to Backlog was allowed. The column has its own
    /// storage now, and the note is the user's text — half a defence would
    /// just be half a defence.
    func testNotesAreRestoredInBothDirections() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "c", field: .notes,
                      replaced: .text("Alter Text"), wrote: .text("Neuer Text"), at: t0)
        XCTAssertEqual(
            ledger.pendingEchoes(for: "c", state: state(notes: "Alter Text"),
                                 now: t0.addingTimeInterval(60))[.notes],
            .text("Neuer Text"))
    }

    /// The direction that used to be forbidden: text this board wrote comes
    /// back even when a foreign writer emptied the field. Nothing about it can
    /// move a card any more, so there is nothing left to fear here.
    func testAnEmptiedNoteIsFilledBackIn() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "c", field: .notes,
                      replaced: .text(nil), wrote: .text("Die Notiz des Nutzers"), at: t0)
        XCTAssertEqual(
            ledger.pendingEchoes(for: "c", state: state(notes: nil),
                                 now: t0.addingTimeInterval(60))[.notes],
            .text("Die Notiz des Nutzers"))
    }

    /// A hashtag in a note is now ordinary text like any other — it carries no
    /// meaning for this board and gets no special treatment.
    func testAHashtagInANoteIsJustText() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "c", field: .notes,
                      replaced: .text("#next"), wrote: .text("#inprogress"), at: t0)
        XCTAssertEqual(
            ledger.pendingEchoes(for: "c", state: state(notes: "#next"),
                                 now: t0.addingTimeInterval(60))[.notes],
            .text("#inprogress"))
    }

    /// On a completed reminder both sides read as Done, so prose comes back.
    func testNotesOnACompletedReminderMayBeRestored() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "c", field: .notes,
                      replaced: .text("alt"), wrote: .text("neu"), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "c", state: state(notes: "alt", isCompleted: true), now: t0.addingTimeInterval(60))
        XCTAssertEqual(echoes[.notes], .text("neu"))
    }

    func testAVanishedDueDateComesBack() {
        var ledger = CorrectionLedger()
        let due = Date(timeIntervalSince1970: 2_000_000)
        ledger.record(cardID: "c", field: .due,
                      replaced: .due(nil, hasTime: false), wrote: .due(due, hasTime: false), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "c", state: state(due: nil), now: t0.addingTimeInterval(60))
        XCTAssertEqual(echoes[.due], .due(due, hasTime: false))
    }

    /// A date that was *moved* is never moved back — that would let the board
    /// delete a deadline the user just set.
    func testAMovedDueDateIsNotRestored() {
        var ledger = CorrectionLedger()
        let older = Date(timeIntervalSince1970: 2_000_000)
        let newer = Date(timeIntervalSince1970: 3_000_000)
        ledger.record(cardID: "c", field: .due,
                      replaced: .due(older, hasTime: false), wrote: .due(newer, hasTime: false), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "c", state: state(due: older), now: t0.addingTimeInterval(60))
        XCTAssertNil(echoes[.due])
    }

    func testADueDateIsNeverDeleted() {
        var ledger = CorrectionLedger()
        let due = Date(timeIntervalSince1970: 2_000_000)
        ledger.record(cardID: "c", field: .due,
                      replaced: .due(due, hasTime: false), wrote: .due(nil, hasTime: false), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "c", state: state(due: due), now: t0.addingTimeInterval(60))
        XCTAssertNil(echoes[.due])
    }

    /// EventKit moves a series' date itself when it rolls on — off limits.
    func testARecurringSeriesKeepsItsDateAlone() {
        var ledger = CorrectionLedger()
        let due = Date(timeIntervalSince1970: 2_000_000)
        ledger.record(cardID: "c", field: .due,
                      replaced: .due(nil, hasTime: false), wrote: .due(due, hasTime: false), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "c", state: state(due: nil, isRecurring: true), now: t0.addingTimeInterval(60))
        XCTAssertNil(echoes[.due])
    }

    func testTitleAndURLAreRestoredInBothDirections() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "c", field: .title, replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        ledger.record(cardID: "c", field: .url,
                      replaced: .text(nil), wrote: .text("https://example.com"), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "c", state: state(title: "Alt", url: nil), now: t0.addingTimeInterval(60))
        XCTAssertEqual(echoes[.title], .text("Neu"))
        XCTAssertEqual(echoes[.url], .text("https://example.com"))
    }

    /// All four at once — one save is the store's business, not the rule's.
    func testFourFieldsCanEchoTogether() {
        var ledger = CorrectionLedger()
        let due = Date(timeIntervalSince1970: 2_000_000)
        ledger.record(cardID: "c", field: .notes, replaced: .text("alt"), wrote: .text("neu"), at: t0)
        ledger.record(cardID: "c", field: .title, replaced: .text("A"), wrote: .text("B"), at: t0)
        ledger.record(cardID: "c", field: .url, replaced: .text(nil), wrote: .text("https://x.test"), at: t0)
        ledger.record(cardID: "c", field: .due,
                      replaced: .due(nil, hasTime: false), wrote: .due(due, hasTime: true), at: t0)
        let echoes = ledger.pendingEchoes(
            for: "c", state: state(title: "A", notes: "alt", url: nil, due: nil, isCompleted: true),
            now: t0.addingTimeInterval(60))
        XCTAssertEqual(echoes.count, 4)
    }

    // MARK: - Housekeeping

    func testRetainDropsStaleEntriesAndKeepsUnfetchedCards() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "fresh", field: .title, replaced: .text("A"), wrote: .text("B"), at: t0)
        ledger.record(cardID: "ancient", field: .title, replaced: .text("A"), wrote: .text("B"),
                      at: t0.addingTimeInterval(-CorrectionLedger.staleAfter - 1))
        ledger.retain(now: t0.addingTimeInterval(60))
        let s = state(title: "A")
        XCTAssertFalse(ledger.pendingEchoes(for: "fresh", state: s, now: t0.addingTimeInterval(60)).isEmpty)
        XCTAssertTrue(ledger.pendingEchoes(for: "ancient", state: s, now: t0.addingTimeInterval(60)).isEmpty)
    }

    func testRetainCapsTheLedger() {
        var ledger = CorrectionLedger()
        for i in 0..<(CorrectionLedger.maxCards + 25) {
            ledger.record(cardID: "card-\(i)", field: .title,
                          replaced: .text("A"), wrote: .text("B"),
                          at: t0.addingTimeInterval(Double(i)))
        }
        ledger.retain(now: t0.addingTimeInterval(1000))
        let s = state(title: "A")
        XCTAssertFalse(ledger.pendingEchoes(
            for: "card-\(CorrectionLedger.maxCards + 24)", state: s,
            now: t0.addingTimeInterval(1000)).isEmpty)
        XCTAssertTrue(ledger.pendingEchoes(
            for: "card-0", state: s, now: t0.addingTimeInterval(1000)).isEmpty)
    }

    func testNextAnswerDueIsTheEarliestAcrossFieldsAndCards() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "a", field: .title, replaced: .text("A"), wrote: .text("B"), at: t0)
        ledger.record(cardID: "b", field: .notes, replaced: .text("#next"), wrote: .text(nil), at: t0)
        ledger.markAnswered(cardID: "a", field: .title, at: t0)
        ledger.markAnswered(cardID: "b", field: .notes, at: t0.addingTimeInterval(120))
        let due = ledger.nextAnswerDue(now: t0.addingTimeInterval(120))
        XCTAssertEqual(due ?? 0, CorrectionLedger.cooldown - 120, accuracy: 0.5)
    }
}

/// The persisted half: it must survive a restart, because the writer it
/// defends against works on a scale of tens of minutes.
final class CorrectionLedgerPersistenceTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private var savedValue: Any?

    override func setUp() {
        super.setUp()
        savedValue = UserDefaults.standard.object(forKey: CorrectionLedger.storageKey)
    }

    override func tearDown() {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: CorrectionLedger.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: CorrectionLedger.storageKey)
        }
        super.tearDown()
    }

    func testAllFourFieldsRoundTrip() {
        var ledger = CorrectionLedger()
        let due = Date(timeIntervalSince1970: 2_000_000)
        ledger.record(cardID: "c", field: .notes, replaced: .text(nil), wrote: .text("Text\n#next"), at: t0)
        ledger.record(cardID: "c", field: .title, replaced: .text("Alt"), wrote: .text("Neu"), at: t0)
        ledger.record(cardID: "c", field: .url, replaced: .text("https://a.test"), wrote: .text(nil), at: t0)
        ledger.record(cardID: "d", field: .due,
                      replaced: .due(nil, hasTime: false), wrote: .due(due, hasTime: true), at: t0)
        ledger.markAnswered(cardID: "c", field: .notes, at: t0.addingTimeInterval(30))
        ledger.save()
        XCTAssertEqual(CorrectionLedger.load(), ledger)
    }

    func testMissingKeyLoadsEmpty() {
        UserDefaults.standard.removeObject(forKey: CorrectionLedger.storageKey)
        XCTAssertEqual(CorrectionLedger.load(), CorrectionLedger())
    }

    func testForeignTypesLoadEmpty() {
        UserDefaults.standard.set("kein Wörterbuch", forKey: CorrectionLedger.storageKey)
        XCTAssertEqual(CorrectionLedger.load(), CorrectionLedger())
    }

    /// A version-2 payload (single displaced value) still loads: its one
    /// value becomes a chain of one, so a defence that was live at upgrade
    /// time survives it.
    func testAVersionTwoPayloadLoadsAsAChainOfOne() {
        UserDefaults.standard.set(
            [
                "v": 2,
                "cards": [
                    "shop": [
                        "notes": [
                            "at": t0.timeIntervalSince1970,
                            "replaced": ["kind": "text", "text": "#next"],
                            "wrote": ["kind": "text"],
                        ],
                    ],
                ],
            ] as [String: Any],
            forKey: CorrectionLedger.storageKey)
        let loaded = CorrectionLedger.load()
        let s = CorrectionLedger.CardState(
            title: nil, notes: "#next", url: nil, due: nil,
            hasDueTime: false, isCompleted: false, isRecurring: false)
        XCTAssertEqual(
            loaded.pendingEchoes(for: "shop", state: s, now: t0.addingTimeInterval(60))[.notes],
            .text(nil))
    }

    /// A payload from the single-field build carries no version and is
    /// discarded rather than guessed at.
    func testAPayloadWithoutAVersionIsDiscarded() {
        UserDefaults.standard.set(
            ["shop": ["replaced": "#next", "at": 1_000_000.0]],
            forKey: CorrectionLedger.storageKey)
        XCTAssertEqual(CorrectionLedger.load(), CorrectionLedger())
    }

    /// A broken field costs that field, not the ledger.
    func testABrokenFieldIsDroppedAndTheRestSurvives() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "c", field: .title, replaced: .text("A"), wrote: .text("B"), at: t0)
        ledger.save()
        var stored = UserDefaults.standard.dictionary(forKey: CorrectionLedger.storageKey)!
        var cards = stored["cards"] as! [String: [String: Any]]
        var fields = cards["c"]!
        fields["notes"] = ["at": 1_000_000.0]        // no values
        fields["erfunden"] = ["at": 1_000_000.0]     // unknown field name
        cards["c"] = fields
        stored["cards"] = cards
        UserDefaults.standard.set(stored, forKey: CorrectionLedger.storageKey)

        let loaded = CorrectionLedger.load()
        let s = CorrectionLedger.CardState(
            title: "A", notes: nil, url: nil, due: nil,
            hasDueTime: false, isCompleted: false, isRecurring: false)
        XCTAssertEqual(loaded.pendingEchoes(for: "c", state: s, now: t0.addingTimeInterval(60))[.title],
                       .text("B"))
    }

    /// "No notes at all" and "empty notes" are different states and must stay
    /// distinguishable across a save.
    func testAbsentAndEmptyTextAreDistinguishable() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "a", field: .notes, replaced: .text(nil), wrote: .text(""), at: t0)
        ledger.save()
        XCTAssertEqual(CorrectionLedger.load(), ledger)
    }
}
