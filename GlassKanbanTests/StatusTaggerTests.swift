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

    func testTagCount() {
        XCTAssertEqual(StatusTagger.tagCount(nil), 0)
        XCTAssertEqual(StatusTagger.tagCount("nichts"), 0)
        XCTAssertEqual(StatusTagger.tagCount("#next"), 1)
        XCTAssertEqual(StatusTagger.tagCount("#next #inprogress #NEXT"), 3)
    }

    // MARK: - Writing

    func testRewriteAppendsTagAsOwnLastLine() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz", for: .next), "Meine Notiz\n#next")
    }

    func testRewriteReplacesExistingTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#next", for: .inProgress), "Meine Notiz\n#inprogress")
    }

    func testRewriteToBacklogRemovesTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#inprogress", for: .backlog), "Meine Notiz")
    }

    func testRewriteToDoneRemovesTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#next", for: .done), "Meine Notiz")
    }

    func testRewriteTagOnlyNotesToBacklogBecomesNil() {
        XCTAssertNil(StatusTagger.rewrittenNotes("#next", for: .backlog))
    }

    func testRewriteNilNotesToNext() {
        XCTAssertEqual(StatusTagger.rewrittenNotes(nil, for: .next), "#next")
    }

    func testRewriteRemovesAllTagsBeforeAppending() {
        XCTAssertEqual(
            StatusTagger.rewrittenNotes("#next Text #inprogress", for: .next),
            "Text\n#next")
    }

    func testRewritePreservesUserTextExactly() {
        let notes = "Zeile 1\nZeile 2 mit Inhalt"
        XCTAssertEqual(StatusTagger.rewrittenNotes(notes, for: .backlog), notes)
    }

    /// Blank lines are how people separate paragraphs. An earlier version ran
    /// a "collapse runs of blank lines" pass over the *whole* note on every
    /// single move, so dragging a card quietly rewrote text the tag never
    /// touched — and did it again for every card, every move.
    func testRewriteKeepsBlankLinesTheUserPutThere() {
        let notes = "Absatz eins\n\n\nAbsatz zwei"
        XCTAssertEqual(StatusTagger.rewrittenNotes(notes, for: .backlog), notes)
        XCTAssertEqual(
            StatusTagger.rewrittenNotes(notes, for: .next),
            "Absatz eins\n\n\nAbsatz zwei\n#next")
    }

    /// The tag's own line goes with it, rather than leaving a blank one where
    /// it stood — that is the tidying the blanket pass was there for.
    func testRewriteDropsTheLineTheTagOccupied() {
        XCTAssertEqual(
            StatusTagger.rewrittenNotes("Notiz\n\n#inprogress", for: .backlog),
            "Notiz")
        XCTAssertEqual(
            StatusTagger.rewrittenNotes("Erste\n#inprogress\nLetzte", for: .backlog),
            "Erste\nLetzte")
    }

    /// Writing a tag repeatedly has to land on the same text every time, or
    /// each save would trigger another change notification and another save.
    func testRewriteIsIdempotent() {
        let once = StatusTagger.rewrittenNotes("Notiz", for: .inProgress)
        XCTAssertEqual(StatusTagger.rewrittenNotes(once, for: .inProgress), once)
    }

    // MARK: - Hygiene rule

    func testNeedsHygieneOnlyWhenSomethingIsActuallyWrong() {
        // The normal cases: nothing to clean up.
        XCTAssertFalse(StatusTagger.needsHygiene(notes: nil, isCompleted: false))
        XCTAssertFalse(StatusTagger.needsHygiene(notes: "Notiz", isCompleted: false))
        XCTAssertFalse(StatusTagger.needsHygiene(notes: "Notiz\n#next", isCompleted: false))
        XCTAssertFalse(StatusTagger.needsHygiene(notes: "Notiz", isCompleted: true))

        // Ticked off in Reminders, so the old status line is now stale.
        XCTAssertTrue(StatusTagger.needsHygiene(notes: "Notiz\n#inprogress", isCompleted: true))
        // Two tags at once, e.g. one typed by hand on the phone.
        XCTAssertTrue(StatusTagger.needsHygiene(notes: "#next\n#inprogress", isCompleted: false))
        // Written by an older build.
        XCTAssertTrue(StatusTagger.needsHygiene(notes: "Notiz\n#progress", isCompleted: false))
    }

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

    func testHasLegacyTag() {
        XCTAssertTrue(StatusTagger.hasLegacyTag("Notiz\n#progress"))
        XCTAssertTrue(StatusTagger.hasLegacyTag("Notiz\n#bearbeitung"))
        XCTAssertTrue(StatusTagger.hasLegacyTag("Notiz\n#alsnächstes"))
        XCTAssertFalse(StatusTagger.hasLegacyTag("Notiz\n#inprogress"))
        XCTAssertFalse(StatusTagger.hasLegacyTag(nil))
    }

    func testRewriteMigratesLegacyTagsToCurrentForm() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#progress", for: .inProgress), "Notiz\n#inprogress")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#alsnächstes", for: .next), "Notiz\n#next")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#alsnaechstes", for: .next), "Notiz\n#next")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#bearbeitung", for: .inProgress), "Notiz\n#inprogress")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#nächstes", for: .next), "Notiz\n#next")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#inbearbeitung", for: .inProgress), "Notiz\n#inprogress")
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
            XCTAssertEqual(StatusTagger.tagCount(notes), 0, "\(notes) darf nicht mitgezählt werden")
            XCTAssertFalse(StatusTagger.hasLegacyTag(notes), "\(notes) ist kein Legacy-Tag")
            XCTAssertFalse(
                StatusTagger.needsHygiene(notes: notes, isCompleted: false),
                "\(notes) darf keine Umschreibung auslösen")
        }
    }

    /// The text such a note carries has to survive untouched — that is the
    /// whole point of the boundary rule.
    func testTextAroundAFalseTagIsPreservedExactly() {
        let notes = "Doku: https://example.com/guide#next"
        XCTAssertEqual(StatusTagger.removingTags(notes), notes)
        XCTAssertEqual(StatusTagger.rewrittenNotes(notes, for: .backlog), notes)
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
        let rewritten = StatusTagger.rewrittenNotes(notes, for: .next)
        XCTAssertEqual(rewritten, "Rechnung  Nr. 4711\u{2028}Betrag  120,00 EUR\n#next")
    }

    func testDoubleSpacesSurviveWithACarriageReturn() {
        let notes = "Zeile A  mit Abstand\rZeile B #next"
        XCTAssertEqual(
            StatusTagger.rewrittenNotes(notes, for: .backlog),
            "Zeile A  mit Abstand\rZeile B")
    }

    /// The ordinary case must not change.
    func testNewlineSeparatedNotesAreUnaffected() {
        let notes = "Rechnung  Nr. 4711\nBetrag  120,00 EUR\n#next"
        XCTAssertEqual(
            StatusTagger.rewrittenNotes(notes, for: .backlog),
            "Rechnung  Nr. 4711\nBetrag  120,00 EUR")
    }
}
