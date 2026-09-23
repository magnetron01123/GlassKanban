import Foundation

/// A global key combination for opening the menu bar panel, as the user
/// recorded it.
///
/// Pure on purpose (CLAUDE.md, "Muster für neue Logik"): what counts as a
/// usable combination, how it is written down and how it reads back are three
/// decisions with quiet failure modes — a shortcut that stores wrong is a
/// setting that silently resets on the next launch, and one that validates
/// wrong swallows a letter in every app the user owns.
///
/// **Why the key's label travels with it.** The registration is by *key code*,
/// which is a position on the keyboard, not a letter: `kVK_ANSI_Y` is the key
/// that types "Z" on a German layout. Deriving a label from the code would
/// therefore show the wrong letter on exactly this project's keyboard. The
/// label recorded here is the character the user saw themselves press
/// (`NSEvent.charactersIgnoringModifiers`), so what the settings pane shows is
/// what happened.
struct TrayShortcut: Equatable, Codable {

    struct Modifiers: OptionSet, Equatable, Codable {
        let rawValue: Int
        static let control = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let shift = Modifiers(rawValue: 1 << 2)
        static let command = Modifiers(rawValue: 1 << 3)

        /// The ones that make a combination global. ⇧ alone does not: ⇧K is
        /// a capital K, and registering it would take that letter away from
        /// every text field on the Mac.
        static let carrying: Modifiers = [.control, .option, .command]
    }

    /// The physical key, in the virtual key codes `RegisterEventHotKey` uses.
    let keyCode: UInt16
    let modifiers: Modifiers
    /// What that key types on the layout it was recorded on, upper-cased —
    /// display only, never part of the registration.
    let label: String

    /// At least one of ⌃⌥⌘. Checked before anything is registered: an
    /// invalid combination is not stored, so it can never come back from
    /// `UserDefaults` either.
    var isValid: Bool {
        !modifiers.isDisjoint(with: .carrying) && !label.isEmpty
    }

    /// The modifier signs in the order every macOS menu prints them, so the
    /// pane reads like the rest of the system rather than like this app.
    var modifierGlyphs: String {
        var glyphs = ""
        if modifiers.contains(.control) { glyphs += "⌃" }
        if modifiers.contains(.option) { glyphs += "⌥" }
        if modifiers.contains(.shift) { glyphs += "⇧" }
        if modifiers.contains(.command) { glyphs += "⌘" }
        return glyphs
    }

    var displayString: String { modifierGlyphs + label }

    // MARK: - Written down

    /// `"ctrl+opt+shift+cmd|40|K"` — modifiers, key code, label. Plain text
    /// rather than encoded data so that a person reading the plist with
    /// `plutil -p` can see what is set (CLAUDE.md: the plist is this
    /// project's one reliable diagnostic).
    var stored: String {
        var tokens: [String] = []
        if modifiers.contains(.control) { tokens.append("ctrl") }
        if modifiers.contains(.option) { tokens.append("opt") }
        if modifiers.contains(.shift) { tokens.append("shift") }
        if modifiers.contains(.command) { tokens.append("cmd") }
        return "\(tokens.joined(separator: "+"))|\(keyCode)|\(label)"
    }

    /// Anything unreadable is no shortcut at all. Never a guess and never a
    /// default: a stored value this version cannot understand must leave the
    /// user with nothing registered, not with some other key combination they
    /// never chose.
    static func parse(_ stored: String) -> TrayShortcut? {
        // Split from the left only, so a label that *is* a pipe survives.
        let parts = stored.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let keyCode = UInt16(parts[1]) else { return nil }
        var modifiers: Modifiers = []
        for token in parts[0].split(separator: "+") where !token.isEmpty {
            switch token {
            case "ctrl": modifiers.insert(.control)
            case "opt": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "cmd": modifiers.insert(.command)
            default: return nil
            }
        }
        let shortcut = TrayShortcut(
            keyCode: keyCode, modifiers: modifiers, label: String(parts[2]))
        guard shortcut.isValid else { return nil }
        return shortcut
    }
}
