import XCTest

/// What the board says when it shows nothing. Three states that need three
/// different answers — the wrong one either claims the user is done when they
/// are not, or offers a button that does nothing.
final class BoardEmptinessTests: XCTestCase {

    func testNothingIsSaidWhileCardsAreVisible() {
        XCTAssertNil(BoardEmptiness.evaluate(
            hasVisibleCards: true, isFiltering: false, recurringHiddenCount: 0))
        // Even a filtered board stays quiet as long as something is on it.
        XCTAssertNil(BoardEmptiness.evaluate(
            hasVisibleCards: true, isFiltering: true, recurringHiddenCount: 3))
    }

    func testTrulyEmptyBoard() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(hasVisibleCards: false, isFiltering: false, recurringHiddenCount: 0),
            .nothingToDo)
    }

    func testActiveFilterExplainsTheBlankBoard() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(hasVisibleCards: false, isFiltering: true, recurringHiddenCount: 0),
            .filteredAway)
    }

    /// The case the board used to get wrong: no filter is active — the
    /// recurring rule rests at "hide until due" and deliberately does not count
    /// as filtering — yet every card is hidden by it. Saying "Board leer, Kopf
    /// frei" there is simply untrue, and "Filter zurücksetzen" would do
    /// nothing, because the filters are already at rest.
    func testRecurringRuleHidingEverythingIsItsOwnCase() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(hasVisibleCards: false, isFiltering: false, recurringHiddenCount: 4),
            .recurringOnly)
    }

    /// An explicit filter is the more useful thing to point at: it is what the
    /// user just changed, and resetting it also brings the recurring cards back.
    func testAnActiveFilterOutranksTheRecurringRule() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(hasVisibleCards: false, isFiltering: true, recurringHiddenCount: 4),
            .filteredAway)
    }
}
