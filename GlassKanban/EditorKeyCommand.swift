import Foundation

/// What a key press inside the opened card means.
///
/// Pulled out of the view for the same reason `TicketRename` was: this is a
/// place where a key can destroy what was typed. Escape throws a whole edit
/// away, and Return ends one — which of the two keys belongs to the card and
/// which belongs to the field being typed in is a rule worth stating in the
/// open, and testing, rather than leaving it to be read out of an AppKit
/// event handler.
///
/// The rule, in one line: **Return übernimmt, Escape verwirft** — the same
/// words the board's inline rename already uses, so one vocabulary covers
/// both ways of editing a title.
enum EditorKeyCommand: Equatable {
    /// Return: close the card, keeping what is written. The same answer a
    /// click on the board behind it gives.
    case commit
    /// Escape: close the card, throwing the edit away.
    case cancel
    /// Not the card's key — it travels on to whatever is being typed in.
    case passThrough

    // Virtual key codes, which are layout-independent: these three physical
    // keys carry the same meaning on every keyboard, unlike the characters a
    // layout maps onto them.
    static let escapeKeyCode: UInt16 = 53
    static let returnKeyCode: UInt16 = 36
    /// The numeric keypad's own Enter. Nobody means anything different by it.
    static let keypadEnterKeyCode: UInt16 = 76

    /// - Parameters:
    ///   - isEditingMultilineText: true while the notes field has the cursor.
    ///     Return belongs to it: a note is a list more often than it is a
    ///     sentence, and a list needs line breaks. The one-line fields have
    ///     no such claim — a Return typed in a title cannot mean anything but
    ///     "done".
    ///   - holdsCommand: ⌘Return closes the card from the notes field too,
    ///     the standard way out of a multi-line field on this platform.
    static func forKey(
        code: UInt16,
        holdsCommand: Bool = false,
        isEditingMultilineText: Bool = false
    ) -> EditorKeyCommand {
        switch code {
        case escapeKeyCode:
            // Escape is never handed on: a note being typed has nothing to
            // abort — the whole card is what is being cancelled.
            .cancel
        case returnKeyCode, keypadEnterKeyCode:
            isEditingMultilineText && !holdsCommand ? .passThrough : .commit
        default:
            .passThrough
        }
    }
}
