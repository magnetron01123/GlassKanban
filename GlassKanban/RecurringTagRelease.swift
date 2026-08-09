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
/// A completion that happens while the app is closed is covered by `Memory`:
/// the end of every refresh persists what condition 2 and 3 need — which
/// identifiers were fetched, which cards carried a tag — and the first
/// refresh after a cold start is seeded from it. The rule itself never
/// changes; only its memory survives the restart. Guessing from timestamps
/// instead was rejected — the roll-on itself bumps `lastModifiedDate`, so
/// there is nothing reliable to guess from; a missing or stale memory simply
/// keeps the tag.
///
/// Remaining limit, accepted: a tag typed onto the series by hand on another
/// device *after* an external completion, while the app is closed, is
/// indistinguishable from a tag that merely survived — it is released. Rare
/// (it takes hand-editing the hashtag away from this Mac) and self-healing
/// with one drag.
enum RecurringTagRelease {

    /// What the release rule remembers between refreshes, persisted so a
    /// completion during downtime still meets its proof after a cold start.
    ///
    /// One defaults key holding both halves: they are a single proof and must
    /// not drift apart. Reading tolerates anything — a missing key, foreign
    /// types, a status raw value from a build that renamed a case — by
    /// dropping what it cannot vouch for; an empty memory just means the
    /// first session behaves like the app always did before it existed.
    struct Memory: Equatable {
        let seenIDs: Set<String>
        let taggedStatusByID: [String: KanbanStatus]

        /// Only working-lane tags are proof material (condition 2 never asks
        /// about anything else); enforcing that here keeps every persisted
        /// entry meaningful regardless of what the caller passes.
        init(seenIDs: Set<String>, taggedStatusByID: [String: KanbanStatus]) {
            self.seenIDs = seenIDs
            self.taggedStatusByID = taggedStatusByID.filter {
                $0.value == .next || $0.value == .inProgress
            }
        }

        static let storageKey = "tagReleaseMemory"

        static func load(from defaults: UserDefaults = .standard) -> Memory {
            let stored = defaults.dictionary(forKey: storageKey)
            let seen = stored?["seen"] as? [String] ?? []
            let tagged = (stored?["tagged"] as? [String: String] ?? [:])
                .compactMapValues(KanbanStatus.init(rawValue:))
            return Memory(seenIDs: Set(seen), taggedStatusByID: tagged)
        }

        func save(to defaults: UserDefaults = .standard) {
            defaults.set(
                [
                    "seen": Array(seenIDs),
                    "tagged": taggedStatusByID.mapValues(\.rawValue),
                ] as [String: Any],
                forKey: Self.storageKey)
        }
    }

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
