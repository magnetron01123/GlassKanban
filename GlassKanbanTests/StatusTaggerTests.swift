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
        XCTAssertEqual(StatusTagger.status(fromNotes: "Zeile eins\n#nächstes", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "mitten #nächstes im Text", isCompleted: false), .next)
    }

    func testNextTagAcceptsUmlautFreeSpelling() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#naechstes", isCompleted: false), .next)
    }

    func testProgressTag() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#bearbeitung", isCompleted: false), .inProgress)
    }

    func testTagIsCaseInsensitive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#NÄCHSTES", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#Bearbeitung", isCompleted: false), .inProgress)
    }

    func testWordBoundaryPreventsFalsePositive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#bearbeitungszeit notieren", isCompleted: false), .backlog)
    }

    func testCompletedAlwaysWinsOverTag() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#bearbeitung", isCompleted: true), .done)
    }

    func testLastTagWinsWhenMultiplePresent() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#nächstes dann #bearbeitung", isCompleted: false), .inProgress)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#bearbeitung\n#nächstes", isCompleted: false), .next)
    }

    func testTagCount() {
        XCTAssertEqual(StatusTagger.tagCount(nil), 0)
        XCTAssertEqual(StatusTagger.tagCount("nichts"), 0)
        XCTAssertEqual(StatusTagger.tagCount("#nächstes"), 1)
        XCTAssertEqual(StatusTagger.tagCount("#nächstes #bearbeitung #NAECHSTES"), 3)
    }

    // MARK: - Writing

    func testRewriteAppendsTagAsOwnLastLine() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz", for: .next), "Meine Notiz\n#nächstes")
    }

    func testRewriteReplacesExistingTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#nächstes", for: .inProgress), "Meine Notiz\n#bearbeitung")
    }

    func testRewriteNormalizesUmlautFreeSpelling() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#naechstes", for: .next), "Meine Notiz\n#nächstes")
    }

    func testRewriteToBacklogRemovesTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#bearbeitung", for: .backlog), "Meine Notiz")
    }

    func testRewriteToDoneRemovesTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#nächstes", for: .done), "Meine Notiz")
    }

    func testRewriteTagOnlyNotesToBacklogBecomesNil() {
        XCTAssertNil(StatusTagger.rewrittenNotes("#nächstes", for: .backlog))
    }

    func testRewriteNilNotesToNext() {
        XCTAssertEqual(StatusTagger.rewrittenNotes(nil, for: .next), "#nächstes")
    }

    func testRewriteRemovesAllTagsBeforeAppending() {
        XCTAssertEqual(
            StatusTagger.rewrittenNotes("#nächstes Text #bearbeitung", for: .next),
            "Text\n#nächstes")
    }

    func testRewritePreservesUserTextExactly() {
        let notes = "Zeile 1\nZeile 2 mit Inhalt"
        XCTAssertEqual(StatusTagger.rewrittenNotes(notes, for: .backlog), notes)
    }

    // MARK: - Legacy tag migration (#next/#progress from earlier builds)

    func testLegacyTagsAreRecognizedWhenReading() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#next", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#progress", isCompleted: false), .inProgress)
    }

    func testHasLegacyTag() {
        XCTAssertTrue(StatusTagger.hasLegacyTag("Notiz\n#progress"))
        XCTAssertFalse(StatusTagger.hasLegacyTag("Notiz\n#bearbeitung"))
        XCTAssertFalse(StatusTagger.hasLegacyTag(nil))
    }

    func testRewriteMigratesLegacyTagToGerman() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#progress", for: .inProgress), "Notiz\n#bearbeitung")
        XCTAssertEqual(StatusTagger.rewrittenNotes("Notiz\n#next", for: .next), "Notiz\n#nächstes")
    }

    func testLegacyAndGermanTagLastOneWins() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#next\n#bearbeitung", isCompleted: false), .inProgress)
    }
}
