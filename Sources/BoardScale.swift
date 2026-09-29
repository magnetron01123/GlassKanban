import SwiftUI

/// How large the board is drawn — for a board that is read from across the
/// room, not just from the chair in front of it.
///
/// Three steps rather than a slider: a step is something one can pick and
/// find again, and each one is checked on screen as a whole board — a slider
/// would promise every size in between without anyone having looked at them.
///
/// Scales the content only: lanes, cards, the opened card. The toolbar, the
/// menu bar panel, Settings, popovers and tooltips keep their size — they are
/// used up close, and a menu bar panel is measured against the system's own.
/// That is why the factor travels as an environment value set on the board
/// rather than by scaling the tokens themselves: the panel reads the same
/// tokens and would have grown with them.
enum BoardScale: String, CaseIterable, Identifiable {
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    var factor: CGFloat {
        switch self {
        case .standard: 1
        case .large: 1.2
        case .extraLarge: 1.4
        }
    }

    var displayName: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .large: String(localized: "Large")
        case .extraLarge: String(localized: "Extra Large")
        }
    }

    /// One step up or down, for ⌘+ and ⌘−. `nil` at either end: the
    /// shortcut then does nothing, which is what a Mac does at the edge of a
    /// zoom range — no beep, no notice.
    var larger: BoardScale? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    var smaller: BoardScale? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index > 0 else { return nil }
        return all[index - 1]
    }

    static let storageKey = StoredSetting.boardScale.key

    static var stored: BoardScale {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(BoardScale.init(rawValue:)) ?? .standard
    }

    /// The board's minimum width, capped at the width it actually has.
    ///
    /// Four lanes at their scaled minimum can be wider than a small screen —
    /// at 140 % they want ~1700 pt against a 13" MacBook's 1470. A window
    /// forced wider than its display hangs off the edge with its toolbar out
    /// of reach, so the lanes give way instead: narrower than they would
    /// like, the type still as large as chosen.
    static func fittedMinWidth(natural: CGFloat, available: CGFloat?) -> CGFloat {
        guard let available, available > 0 else { return natural }
        return min(natural, available)
    }
}

/// Owns the setting, like `AppearanceController`: the picker and the board
/// read one published value, so a change lands on the board at once without
/// the Settings window having to be open for it.
final class BoardScaleController: ObservableObject {
    static let shared = BoardScaleController()

    @Published var selection: BoardScale {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: BoardScale.storageKey)
        }
    }

    private init() {
        selection = BoardScale.stored
    }
}

extension EnvironmentValues {
    /// The board's size factor. 1 everywhere the board does not set it —
    /// which is what keeps the panel, Settings and the popovers at their own
    /// size while reading the same tokens.
    @Entry var boardScale: CGFloat = 1
}
