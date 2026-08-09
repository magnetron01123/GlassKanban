import Foundation

/// Which live recurring series must give their status tag back after an
/// occurrence was completed somewhere else.
///
/// Only this app removes the status tag before completing a card. Ticking the
/// box in Reminders.app, on iPhone, or in a shared list on someone else's
/// device completes the occurrence with the notes untouched: EventKit files
/// the finished turn away as a detached copy (new identifier, no recurrence
/// rule, tag still in its notes) and rolls the series on under the old
/// identifier — with `#next` still attached. Measured against real iCloud
/// (09.08.2026, weekly rule): both records kept the tag. The next turn of the
/// chore then sits in a working lane although nobody pulled it, and it comes
/// back every single cycle — the bug this type exists for.
///
/// The pull that tag once stood for was spent by the occurrence that got
/// finished. Releasing it is bookkeeping, not a move — which is why the
/// release is silent and not undoable: there is no user decision to give
/// back, and ⌘Z re-tagging work nobody pulled is exactly what
/// `RecurringHandoff` guards against on the replay side.
///
/// A tag is only released when it *provably* belongs to the finished turn.
/// All of these must hold, and any doubt fails toward keeping the tag — a tag
/// kept costs one drag, a pulled card silently pushed back to Backlog breaks
/// the pull principle:
///
/// 1. The series is open, recurring, and carries a status tag.
/// 2. The previous refresh saw the same tag on the same identifier — the tag
///    is older than this refresh, so nobody just pulled it.
/// 3. A completed reminder with the same title in the same list appeared
///    whose identifier was never fetched before — the fingerprint of a
///    freshly detached occurrence. An ordinary completion keeps its
///    identifier, so finishing a same-titled one-off task can not trigger
///    this.
/// 4. The user has not deliberately moved the series since the last refresh —
///    a pull made in the window between the completion syncing in and the
///    refresh seeing it stays a pull.
/// 5. Exactly one series matches the finished occurrence. Two same-titled
///    live series in one list make the match ambiguous, so nothing happens.
///
/// Known limit, accepted: a completion that happened while the app was closed
/// leaves no "previous refresh" to compare against (condition 2), so its tag
/// survives until the next completion or a manual drag. Guessing from
/// timestamps instead was already rejected once in this area — the roll-on
/// itself bumps `lastModifiedDate`, so there is nothing reliable to guess
/// from.
enum RecurringTagRelease {

    /// One fetched reminder, reduced to the values the rule reads. Built from
    /// `EKReminder` by the store; a plain value here so the rule stays
    /// testable without EventKit.
    struct Snapshot {
        let id: String
        let title: String
        let listID: String
        let isCompleted: Bool
        let isRecurring: Bool
        let status: KanbanStatus

        init(id: String, title: String, listID: String,
             isCompleted: Bool, isRecurring: Bool, status: KanbanStatus) {
            self.id = id
            self.title = title
            self.listID = listID
            self.isCompleted = isCompleted
            self.isRecurring = isRecurring
            self.status = status
        }
    }

    /// Identifiers of live series whose tag must be rewritten to Backlog.
    ///
    /// - Parameters:
    ///   - previousStatusByID: card status per identifier as the board showed
    ///     it before this refresh (condition 2).
    ///   - previouslySeenIDs: every identifier the previous refresh fetched,
    ///     completed ones included — wider than the board, which only keeps
    ///     recent Done cards (condition 3 must not mistake an old completion
    ///     scrolled into the fetch window for a fresh one).
    ///   - refreshed: the current fetch.
    ///   - deliberatelyMoved: identifiers the user moved themselves since the
    ///     last completed refresh (condition 4).
    static func releasedSeriesIDs(
        previousStatusByID: [String: KanbanStatus],
        previouslySeenIDs: Set<String>,
        refreshed: [Snapshot],
        deliberatelyMoved: Set<String>
    ) -> Set<String> {
        let freshOccurrences = refreshed.filter {
            $0.isCompleted && !$0.title.isEmpty && !previouslySeenIDs.contains($0.id)
        }
        var released: Set<String> = []
        for occurrence in freshOccurrences {
            let candidates = refreshed.filter {
                !$0.isCompleted
                    && $0.isRecurring
                    && ($0.status == .next || $0.status == .inProgress)
                    && $0.title == occurrence.title
                    && $0.listID == occurrence.listID
                    && $0.id != occurrence.id
            }
            guard candidates.count == 1, let series = candidates.first,
                  previousStatusByID[series.id] == series.status,
                  !deliberatelyMoved.contains(series.id)
            else { continue }
            released.insert(series.id)
        }
        return released
    }
}
