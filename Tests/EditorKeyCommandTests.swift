import XCTest

/// The opened card has no Sichern/Abbrechen buttons, so these two keys *are*
/// its two answers — and one of them destroys an edit. What each key means,
/// stated once here rather than inferred from an event handler.
final class EditorKeyCommandTests: XCTestCase {

    func testReturnCommits() {
        XCTAssertEqual(EditorKeyCommand.forKey(code: EditorKeyCommand.returnKeyCode), .commit)
    }

    /// The keypad's Enter is the same key as far as a card is concerned.
    func testKeypadEnterCommits() {
        XCTAssertEqual(EditorKeyCommand.forKey(code: EditorKeyCommand.keypadEnterKeyCode), .commit)
    }

    func testEscapeCancels() {
        XCTAssertEqual(EditorKeyCommand.forKey(code: EditorKeyCommand.escapeKeyCode), .cancel)
    }

    /// Escape is never handed to the field being typed in: there is no
    /// half-cancel here, the whole card is what is being thrown away.
    func testEscapeCancelsFromTheNotesFieldToo() {
        XCTAssertEqual(
            EditorKeyCommand.forKey(code: EditorKeyCommand.escapeKeyCode, isEditingMultilineText: true),
            .cancel)
    }

    /// The reason this rule exists: notes are lists more often than prose, and
    /// a Return typed into them has to break the line rather than close the
    /// card out from under the list being written.
    func testReturnInNotesBreaksTheLineInsteadOfClosing() {
        XCTAssertEqual(
            EditorKeyCommand.forKey(code: EditorKeyCommand.returnKeyCode, isEditingMultilineText: true),
            .passThrough)
    }

    /// ⌘Return is the platform's way out of a multi-line field, so it still
    /// closes the card from inside the notes.
    func testCommandReturnCommitsFromTheNotesField() {
        XCTAssertEqual(
            EditorKeyCommand.forKey(
                code: EditorKeyCommand.returnKeyCode,
                holdsCommand: true,
                isEditingMultilineText: true),
            .commit)
    }

    /// A one-line field has no claim on Return — a Return typed in a title
    /// cannot mean anything but "done".
    func testReturnInAOneLineFieldCommits() {
        XCTAssertEqual(
            EditorKeyCommand.forKey(code: EditorKeyCommand.returnKeyCode, isEditingMultilineText: false),
            .commit)
    }

    /// Everything else belongs to the field, not the card — a monitor that
    /// swallowed more than its two keys would silently stop typing from
    /// arriving.
    func testEveryOtherKeyIsLeftAlone() {
        let letterA: UInt16 = 0
        let space: UInt16 = 49
        let tab: UInt16 = 48
        for code in [letterA, space, tab] {
            XCTAssertEqual(EditorKeyCommand.forKey(code: code), .passThrough)
            XCTAssertEqual(
                EditorKeyCommand.forKey(code: code, holdsCommand: true, isEditingMultilineText: true),
                .passThrough)
        }
    }
}
