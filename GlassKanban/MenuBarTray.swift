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

    /// Erledigt shows less: the tray is for finishing, and the finished need
    /// only be a short confirmation of it — the last few, not the week. Three
    /// is the small, safe reward; six was a list.
    static let doneRowCap = 3

    /// The Backlog's resting cap. Eight rather than the board's fifteen,
    /// because the panel has a fraction of the height — the same kind of
    /// difference as Erledigt's three rows against the board's seven days.
    static let backlogRowCap = 8

    static func rowCap(for status: KanbanStatus) -> Int {
        switch status {
        case .backlog: backlogRowCap
        case .done: doneRowCap
        case .next, .inProgress: rowCap
        }
    }

    /// The rows a section shows at rest — the board's own fold rules, at
    /// the panel's caps. The Backlog cuts exactly as `BacklogFold` does
    /// (not-yet-due first, then the cap), so a card resting behind the fold
    /// on the board rests behind it here too; every other section is simply
    /// its first rows. What is not at rest is never gone: the line under the
    /// pile brings it in, with the board's words (12.09.2026, user:
    /// consistency between panel and app over a fold of the panel's own).
    static func restingRows(
        _ cards: [KanbanCard],
        in status: KanbanStatus,
        foldsNotYetDue: Bool,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [KanbanCard] {
        switch status {
        case .backlog:
            BacklogFold.restingCut(
                cards, limit: backlogRowCap, foldsNotYetDue: foldsNotYetDue,
                calendar: calendar, now: now)
        case .next, .inProgress, .done:
            Array(cards.prefix(rowCap(for: status)))
        }
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

    /// Which rows say how long they have been sitting: only "In
    /// Bearbeitung", and only from the board's own threshold on.
    ///
    /// The panel is for finishing, and "this has been started for five days"
    /// is the one fact that helps with that. On the other sections the same
    /// number would be a figure without a question behind it: a Backlog item
    /// is *supposed* to lie there, and a finished one is done. Below the
    /// threshold nothing is said at all — a number that appears the moment a
    /// card is pulled would be a stopwatch, and this app does not run one
    /// (CONCEPT.md, "Belohnen, nie bestrafen").
    static func showsDwellTime(status: KanbanStatus, days: Int?) -> Bool {
        guard status == .inProgress, let days else { return false }
        return days >= KanbanCard.agingThresholdDays
    }

    /// Every row may move, Erledigt included (12.09.2026, user).
    ///
    /// It was barred until then, for a real reason: a move out of Erledigt is
    /// the one move that can be refused outright — a repeating series that has
    /// already rolled on cannot take its finished occurrence back — and the
    /// answer to that, "Nicht wiederhergestellt", was a board alert the panel
    /// could not raise. So the failure would have been silent, which is the
    /// one thing this project never does. The bar is lifted now that the panel
    /// says it itself: `SaveFailure` carries its `MoveSource` and the panel
    /// shows the refusal inline (`TrayNoticeRow`). Pulling finished work back
    /// out is a Kanban move like any other, and refusing it here while the
    /// board allows it was the panel disagreeing with the app.
    static func allowsMoving(from status: KanbanStatus) -> Bool { true }
}
