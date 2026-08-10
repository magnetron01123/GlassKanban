import XCTest

/// The rule that stops the board from arguing with other software.
///
/// Every correction the app makes to data it did not change itself happens
/// once; if the same state comes back, the app accepts it. Measured origin
/// (10.08.2026): a stale snapshot pushed back every 30–55 minutes had the tag
/// hygiene rewriting the same four reminders three times in three hours.
final class CorrectionLedgerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func ledgerAfterBacklogMove() -> CorrectionLedger {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "#next", wrote: nil, at: t0)
        return ledger
    }

    func testTheStateTheAppDisplacedComingBackIsCorrectedOnce() {
        let ledger = ledgerAfterBacklogMove()
        let correction = ledger.pendingEcho(for: "shop", current: "#next", now: t0.addingTimeInterval(60))
        XCTAssertNotNil(correction, "an echo of our own write must be recognised")
        XCTAssertEqual(correction ?? "unexpected", nil, "the correction restores what the app wrote")
    }

    /// Within the cooldown the board stays quiet — that is what stops a
    /// storm across the dozens of refreshes in an hour.
    func testASecondEchoInsideTheCooldownIsIgnored() {
        var ledger = ledgerAfterBacklogMove()
        XCTAssertNotNil(ledger.pendingEcho(for: "shop", current: "#next", now: t0.addingTimeInterval(60)))
        ledger.markAnswered(cardID: "shop", at: t0.addingTimeInterval(60))
        XCTAssertNil(ledger.pendingEcho(for: "shop", current: "#next", now: t0.addingTimeInterval(120)))
    }

    /// ...but the decision is not abandoned: once the cooldown is over, the
    /// board restores it again. A stale writer keeps losing.
    func testTheEchoIsAnsweredAgainAfterTheCooldown() {
        var ledger = ledgerAfterBacklogMove()
        ledger.markAnswered(cardID: "shop", at: t0.addingTimeInterval(60))
        let later = t0.addingTimeInterval(60 + CorrectionLedger.cooldown + 1)
        XCTAssertNotNil(ledger.pendingEcho(for: "shop", current: "#next", now: later))
    }

    /// Two Macs on one account cannot spin: each side answers at most once
    /// per cooldown, so the exchange stays slow and bounded.
    func testTwoMacsStayBoundedByTheCooldown() {
        var mac = ledgerAfterBacklogMove()
        mac.markAnswered(cardID: "shop", at: t0.addingTimeInterval(60))
        XCTAssertNil(mac.pendingEcho(for: "shop", current: "#next", now: t0.addingTimeInterval(120)))
        // A fresh move by this Mac's own user arms it again immediately.
        mac.record(cardID: "shop", replaced: "#next", wrote: nil, at: t0.addingTimeInterval(180))
        XCTAssertNotNil(mac.pendingEcho(for: "shop", current: "#next", now: t0.addingTimeInterval(200)))
    }

    /// Byte-exact, not status-exact: someone typing the tag by hand on their
    /// phone writes a different string than the one the app replaced, and
    /// their decision stands.
    func testAHandTypedTagIsNotMistakenForAnEcho() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "Kontrolltext\n#next", wrote: "Kontrolltext", at: t0)
        XCTAssertNil(ledger.pendingEcho(
            for: "shop", current: "Kontrolltext\n#NEXT", now: t0.addingTimeInterval(60)))
        XCTAssertNil(ledger.pendingEcho(
            for: "shop", current: "Kontrolltext #next", now: t0.addingTimeInterval(60)))
        XCTAssertNil(ledger.pendingEcho(
            for: "shop", current: "Kontrolltext\n#alsnächstes", now: t0.addingTimeInterval(60)))
    }

    /// The legacy spellings are exactly what the measured snapshot pushed
    /// back, and they are recognised — because the ledger compares against
    /// what was *replaced*, whatever that happened to be.
    func testAnEchoInALegacySpellingIsRecognised() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "chore", replaced: "#alsnächstes", wrote: nil, at: t0)
        XCTAssertNotNil(ledger.pendingEcho(
            for: "chore", current: "#alsnächstes", now: t0.addingTimeInterval(60)))
    }

    /// Any other state is a decision someone made, not an echo.
    func testAnUnrelatedStateIsLeftAlone() {
        let ledger = ledgerAfterBacklogMove()
        XCTAssertNil(ledger.pendingEcho(for: "shop", current: "#inprogress", now: t0.addingTimeInterval(60)))
        XCTAssertNil(ledger.pendingEcho(for: "shop", current: "Neuer Text", now: t0.addingTimeInterval(60)))
    }

    func testACardTheAppNeverWroteIsNeverCorrected() {
        let ledger = CorrectionLedger()
        XCTAssertNil(ledger.pendingEcho(for: "unknown", current: "#next", now: t0))
    }

    /// Preferences restored from a backup must not hand the app a target
    /// state for a board that has moved on for weeks.
    func testStaleEntriesExpire() {
        let ledger = ledgerAfterBacklogMove()
        let farLater = t0.addingTimeInterval(CorrectionLedger.staleAfter + 1)
        XCTAssertNil(ledger.pendingEcho(for: "shop", current: "#next", now: farLater))
    }

    /// A write that changed nothing displaced nothing.
    func testANoOpWriteIsNotRecorded() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "#next", wrote: "#next", at: t0)
        XCTAssertNil(ledger.pendingEcho(for: "shop", current: "#next", now: t0.addingTimeInterval(60)))
    }

    /// The user's hand outranks the bookkeeping: a later write on the same
    /// card ends the older displacement even when it changes no text — which
    /// is exactly what Backlog → Erledigt looks like, both being tagless.
    func testALaterNoOpWriteEndsAnOlderDisplacement() {
        var ledger = ledgerAfterBacklogMove()
        ledger.record(cardID: "shop", replaced: nil, wrote: nil, at: t0.addingTimeInterval(60))
        XCTAssertNil(ledger.pendingEcho(for: "shop", current: "#next", now: t0.addingTimeInterval(120)))
        XCTAssertTrue(ledger.permitsAutomaticWrite(
            for: "shop", current: "#next", now: t0.addingTimeInterval(120)))
    }

    func testRetainDropsVanishedCardsAndStaleEntries() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "live", replaced: "#next", wrote: nil, at: t0)
        ledger.record(cardID: "deleted", replaced: "#next", wrote: nil, at: t0)
        ledger.record(cardID: "ancient", replaced: "#next", wrote: nil,
                      at: t0.addingTimeInterval(-CorrectionLedger.staleAfter - 1))
        ledger.retain(["live", "ancient"], now: t0.addingTimeInterval(60))
        XCTAssertNotNil(ledger.pendingEcho(for: "live", current: "#next", now: t0.addingTimeInterval(60)))
        XCTAssertNil(ledger.pendingEcho(for: "deleted", current: "#next", now: t0.addingTimeInterval(60)))
        XCTAssertNil(ledger.pendingEcho(for: "ancient", current: "#next", now: t0.addingTimeInterval(60)))
    }

    // MARK: - The storm guard

    /// The measured incident: the hygiene stripped the same legacy tag from
    /// the same completed reminder three times in three hours. After the
    /// first answer, it must stop asking.
    func testHygieneMayCleanAStateOncePerCooldown() {
        var ledger = CorrectionLedger()
        let stale = "#alsnächstes"
        // Nothing known about this card yet — the hygiene is free to act.
        XCTAssertTrue(ledger.permitsAutomaticWrite(for: "chore", current: stale, now: t0))
        ledger.record(cardID: "chore", replaced: stale, wrote: nil, at: t0)
        ledger.markAnswered(cardID: "chore", at: t0)
        // Same refresh cycle, same state: quiet.
        XCTAssertFalse(ledger.permitsAutomaticWrite(
            for: "chore", current: stale, now: t0.addingTimeInterval(60)))
        // After the cooldown the board cleans it again rather than giving up.
        XCTAssertTrue(ledger.permitsAutomaticWrite(
            for: "chore", current: stale, now: t0.addingTimeInterval(CorrectionLedger.cooldown + 1)))
    }

    /// The guard is bound to the exact state that was answered. Anything else
    /// — including a state nobody has seen before — may still be cleaned.
    func testADifferentStateMayStillBeWritten() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "chore", replaced: "#alsnächstes", wrote: nil, at: t0)
        ledger.markAnswered(cardID: "chore", at: t0)
        XCTAssertTrue(ledger.permitsAutomaticWrite(
            for: "chore", current: "#inbearbeitung", now: t0.addingTimeInterval(60)))
    }

    /// Before the one answer is spent, writing is allowed — that write *is*
    /// the answer.
    func testAnUnansweredStateMayBeWritten() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "chore", replaced: "#alsnächstes", wrote: nil, at: t0)
        XCTAssertTrue(ledger.permitsAutomaticWrite(
            for: "chore", current: "#alsnächstes", now: t0.addingTimeInterval(60)))
    }

    /// Once the entry itself is stale, the pacing stops mattering too.
    func testTheEntryExpiresEntirely() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "chore", replaced: "#alsnächstes", wrote: nil, at: t0)
        ledger.markAnswered(cardID: "chore", at: t0)
        XCTAssertTrue(ledger.permitsAutomaticWrite(
            for: "chore", current: "#alsnächstes", now: t0.addingTimeInterval(CorrectionLedger.staleAfter + 1)))
        XCTAssertNil(ledger.pendingEcho(
            for: "chore", current: "#alsnächstes", now: t0.addingTimeInterval(CorrectionLedger.staleAfter + 1)))
    }

    /// Notes that were empty are a state like any other — a card whose only
    /// content was the tag ends up with none, and that "none" must be
    /// comparable.
    func testAbsentNotesAreAComparableState() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: nil, wrote: "#next", at: t0)
        let correction = ledger.pendingEcho(for: "shop", current: nil, now: t0.addingTimeInterval(60))
        XCTAssertEqual(correction ?? nil, "#next")
    }
}

