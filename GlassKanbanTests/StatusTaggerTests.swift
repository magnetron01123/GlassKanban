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
        XCTAssertEqual(StatusTagger.status(fromNotes: "#progress", isCompleted: false), .inProgress)
    }

    func testTagIsCaseInsensitive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#NEXT", isCompleted: false), .next)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#Progress", isCompleted: false), .inProgress)
    }

    func testWordBoundaryPreventsFalsePositive() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#nextlevel Plan", isCompleted: false), .backlog)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#progressive Idee", isCompleted: false), .backlog)
    }

    func testCompletedAlwaysWinsOverTag() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#progress", isCompleted: true), .done)
    }

    func testLastTagWinsWhenMultiplePresent() {
        XCTAssertEqual(StatusTagger.status(fromNotes: "#next dann #progress", isCompleted: false), .inProgress)
        XCTAssertEqual(StatusTagger.status(fromNotes: "#progress\n#next", isCompleted: false), .next)
    }

    func testTagCount() {
        XCTAssertEqual(StatusTagger.tagCount(nil), 0)
        XCTAssertEqual(StatusTagger.tagCount("nichts"), 0)
        XCTAssertEqual(StatusTagger.tagCount("#next"), 1)
        XCTAssertEqual(StatusTagger.tagCount("#next #progress #NEXT"), 3)
    }

    // MARK: - Writing

    func testRewriteAppendsTagAsOwnLastLine() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz", for: .next), "Meine Notiz\n#next")
    }

    func testRewriteReplacesExistingTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#next", for: .inProgress), "Meine Notiz\n#progress")
    }

    func testRewriteToBacklogRemovesTag() {
        XCTAssertEqual(StatusTagger.rewrittenNotes("Meine Notiz\n#progress", for: .backlog), "Meine Notiz")
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
            StatusTagger.rewrittenNotes("#next Text #progress", for: .next),
            "Text\n#next")
    }

    func testRewritePreservesUserTextExactly() {
        let notes = "Zeile 1\nZeile 2 mit Inhalt"
        XCTAssertEqual(StatusTagger.rewrittenNotes(notes, for: .backlog), notes)
    }
}
