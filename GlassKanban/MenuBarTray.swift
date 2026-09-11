import Foundation

/// What the menu bar tray shows. Decisions only; the view draws them.
///
/// Separated from the view for the reason the rest of this project's rules
/// are (see CLAUDE.md): a decision inside a `body` cannot be tested, and
/// every one of these has a failure mode that is invisible on screen until
/// it is the wrong day.
enum MenuBarTray {
    /// Rows a section shows at most. Three sections of twenty rows would
    /// hang the tray off the bottom of the screen. The count in the head
    /// always tells the whole truth and the last row names the rest, so
    /// nothing is hidden — it is only not drawn (see SPEC.md, "Menüleiste").
    static let rowCap = 6

    /// How many rows of a section the cap keeps out — the number the last
    /// row names, so nothing is hidden without being counted.
    static func hiddenRows(total: Int) -> Int {
        max(0, total - rowCap)
    }

    /// Whether the footer offers Quit: only when there is no Dock icon to
    /// quit from, and no board window that has to be open for the app menu
    /// to exist.
    static func offersQuit(_ presence: AppPresence) -> Bool { !presence.showsDockIcon }

    /// While the tray's own WIP question stands, nothing else in the tray
    /// moves — a second drag would overwrite the first question unanswered,
    /// which is silently allowing what the user was asked about.
    static func allowsMoves(pendingSource: MoveSource?) -> Bool {
        pendingSource != .tray
    }

    /// Cards in Erledigt cannot be moved from the tray at all.
    ///
    /// Not a matter of taste: a move out of Erledigt can fail on a recurring
    /// series, and the app answers that with the "Not Restored" notice —
    /// which only the board puts up. In the tray the move would fail in
    /// silence, which is the one thing this project never does.
    static func allowsMoving(from status: KanbanStatus) -> Bool {
        status != .done
    }
}