/// The ledger's persisted half: it must survive a restart, because the writer
/// it defends against works on a scale of tens of minutes and the app may be
/// quit in between.
final class CorrectionLedgerPersistenceTests: XCTestCase {

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

    func testLedgerRoundTripsThroughDefaults() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "Text\n#next", wrote: "Text", at: t0)
        ledger.record(cardID: "chore", replaced: "#inprogress", wrote: nil, at: t0)
        ledger.save()
        XCTAssertEqual(CorrectionLedger.load(), ledger)
    }

    func testMissingKeyLoadsEmpty() {
        UserDefaults.standard.removeObject(forKey: CorrectionLedger.storageKey)
        XCTAssertEqual(CorrectionLedger.load(), CorrectionLedger())
    }

    func testForeignTypesLoadEmpty() {
        UserDefaults.standard.set("not a dictionary", forKey: CorrectionLedger.storageKey)
        XCTAssertEqual(CorrectionLedger.load(), CorrectionLedger())
    }

    /// A half-written entry says nothing usable and is dropped; the rest of
    /// the ledger survives.
    func testEntriesWithoutATimestampAreDropped() {
        UserDefaults.standard.set(
            [
                "broken": ["replaced": "#next"],
                "good": ["replaced": "#next", "at": 1_000_000.0],
            ],
            forKey: CorrectionLedger.storageKey)
        let ledger = CorrectionLedger.load()
        let now = Date(timeIntervalSince1970: 1_000_060)
        XCTAssertNil(ledger.pendingEcho(for: "broken", current: "#next", now: now))
        XCTAssertNotNil(ledger.pendingEcho(for: "good", current: "#next", now: now))
    }
}

