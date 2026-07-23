import XCTest

/// The rename path is the one place on the board where an edit can destroy
/// data: the card shows a title with URLs stripped, and committing that display
/// form back to Reminders deletes the link permanently.
final class TicketRenameTests: XCTestCase {

    func testChangedTitleIsSaved() {
        XCTAssertEqual(
            TicketRename.outcome(original: "Alt", edited: "Neu"),
            .save("Neu"))
    }

    /// The regression this type exists for. The card displays
    /// "Angebot von prüfen" for a reminder actually titled
    /// "Angebot von https://example.com prüfen" — starting the edit there and
    /// committing it used to be a silent, permanent deletion of the URL.
    /// Now the edit starts from the stored title, so an untouched field is
    /// identical to it and writes nothing at all.
    func testUntouchedStoredTitleWritesNothing() {
        let stored = "Angebot von https://example.com prüfen"
        XCTAssertEqual(
            TicketRename.outcome(original: stored, edited: stored),
            .discard)
    }

    /// Saving an unchanged title is not harmless: it bumps `lastModifiedDate`,
    /// which is what the card reads as "days in this column", and pushes a
    /// no-op change through iCloud.
    func testUnchangedTitleIsDiscarded() {
        XCTAssertEqual(
            TicketRename.outcome(original: "Gleich", edited: "Gleich"),
            .discard)
    }

    func testWhitespaceOnlyDifferenceIsDiscarded() {
        XCTAssertEqual(
            TicketRename.outcome(original: "Titel", edited: "  Titel  "),
            .discard)
    }

    /// Nobody empties a title on purpose — that is a card whose name has been
    /// wiped, not a rename.
    func testEmptiedTitleIsDiscarded() {
        XCTAssertEqual(TicketRename.outcome(original: "Titel", edited: ""), .discard)
        XCTAssertEqual(TicketRename.outcome(original: "Titel", edited: "   \n "), .discard)
    }

    func testSavedTitleIsTrimmed() {
        XCTAssertEqual(
            TicketRename.outcome(original: "Alt", edited: "  Neu  "),
            .save("Neu"))
    }

    /// A title that only ever existed as whitespace still counts as changed
    /// once real text is typed over it.
    func testTypingOverAnEmptyTitleSaves() {
        XCTAssertEqual(
            TicketRename.outcome(original: "", edited: "Endlich ein Titel"),
            .save("Endlich ein Titel"))
    }
}
