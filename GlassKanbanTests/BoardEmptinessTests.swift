import XCTest

/// What the board says when it shows nothing. Three states that need three
/// different answers — the wrong one either claims the user is done when they
/// are not, or offers a button that does nothing.
final class BoardEmptinessTests: XCTestCase {

    func testNothingIsSaidWhileCardsAreVisible() {
        XCTAssertNil(BoardEmptiness.evaluate(hasVisibleCards: true, isFiltering: false))
        // Even a filtered board stays quiet as long as something is on it.
        XCTAssertNil(BoardEmptiness.evaluate(hasVisibleCards: true, isFiltering: true))
    }

    func testTrulyEmptyBoard() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(hasVisibleCards: false, isFiltering: false),
            .nothingToDo)
    }

    func testActiveFilterExplainsTheBlankBoard() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(hasVisibleCards: false, isFiltering: true),
            .filteredAway)
    }
}

// MARK: - Keine Liste ausgewählt

extension BoardEmptinessTests {
    /// Excluding every list leaves the board with no source. That is a
    /// setting, not an achievement — it must never read as "Nichts zu tun".
    func testNoSelectedListsIsItsOwnState() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(
                hasVisibleCards: false, isFiltering: false, hasSelectedLists: false),
            .noListsSelected)
    }

    /// It outranks the filter answer: with no source, no filter can be what
    /// is hiding the cards, and "Filter zurücksetzen" would do nothing.
    func testNoSelectedListsOutranksFiltering() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(
                hasVisibleCards: false, isFiltering: true, hasSelectedLists: false),
            .noListsSelected)
    }

    /// With a source present, nothing about the existing answers changes.
    func testSelectedListsLeaveTheOtherAnswersAlone() {
        XCTAssertEqual(
            BoardEmptiness.evaluate(
                hasVisibleCards: false, isFiltering: true, hasSelectedLists: true),
            .filteredAway)
        XCTAssertEqual(
            BoardEmptiness.evaluate(
                hasVisibleCards: false, isFiltering: false, hasSelectedLists: true),
            .nothingToDo)
        XCTAssertNil(
            BoardEmptiness.evaluate(
                hasVisibleCards: true, isFiltering: false, hasSelectedLists: false))
    }
}
