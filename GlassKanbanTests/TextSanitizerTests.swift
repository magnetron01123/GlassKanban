import XCTest

final class TextSanitizerTests: XCTestCase {

    // MARK: - Titles

    func testTitleStripsHTTPSURL() {
        XCTAssertEqual(
            TextSanitizer.displayTitle("Feedback aus https://github.com/x/y einarbeiten"),
            "Feedback aus einarbeiten")
    }

    func testTitleStripsWWWURL() {
        XCTAssertEqual(
            TextSanitizer.displayTitle("Siehe www.example.com dazu"),
            "Siehe dazu")
    }

    func testTitleWithoutURLUnchanged() {
        XCTAssertEqual(TextSanitizer.displayTitle("Ganz normaler Titel"), "Ganz normaler Titel")
    }

    func testNilTitleIsEmpty() {
        XCTAssertEqual(TextSanitizer.displayTitle(nil), "")
    }

    // MARK: - Notes preview

    func testPreviewSkipsURLOnlyLine() {
        XCTAssertEqual(
            TextSanitizer.notesPreview("https://example.com\nEigentlicher Inhalt"),
            "Eigentlicher Inhalt")
    }

    func testPreviewSkipsStatusTag() {
        XCTAssertEqual(TextSanitizer.notesPreview("Wichtige Notiz\n#nächstes"), "Wichtige Notiz")
        XCTAssertEqual(TextSanitizer.notesPreview("#bearbeitung"), "")
    }

    func testPreviewStripsInlineURL() {
        XCTAssertEqual(
            TextSanitizer.notesPreview("Details unter https://example.com/docs nachlesen"),
            "Details unter nachlesen")
    }

    func testPreviewOfNilIsEmpty() {
        XCTAssertEqual(TextSanitizer.notesPreview(nil), "")
    }

    func testPreviewUsesFirstNonEmptyLine() {
        XCTAssertEqual(TextSanitizer.notesPreview("\n\nDritte Zeile zählt"), "Dritte Zeile zählt")
    }

    // MARK: - Excerpt (several lines, for the working-lane cards)

    func testExcerptKeepsSeveralLinesAndDropsBlanks() {
        XCTAssertEqual(
            TextSanitizer.notesExcerpt("Erste\n\nZweite\nDritte"),
            "Erste\nZweite\nDritte")
    }

    func testExcerptStopsAtMaxLines() {
        XCTAssertEqual(
            TextSanitizer.notesExcerpt("Eins\nZwei\nDrei\nVier", maxLines: 2),
            "Eins\nZwei")
    }

    func testExcerptStripsURLsAndStatusTags() {
        XCTAssertEqual(
            TextSanitizer.notesExcerpt("Siehe https://example.com hier\n#inbearbeitung\nRest"),
            "Siehe hier\nRest")
    }

    func testExcerptOfNilIsEmpty() {
        XCTAssertEqual(TextSanitizer.notesExcerpt(nil), "")
    }
}
