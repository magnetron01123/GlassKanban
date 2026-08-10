import XCTest

/// The rule that keeps ⌘Z off next week's chore.
///
/// Completing a repeating reminder leaves its identifier pointing at the next
/// turn of the series, not at the occurrence that was finished (measured
/// against EventKit, 08.08.2026). Every undo entry recorded for that card
/// *before* the completion is therefore aimed at work nobody has pulled —
/// which is how a weekly shop, finished at 22:08, ended up sitting in "Als
/// Nächstes" at 22:34.
///
/// Since 10.08.2026 the fence is an order rather than a flag: entries made
/// after the completion belong to the returned occurrence and replay
/// normally.
final class RecurringHandoffTests: XCTestCase {

    /// A short helper so the tests read as a sequence of writes.
    private func writes(_ count: Int) -> [RecurringHandoff.Generation] {
        var stamps: [RecurringHandoff.Generation] = []
        var current = RecurringHandoff.Generation.first
        for _ in 0..<count {
            current = current.next()
            stamps.append(current)
        }
        return stamps
    }

    func testAOneOffCardFencesNothing() {
        let w = writes(2)
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "one-off", isRecurringSeries: false, at: w[0])
        XCTAssertFalse(handoff.refusesReplay(of: "one-off", recordedAt: w[0]))
        XCTAssertFalse(handoff.refusesUnattributedWrite(to: "one-off"))
    }

    func testAnEntryFromBeforeTheCompletionIsRefused() {
        let w = writes(3)
        var handoff = RecurringHandoff()
        // w[0]: the move into a working lane. w[1]: the completion.
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[1])
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[0]))
    }

    /// The completing write and its own undo entry share a stamp — and that
    /// entry is the one measured writing `#inprogress` onto the next turn.
    /// This is why the comparison is `<=`.
    func testTheCompletionsOwnEntryIsRefused() {
        let w = writes(2)
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[0])
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[0]))
    }

    /// The user's own later work on the returned occurrence is theirs.
    func testAnEntryFromAfterTheCompletionReplays() {
        let w = writes(3)
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[0])
        XCTAssertFalse(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[1]))
        XCTAssertFalse(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[2]))
    }

    /// The reported failure, as a regression test: completing, then pulling
    /// the returned occurrence, then pressing ⌘Z twice. The second step must
    /// still be refused — a deliberate move does not unlock the past.
    func testADeliberateMoveDoesNotUnlockOlderEntries() {
        let w = writes(4)
        var handoff = RecurringHandoff()
        // w[0]: move into a working lane. w[1]: completion. w[2]: the pull of
        // the returned occurrence.
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[1])
        handoff.movedDeliberately(cardID: "weekly-shop")
        XCTAssertFalse(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[2]),
                       "the pull's own entry undoes normally")
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[0]),
                      "the entry from before the completion still aims at work that is gone")
    }

    /// A second completion re-fences everything up to it, including the
    /// deliberate move that came in between.
    func testASecondCompletionFencesEverythingBeforeIt() {
        let w = writes(4)
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[0])
        handoff.movedDeliberately(cardID: "weekly-shop")
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[2])
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[1]))
        XCTAssertFalse(handoff.refusesReplay(of: "weekly-shop", recordedAt: w[3]))
    }

    func testOnlyTheCompletedIdentifierIsFenced() {
        let w = writes(2)
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[1])
        XCTAssertFalse(handoff.refusesReplay(of: "some-other-card", recordedAt: w[0]))
    }

    func testGenerationsAreStrictlyIncreasingFromFirst() {
        let w = writes(3)
        XCTAssertTrue(RecurringHandoff.Generation.first < w[0])
        XCTAssertTrue(w[0] < w[1])
        XCTAssertTrue(w[1] < w[2])
    }

    // MARK: - The question an order cannot answer

    /// Automatic writes — an echo answer, a hygiene pass — carry no undo entry
    /// and therefore no position, so they can only ask whether the identifier
    /// still points at an unpulled turn. Here a deliberate move genuinely does
    /// hand it back.
    func testUnattributedWritesAreRefusedUntilTheUserActs() {
        let w = writes(2)
        var handoff = RecurringHandoff()
        XCTAssertFalse(handoff.refusesUnattributedWrite(to: "weekly-shop"),
                       "nothing known about this card")
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true, at: w[0])
        XCTAssertTrue(handoff.refusesUnattributedWrite(to: "weekly-shop"))
        handoff.movedDeliberately(cardID: "weekly-shop")
        XCTAssertFalse(handoff.refusesUnattributedWrite(to: "weekly-shop"),
                       "the user is acting on the card in front of them")
    }

    /// A deliberate move on a card that was never completed says nothing.
    func testADeliberateMoveWithoutAHandoverChangesNothing() {
        var handoff = RecurringHandoff()
        handoff.movedDeliberately(cardID: "ordinary")
        XCTAssertFalse(handoff.refusesUnattributedWrite(to: "ordinary"))
    }

    // MARK: - Bounds

    /// Bounded by count, not by the board: a series whose list is switched off
    /// in Settings leaves the refresh while its undo entries stay on the
    /// stack, and dropping the fence there let exactly the measured write
    /// land. The newest handovers survive.
    func testRetainKeepsTheNewestHandovers() {
        var handoff = RecurringHandoff()
        var stamp = RecurringHandoff.Generation.first
        var first: RecurringHandoff.Generation?
        for i in 0..<(RecurringHandoff.maxHandovers + 10) {
            stamp = stamp.next()
            if i == 0 { first = stamp }
            handoff.completed(cardID: "card-\(i)", isRecurringSeries: true, at: stamp)
        }
        handoff.retain()
        XCTAssertFalse(
            handoff.refusesReplay(of: "card-0", recordedAt: first!),
            "the oldest handover is dropped once the bound is exceeded")
        XCTAssertTrue(
            handoff.refusesReplay(
                of: "card-\(RecurringHandoff.maxHandovers + 9)", recordedAt: stamp),
            "the newest survives")
    }
}
