import Foundation

/// Which live recurring series carry a status tag their finished turn has
/// already spent — and must therefore give it back.
///
/// Only this app removes the status tag before completing a card. Ticking the
/// box in Reminders.app, on iPhone, or in a shared list on someone else's
/// device completes the occurrence with the notes untouched: EventKit files
/// the finished turn away as a detached copy (new identifier, no recurrence
/// rule, tag still in its notes) and rolls the series on under the old
/// identifier — with `#next` still attached. Measured against real iCloud
/// (09.08.2026, weekly rule): both records kept the tag. The next turn of the
/// chore then sits in a working lane although nobody pulled it.
///
/// Until 13.08.2026 this rule was an *edge*: it fired only in the one refresh
/// that first saw the freshly detached completion, and only if the tag was
/// already on the series in that same refresh. That shape lost a real card
/// ("Einkaufen", measured 12.–13.08.2026): the occurrence was completed in
/// the app at 22:40 — tag cleanly stripped — and at 22:49 a stale writer (a
/// calendar client pushing back cached copies every 19–55 minutes) restored
/// `#next` onto the rolled-on series. The app never saw the clean state
/// between the two writes, the completion's identifier counted as "seen" from
/// then on, and no mechanism ever asked the question again. The unpulled next
/// turn sat in "Als Nächstes" indefinitely.
///
/// So the rule is now a *standing condition*, re-checked on every refresh:
///
/// > **A series whose newest finished turn was completed after the last pull
/// > of that series on this board carries a spent tag. It is released to
/// > Backlog — however late the tag arrives, and as often as something puts
/// > it back.**
///
/// "The last pull on this board" is a small persisted ledger (`Memory`):
/// every move of a series into a working lane records the moment. It is
/// stamped no earlier than the newest completion the board can already see,
/// so a completion that synced in *before* the pull can never outrank it —
/// that also absorbs modest clock skew between the completing device and
/// this Mac in the one direction that matters.
///
/// A tag is only released when the evidence is exact, and any doubt fails
/// toward keeping the tag — a tag kept costs one drag, a pulled card silently
/// pushed back to Backlog breaks the pull principle:
///
/// 1. The series is open, recurring, and carries a working-lane tag.
/// 2. A completed reminder in the same list carries the series' creation date
///    bit for bit (`RecurringSeriesMatch`) — the identity of a detached
///    occurrence, measured 10.08.2026. Matching on the title instead let a
///    same-titled task created and completed on another device take the tag
///    off a card somebody had pulled.
/// 3. Exactly one live series of that list carries that creation date.
///    Anything ambiguous means no proof, so nothing happens.
/// 4. The newest such completion is younger than the last recorded pull of
///    the series — and younger than `Memory.activeSince`, the first run of
///    this rule. Completions from before the rule existed are not evidence:
///    the pulls they would be weighed against were never recorded, and
///    judging them would demote every legitimately pulled recurring card
///    once, board-wide, on upgrade.
/// 5. The user has not deliberately moved the series since the last refresh —
///    a pull made in the window between the completion syncing in and the
///    refresh seeing it stays a pull.
///
/// Because the condition stands rather than fires, it needs no memory of
/// which identifiers were fetched before — a cold start, a sleep gap, or a
/// stale writer restoring the tag hours later all land in the same check.
/// The write it produces is paced by the store (one answer per card per
/// correction cooldown), so a writer that keeps restoring the tag is
/// answered calmly, not fought.
///
/// Remaining limits, accepted and documented in SPEC.md: a tag typed onto
/// the series by hand on another device after a completion is
/// indistinguishable from a stale restoration and is released — repeatedly,
/// while the condition holds (it takes hashtag handwork away from this Mac,
/// and one drag on this board ends it). And on a shared list, a pull made by
/// *another* instance of this app would be read as foreign; pulls live on
/// the board they were made on.
enum RecurringTagRelease {

    /// What the standing rule remembers across refreshes and launches: when
    /// each series was last pulled on this board, and since when the rule has
    /// been active at all.
    ///
    /// One defaults key holding both halves. Reading tolerates anything — a
    /// missing key, foreign types, the pre-13.08 payload (which stored seen
    /// identifiers instead) — by dropping what it cannot vouch for. A missing
    /// `activeSince` means the rule starts counting from now, which is the
    /// upgrade path: nothing that happened before this build is evidence.
    struct Memory: Equatable {
        private(set) var lastPullByID: [String: Date]
        let activeSince: Date

