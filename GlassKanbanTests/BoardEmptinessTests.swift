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

// MARK: - Deutsche Plurale

/// The counts the board says out loud. Every one of these read "1 Karten"
/// until July 2026 — in the lane tooltip someone opens *because* they are
/// counting, and in five VoiceOver labels, where a wrong ending is spoken.
final class GermanPluralTests: XCTestCase {
    func testSingularAndPlural() {
        XCTAssertEqual(GermanPlural.cards(1), "1 Karte")
        XCTAssertEqual(GermanPlural.cards(0), "0 Karten")
        XCTAssertEqual(GermanPlural.cards(7), "7 Karten")

        XCTAssertEqual(GermanPlural.olderCards(1), "1 ältere Karte")
        XCTAssertEqual(GermanPlural.olderCards(11), "11 ältere Karten")

        XCTAssertEqual(GermanPlural.days(1), "1 Tag")
        XCTAssertEqual(GermanPlural.days(2), "2 Tage")

        XCTAssertEqual(GermanPlural.tasks(1), "1 Aufgabe")
        XCTAssertEqual(GermanPlural.tasks(5), "5 Aufgaben")

        XCTAssertEqual(GermanPlural.restrictions(1), "1 Einschränkung")
        XCTAssertEqual(GermanPlural.restrictions(3), "3 Einschränkungen")
    }
}
