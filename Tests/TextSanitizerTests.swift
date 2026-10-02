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

    // MARK: - Link host

    /// A title that is nothing but a link strips to nothing; the host is
    /// what the card shows instead of "Untitled".
    func testLinkHostOfALinkOnlyTitle() {
        let raw = "https://www.Example.com/ein/pfad?x=1#frag"
        XCTAssertEqual(TextSanitizer.displayTitle(raw), "")
        XCTAssertEqual(TextSanitizer.firstLinkHost(raw), "example.com")
    }

    func testLinkHostWithoutScheme() {
        XCTAssertEqual(TextSanitizer.firstLinkHost("www.example.org/x"), "example.org")
    }

    func testLinkHostDropsThePort() {
        XCTAssertEqual(TextSanitizer.firstLinkHost("http://localhost:8123/lovelace"), "localhost")
    }

    func testNoLinkHasNoHost() {
        XCTAssertNil(TextSanitizer.firstLinkHost("Ganz normaler Titel"))
        XCTAssertNil(TextSanitizer.firstLinkHost(nil))
    }

    /// The host must never reach the value rename compares against — it
    /// would be written back into the reminder as its title.
    func testDisplayTitleNeverCarriesTheHost() {
        XCTAssertEqual(TextSanitizer.displayTitle("https://example.com"), "")
    }

    // MARK: - Notes preview

    func testPreviewSkipsURLOnlyLine() {
        XCTAssertEqual(
            TextSanitizer.notesPreview("https://example.com\nEigentlicher Inhalt"),
            "Eigentlicher Inhalt")
    }

    /// Inverted on 13.08.2026. While the board wrote status tags, hiding its
    /// own control token was honest. It writes none any more, so a hashtag in
    /// a note is the user's word and gets shown like every other.
    func testAHashtagIsShownLikeAnyOtherWord() {
        XCTAssertEqual(TextSanitizer.notesPreview("Wichtige Notiz\n#nächstes"), "Wichtige Notiz")
        XCTAssertEqual(TextSanitizer.notesPreview("#bearbeitung"), "#bearbeitung")
        XCTAssertEqual(TextSanitizer.notesPreview("#next"), "#next")
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

    func testExcerptStripsURLsAndKeepsEverythingElse() {
        XCTAssertEqual(
            TextSanitizer.notesExcerpt("Siehe https://example.com hier\n#inbearbeitung\nRest"),
            "Siehe hier\n#inbearbeitung\nRest")
    }

    func testExcerptOfNilIsEmpty() {
        XCTAssertEqual(TextSanitizer.notesExcerpt(nil), "")
    }
}

/// Text that only looks like a status tag belongs to the user — it must
/// survive the card's own display path, which also feeds Find.
final class TagLookalikeDisplayTests: XCTestCase {

    func testHashtaggedWordsInNotesSurviveTheCardPreview() {
        let cases = [
            "Aufgabe fuer #next-steps Meeting",
            "Thread im Slack: #progress-report lesen",
            "Kunde: #bearbeitung/2024 Akte",
        ]
        for notes in cases {
            XCTAssertEqual(TextSanitizer.notesPreview(notes), notes, "preview mangled: \(notes)")
            XCTAssertEqual(TextSanitizer.notesExcerpt(notes), notes, "excerpt mangled: \(notes)")
        }
    }

    /// A real tag on its own line still disappears from the card.
    func testARealTagIsStillHidden() {
        XCTAssertEqual(TextSanitizer.notesPreview("Kontrolltext\n#next"), "Kontrolltext")
    }
}
