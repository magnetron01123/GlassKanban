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