/// The wake-up call: an answer the cooldown deferred must still be given, and
/// only the ledger knows when it is due.
final class CorrectionLedgerWakeUpTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testNothingIsDueWithoutEntries() {
        XCTAssertNil(CorrectionLedger().nextAnswerDue(now: t0))
    }

    func testAnUnansweredEntryNeedsNoWakeUp() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "#next", wrote: nil, at: t0)
        XCTAssertNil(ledger.nextAnswerDue(now: t0), "it can be answered right away")
    }

    func testAnAnsweredEntryComesDueAfterTheCooldown() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "#next", wrote: nil, at: t0)
        ledger.markAnswered(cardID: "shop", at: t0)
        let due = ledger.nextAnswerDue(now: t0.addingTimeInterval(60))
        XCTAssertEqual(due ?? 0, CorrectionLedger.cooldown - 60, accuracy: 0.5)
    }

    /// The wake-up follows whichever card comes due first.
    func testTheEarliestAnswerWins() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "early", replaced: "#next", wrote: nil, at: t0)
        ledger.markAnswered(cardID: "early", at: t0)
        ledger.record(cardID: "late", replaced: "#next", wrote: nil, at: t0)
        ledger.markAnswered(cardID: "late", at: t0.addingTimeInterval(120))
        let due = ledger.nextAnswerDue(now: t0.addingTimeInterval(120))
        XCTAssertEqual(due ?? 0, CorrectionLedger.cooldown - 120, accuracy: 0.5)
    }

    /// Once the cooldown has passed nothing is pending — the next sync will
    /// answer on its own.
    func testNothingIsDueOnceTheCooldownHasPassed() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "#next", wrote: nil, at: t0)
        ledger.markAnswered(cardID: "shop", at: t0)
        XCTAssertNil(ledger.nextAnswerDue(now: t0.addingTimeInterval(CorrectionLedger.cooldown + 1)))
    }

    /// A stale entry is nobody's business any more, so it never wakes the app.
    func testAStaleEntryNeverWakesTheApp() {
        var ledger = CorrectionLedger()
        ledger.record(cardID: "shop", replaced: "#next", wrote: nil, at: t0)
        ledger.markAnswered(cardID: "shop", at: t0.addingTimeInterval(CorrectionLedger.staleAfter - 1))
        XCTAssertNil(ledger.nextAnswerDue(now: t0.addingTimeInterval(CorrectionLedger.staleAfter + 1)))
    }
}
