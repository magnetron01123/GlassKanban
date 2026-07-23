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
        XCTAssertEqual(StatusTagger.status(fromNotes: "Zeile eins\n#alsnächstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "mitten #alsnächstes im Text", isCompleted: false), .next)
    }

    func testNextTagAcceptsUmlautFreeSpelling() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#alsnaechstes", isCompleted: false), .next)
    }

    func testProgressTag() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inbearbeitung", isCompleted: false), .inProgress)
    }

    func testTagIsCaseInsensitive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#ALSNÄCHSTES", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#InBearbeitung", isCompleted: false), .inProgress)
    }

    func testWordBoundaryPreventsFalsePositive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inbearbeitungszeit notieren", isCompleted: false), .backlog)
    }

    func testCompletedAlwaysWinsOverTag() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inbearbeitung", isCompleted: true), .done)
    }

    func testLastTagWinsWhenMultiplePresent() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#alsnächstes dann #inbearbeitung", isCompleted: false), .inProgress)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#inbearbeitung\n#alsnächstes", isCompleted: false), .next)
    }

    func testTagCount() {
        XCTAssertEqual(StatusTagger.tagCount(nil), 0)
        XCTAssertEqual(StatusTagger.tagCount("nichts"), 0)
        XCTAssertEqual(StatusTagger.tagCount("#alsnächstes"), 1)
        XCTAssertEqual(StatusTagger.tagCount("#alsnächstes #inbearbeitung #ALSNAECHSTES"), 3)
    }

    // MARK: - Writing

    func testRewriteAppendsTagAsOwnLastLine() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz", for: .next), "Meine Notiz\n#alsnächstes")
    }

    func testRewriteReplacesExistingTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#alsnächstes", for: .inProgress), "Meine Notiz\n#inbearbeitung")
    }

    func testRewriteNormalizesUmlautFreeSpelling() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#alsnaechstes", for: .next), "Meine Notiz\n#alsnächstes")
    }

    func testRewriteToBacklogRemovesTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#inbearbeitung", for: .backlog), "Meine Notiz")
    }

    func testRewriteToDoneRemovesTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#alsnächstes", for: .done), "Meine Notiz")
    }

    func testRewriteTagOnlyNotesToBacklogBecomesNil() {
        XCTAssertNil(StatusTagger.rewrittenNotes("#alsnächstes", for: .backlog))
    }

    func testRewriteNilNotesToNext() {
        XCTAssertEqual(StatusTagger.rewrittenNotes(nil, for: .next), "#alsnächstes")
    }

    func testRewriteRemovesAllTagsBeforeAppending() {
        XCTAssertEqual(
            StatusTagger.rewrittenNotes("#alsnächstes Text #inbearbeitung", for: .next),
            "Text\n#alsnächstes")
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
            "Absatz eins\n\n\nAbsatz zwei\n#alsnächstes")
    }

    /// The tag's own line goes with it, rather than leaving a blank one where
    /// it stood — that is the tidying the blanket pass was there for.
    func testRewriteDropsTheLineTheTagOccupied() {
        XCTAssertEqual(
            StatusTagger.rewrittenNotes("Notiz\n\n#inbearbeitung", for: .backlog),
            "Notiz")
        XCTAssertEqual(
            StatusTagger.rewrittenNotes("Erste\n#inbearbeitung\nLetzte", for: .backlog),
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
        XCTAssertFalse(StatusTagger.needsHygiene(notes: "Notiz\n#alsnächstes", isCompleted: false))
        XCTAssertFalse(StatusTagger.needsHygiene(notes: "Notiz", isCompleted: true))

        // Ticked off in Reminders, so the old status line is now stale.
        XCTAssertTrue(StatusTagger.needsHygiene(notes: "Notiz\n#inbearbeitung", isCompleted: true))
        // Two tags at once, e.g. one typed by hand on the phone.
        XCTAssertTrue(StatusTagger.needsHygiene(notes: "#alsnächstes\n#inbearbeitung", isCompleted: false))
        // Written by an older build.
        XCTAssertTrue(StatusTagger.needsHygiene(notes: "Notiz\n#progress", isCompleted: false))
    }

    // MARK: - Legacy tag migration (#next/#progress and #nächstes/#bearbeitung)

    func testLegacyEnglishTagsAreRecognizedWhenReading() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#next", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#progress", isCompleted: false), .inProgress)
    }

    func testLegacyShortGermanTagsAreRecognizedWhenReading() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#nächstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#naechstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#bearbeitung", isCompleted: false), .inProgress)
    }

    func testHasLegacyTag() {
        XCTAssertTrue(StatusTagger.hasLegacyTag("Notiz\n#progress"))
        XCTAssertTrue(StatusTagger.hasLegacyTag("Notiz\n#bearbeitung"))
        XCTAssertFalse(StatusTagger.hasLegacyTag("Notiz\n#inbearbeitung"))
        XCTAssertFalse(StatusTagger.hasLegacyTag(nil))
    }

    func testRewriteMigratesLegacyTagsToCurrentForm() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#progress", for: .inProgress), "Notiz\n#inbearbeitung")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#next", for: .next), "Notiz\n#alsnächstes")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#bearbeitung", for: .inProgress), "Notiz\n#inbearbeitung")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#nächstes", for: .next), "Notiz\n#alsnächstes")
    }

    func testLegacyAndCurrentTagLastOneWins() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#next\n#inbearbeitung", isCompleted: false), .inProgress)
    }
}
