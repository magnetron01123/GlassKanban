import XCTest

/// A title that does not fit loses whole words, never half of one.
final class WordTruncationTests: XCTestCase {

    /// Ten points per character stands in for a font.
    private func width(_ s: String) -> CGFloat { CGFloat(s.count) * 10 }

    func testATitleThatFitsIsUntouched() {
        XCTAssertEqual(WordTruncation.fit("Joris baden", in: 110, measure: width), "Joris baden")
    }

    func testTheLastWordGoesFirst() {
        // "Geräte in Apple Home…" is 21 characters.
        XCTAssertEqual(
            WordTruncation.fit("Geräte in Apple Home ausschließen", in: 220, measure: width),
            "Geräte in Apple Home…")
    }

    func testAsManyWordsGoAsNeeded() {
        XCTAssertEqual(
            WordTruncation.fit("Geräte in Apple Home ausschließen", in: 110, measure: width),
            "Geräte in…")
    }

    func testTheEllipsisCountsTowardsTheWidth() {
        // "Geräte in" alone is 9, with the ellipsis 10 — at 95 it must fall back further.
        XCTAssertEqual(WordTruncation.fit("Geräte in Apple", in: 95, measure: width), "Geräte…")
    }

    /// A single word wider than the line is handed back whole: the row's
    /// own character truncation is the only cut left, and this function
    /// must not invent one.
    func testASingleOverlongWordStaysWhole() {
        XCTAssertEqual(
            WordTruncation.fit("Hausratversicherung abschließen", in: 50, measure: width),
            "Hausratversicherung")
    }

    func testDoubleSpacesDoNotProduceEmptyWords() {
        XCTAssertEqual(WordTruncation.fit("a  b  c", in: 40, measure: width), "a b…")
    }
}