        /// How many pulls are kept, oldest dropped first. Far above any real
        /// board's set of recurring series, and a hard bound on a dictionary
        /// that lives in UserDefaults.
        static let maxPulls = 200

        init(lastPullByID: [String: Date] = [:], activeSince: Date) {
            self.lastPullByID = lastPullByID
            self.activeSince = activeSince
        }

        /// Records a pull, stamped no earlier than one second past the newest
        /// completion already visible — see the type comment for why the pull
        /// must outrank everything the board could already see.
        mutating func recordPull(seriesID: String, at now: Date, newestVisibleCompletion: Date?) {
            var stamp = now
            if let visible = newestVisibleCompletion, visible >= stamp {
                stamp = visible.addingTimeInterval(1)
            }
            lastPullByID[seriesID] = stamp
            if lastPullByID.count > Self.maxPulls {
                let oldestFirst = lastPullByID.sorted { $0.value < $1.value }
                for stale in oldestFirst.prefix(lastPullByID.count - Self.maxPulls) {
                    lastPullByID.removeValue(forKey: stale.key)
                }
            }
        }

        static let storageKey = "tagReleaseMemory"

        static func load(from defaults: UserDefaults = .standard, now: Date = .now) -> Memory {
            let stored = defaults.dictionary(forKey: storageKey)
            let pulls = (stored?["pulls"] as? [String: Double] ?? [:])
                .mapValues(Date.init(timeIntervalSince1970:))
            let active = (stored?["activeSince"] as? Double)
                .map(Date.init(timeIntervalSince1970:)) ?? now
            return Memory(lastPullByID: pulls, activeSince: active)
        }

        func save(to defaults: UserDefaults = .standard) {
            defaults.set(
                [
                    "pulls": lastPullByID.mapValues(\.timeIntervalSince1970),
                    "activeSince": activeSince.timeIntervalSince1970,
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
        /// What says which series a finished turn came from — see
        /// `RecurringSeriesMatch`. The title stays on the snapshot, but only
        /// to skip abandoned untitled placeholders; it does not decide
        /// identity.
        let createdAt: Date?
        /// When a finished turn was completed — the fact the standing rule
        /// weighs against the last pull.
        let completedAt: Date?

        init(id: String, title: String, listID: String,
             isCompleted: Bool, isRecurring: Bool, status: KanbanStatus,
             createdAt: Date? = nil, completedAt: Date? = nil) {
            self.id = id
            self.title = title
            self.listID = listID
            self.isCompleted = isCompleted
            self.isRecurring = isRecurring
            self.status = status
            self.createdAt = createdAt
            self.completedAt = completedAt
        }

        var matchRecord: RecurringSeriesMatch.Record {
            RecurringSeriesMatch.Record(
                id: id, listID: listID, createdAt: createdAt,
                isCompleted: isCompleted, isRecurring: isRecurring)
        }
    }

    /// Identifiers of live series whose tag must be rewritten to Backlog —
    /// the standing condition, evaluated against the current fetch.
    static func releasedSeriesIDs(
        refreshed: [Snapshot],
        memory: Memory,
        deliberatelyMoved: Set<String>
    ) -> Set<String> {
        let records = refreshed.map(\.matchRecord)
        var released: Set<String> = []
        for series in refreshed {
            guard !series.isCompleted, series.isRecurring,
                  series.status == .next || series.status == .inProgress,
                  !deliberatelyMoved.contains(series.id)
            else { continue }
            let newest = newestCompletion(ofSeries: series, refreshed: refreshed, records: records)
            guard let completedAt = newest,
                  completedAt > memory.activeSince,
                  completedAt > (memory.lastPullByID[series.id] ?? .distantPast)
            else { continue }
            released.insert(series.id)
        }
        return released
    }

    /// The newest completion that provably belongs to this series — via the
    /// creation-date identity, with the same uniqueness demand as everywhere
    /// else (`RecurringSeriesMatch.seriesID` answers nil on any ambiguity,
    /// which reads as "no proof" here too). Untitled completions are skipped:
    /// an abandoned placeholder is not evidence about anybody's pull.
    private static func newestCompletion(
        ofSeries series: Snapshot,
        refreshed: [Snapshot],
        records: [RecurringSeriesMatch.Record]
    ) -> Date? {
        refreshed
            .filter { occurrence in
                occurrence.isCompleted
                    && !occurrence.title.isEmpty
                    && occurrence.completedAt != nil
                    && RecurringSeriesMatch.seriesID(
                        of: occurrence.matchRecord, among: records) == series.id
            }
            .compactMap(\.completedAt)
            .max()
    }
}
