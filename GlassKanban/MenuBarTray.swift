import Foundation

/// What the menu bar tray shows. Decisions only; the view draws them.
///
/// Separated from the view for the reason the rest of this project's rules
/// are (see CLAUDE.md): a decision inside a `body` cannot be tested, and
/// every one of these has a failure mode that is invisible on screen until
/// it is the wrong day.
enum MenuBarTray {
    /// Rows a lane shows at most. A WIP limit of 20 would otherwise give 20
    /// rows and hang the tray off the bottom of the screen. The count chip
    /// always tells the whole truth, so nothing is hidden — it is only not
    /// drawn (see SPEC.md, "Menüleiste").
    static let rowCap = 6

    /// The smallest a well ever gets. Below three rows the three wells stop
    /// reading as lanes and start reading as buttons.
    static let minimumRows = 3

    /// Whether the footer offers Quit: only when there is no Dock icon to
    /// quit from, and no board window that has to be open for the app menu
    /// to exist.
    static func offersQuit(_ presence: AppPresence) -> Bool { !presence.showsDockIcon }

    /// All three wells share one height: the fullest lane's rows, never
    /// fewer than three, never more than the cap.
    ///
    /// Wells that each hug their own content were rejected for the board
    /// ("Spalten enden mit dem Inhalt", BACKLOG.md "Explizit abgelehnt");
    /// the tray keeps the same posture, and a well that resized under the
    /// cursor mid-drag would be worse here than it was there.
    static func laneRows(next: Int, inProgress: Int, done: Int) -> Int {
        min(rowCap, max(minimumRows, next, inProgress, done))
    }

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
