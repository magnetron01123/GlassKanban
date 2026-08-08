import XCTest

/// The rule that keeps ⌘Z off next week's chore.
///
/// Completing a repeating reminder leaves its identifier pointing at the next
/// turn of the series, not at the occurrence that was finished (measured
/// against EventKit, 08.08.2026). Every undo entry recorded for that card
/// before the completion is therefore aimed at work nobody has pulled — which
/// is exactly how a weekly shop, finished at 22:08, ended up sitting in "Als
/// Nächstes" at 22:34.
final class RecurringHandoffTests: XCTestCase {

    func testAOneOffCardKeepsItsUndo() {
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "one-off", isRecurringSeries: false)
        // Nothing changed hands: completing an ordinary reminder completes the
        // very record the board is holding.
        XCTAssertFalse(handoff.refusesReplay(of: "one-off"))
    }

    func testCompletingARepeatingCardStopsReplayedWrites() {
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true)
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop"))
    }

    /// The bug had a second act: the *first* ⌘Z replayed the move into "In
    /// Bearbeitung", the second the one into "Als Nächstes". Both have to be
    /// refused, not just the one that undoes the completion itself.
    func testEveryQueuedReplayIsRefused_notOnlyTheFirst() {
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true)
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop"))
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop"))
    }

    func testOnlyTheCompletedCardIsAffected() {
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true)
        XCTAssertFalse(handoff.refusesReplay(of: "some-other-card"))
    }

    /// When the chore's turn does come round and the user pulls it themselves,
    /// the id is about that card again — and undo has to mean what it says.
    func testADeliberateMoveHandsTheIdentifierBack() {
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true)
        handoff.movedDeliberately(cardID: "weekly-shop")
        XCTAssertFalse(handoff.refusesReplay(of: "weekly-shop"))
    }

    func testCompletingARepeatingCardTwiceStaysRefused() {
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true)
        handoff.movedDeliberately(cardID: "weekly-shop")
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true)
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop"))
    }

    /// A card that has left the board cannot be undone into the wrong lane,
    /// and a session that stays open for days must not grow a set for ever.
    func testCardsThatLeftTheBoardAreForgotten() {
        var handoff = RecurringHandoff()
        handoff.completed(cardID: "weekly-shop", isRecurringSeries: true)
        handoff.completed(cardID: "monthly-filing", isRecurringSeries: true)
        handoff.retain(["weekly-shop"])
        XCTAssertTrue(handoff.refusesReplay(of: "weekly-shop"))
        XCTAssertFalse(handoff.refusesReplay(of: "monthly-filing"))
    }
}
