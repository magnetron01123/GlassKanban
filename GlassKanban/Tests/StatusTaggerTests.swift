import XCTest

final class StatusTaggerTests: XCTestCase {

    // MARK: - Reading

    func testNilNotesIsBacklog() {
        XCTAssertEqual(StatusTagger.status(fromNotes: nil, isCompleted: false), .backlog)
    }

    func testNotesWithoutTagIsBacklog() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "Nur eine Notiz", isCompleted: false), .backlog)
    }

    func testNextTagAnywhereInText() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "Zeile eins\n#next", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "mitten #next im Text", isCompleted: false), .next)
    }

    func testProgressTag() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inprogress", isCompleted: false), .inProgress)
    }

    func testTagIsCaseInsensitive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#NEXT", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#InProgress", isCompleted: false), .inProgress)
    }

    func testWordBoundaryPreventsFalsePositive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inprogressreport notieren", isCompleted: false), .backlog)
    }

    func testCompletedAlwaysWinsOverTag() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inprogress", isCompleted: true), .done)
    }

    func testLastTagWinsWhenMultiplePresent() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#next dann #inprogress", isCompleted: false), .inProgress)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inprogress\n#next", isCompleted: false), .next)
    }
    // MARK: - Writing
    // MARK: - Hygiene rule
    // MARK: - Legacy tag migration (pre-localization German forms, and #progress)

    func testLegacyGermanTagsAreRecognizedWhenReading() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#alsnächstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#alsnaechstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inbearbeitung", isCompleted: false), .inProgress)
    }

    func testLegacyShortGermanTagsAreRecognizedWhenReading() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#nächstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#naechstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#bearbeitung", isCompleted: false), .inProgress)
    }

    /// `#progress` predates even the German tags — a short-lived early build
    /// used it without the "in" — and stays legacy through this migration too.
    func testLegacyBareProgressTagIsRecognizedWhenReading() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#progress", isCompleted: false), .inProgress)
    }
    func testLegacyAndCurrentTagLastOneWins() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#alsnächstes\n#inprogress", isCompleted: false), .inProgress)
    }

    // MARK: - A tag has to stand alone

    /// The regressions this rule exists for. Every one of these used to be
    /// read as a tag, which meant the hygiene pass rewrote the note without
    /// the user doing anything — the URL fragment came off the link and the
    /// card jumped lanes.
    func testTagInsideOtherTextIsNotATag() {
        let notATag = [
            "Doku: https://example.com/guide#next",
            "Siehe https://wiki.intern/roadmap#progress",
            "Aufgabe fuer #next-steps Meeting",
            "Thread im Slack: #progress-report lesen",
            "Kunde: #bearbeitung/2024 Akte",
            "ABC#NEXT!",
            "Mail an chef#nächstes.de",
        ]
        for notes in notATag {
            XCTAssertEqual(
                StatusTagger.status(fromNotes: notes, isCompleted: false), .backlog,
                "\(notes) darf kein Tag sein")
            XCTAssertFalse(StatusTagger.hasStatusTag(notes), "\(notes) darf keinen Tag melden")
            XCTAssertEqual(
                StatusTagger.removingTags(notes), notes,
                "\(notes) muss die Aufräumung unangetastet überstehen")
        }
    }

    /// The text such a note carries has to survive untouched — that is the
    /// whole point of the boundary rule.
    func testTextAroundAFalseTagIsPreservedExactly() {
        let notes = "Doku: https://example.com/guide#next"
        XCTAssertEqual(StatusTagger.removingTags(notes), notes)
    }

    /// The shapes a tag really comes in: on its own line (what the app
    /// writes), after a space, at the very start, and mid-sentence.
    func testStandaloneTagIsStillRecognized() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#next", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "Notiz\n#next", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "Text #inprogress", isCompleted: false), .inProgress)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inprogress danach", isCompleted: false), .inProgress)
        XCTAssertEqual(StatusTagger.status(fromNotes: "vorher #next nachher", isCompleted: false), .next)
    }

    /// Tabs and hard line breaks are whitespace too.
    func testTabsAndNewlinesCountAsBoundaries() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "Text\t#next\t", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "a\n#inprogress\nb", isCompleted: false), .inProgress)
    }

    /// Removing a standalone tag still takes its line with it and leaves the
    /// surrounding text character-for-character.
    func testStandaloneTagIsStillRemoved() {
        XCTAssertEqual(StatusTagger.removingTags("Zeile A\n#next\nZeile B"), "Zeile A\nZeile B")
        XCTAssertEqual(StatusTagger.removingTags("Notiz #inprogress"), "Notiz")
    }
}

/// Notes do not always use "\n". Text pasted from a PDF, a web page or an
/// older source can be separated by U+2028 or a lone carriage return, and
/// lines that never held a tag have to survive those byte for byte.
final class UnusualLineSeparatorTests: XCTestCase {

    func testDoubleSpacesSurviveOnLinesWithoutATagLineSeparator() {
        let notes = "Rechnung  Nr. 4711\u{2028}Betrag  120,00 EUR\u{2028}#alsnächstes"
        XCTAssertEqual(
            StatusTagger.removingTags(notes),
            "Rechnung  Nr. 4711\u{2028}Betrag  120,00 EUR")
    }

    func testDoubleSpacesSurviveWithACarriageReturn() {
        let notes = "Zeile A  mit Abstand\rZeile B #next"
        XCTAssertEqual(
            StatusTagger.removingTags(notes),
            "Zeile A  mit Abstand\rZeile B")
    }

    /// The ordinary case must not change.
    func testNewlineSeparatedNotesAreUnaffected() {
        let notes = "Rechnung  Nr. 4711\nBetrag  120,00 EUR\n#next"
        XCTAssertEqual(
            StatusTagger.removingTags(notes),
            "Rechnung  Nr. 4711\nBetrag  120,00 EUR")
    }
}
