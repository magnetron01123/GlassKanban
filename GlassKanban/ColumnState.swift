import Foundation
import os

/// Which working lane each card was pulled into, and when — the board's own
/// record, in the board's own storage.
///
/// Until 13.08.2026 the column lived as a hashtag in the reminder's notes.
/// That put the one thing this board is *for* into a field every program with
/// Reminders access may rewrite, and it cost a measured card: a stale calendar
/// client pushed `#next` back onto a series nine minutes after the occurrence
/// had been completed in the app, and the next turn — which nobody had pulled
/// — sat in a working lane. The board could recognise that pattern and answer
/// it (see `CorrectionLedger`), but recognition is not prevention. A column
/// nobody else can reach cannot be moved by anybody else. That is the whole
/// reason this type exists.
///
/// **What is stored, and what deliberately is not.**
///
/// - Only `next` and `inProgress`. Backlog is the absence of an entry, exactly
///   as it was the absence of a tag — and `pull(_:into:)` enforces that by
///   turning a pull into Backlog into a removal, so the format cannot express
///   two different things that mean the same column.
/// - Completion is never stored. It belongs to EventKit's `isCompleted`, where
///   Reminders, the phone, the widgets and this board's statistics all read
///   it. A second truth for "finished" would drift from the one everybody
///   else can see.
/// - `at` is when the card entered its lane. The tag form had no such field
///   and approximated the dwell time with EventKit's `lastModifiedDate`, which
///   any content edit — and any foreign writer — reset. Storing the moment
///   makes it exact instead.
///
/// **Identity is `EKReminder.calendarItemIdentifier`.** If that identifier
/// breaks — a resync, a list change — the entry is orphaned and the card falls
/// to Backlog. That is the safe direction this board picks everywhere: a lost
/// pull costs one drag, an invented one breaks the pull principle. Identity by
/// content (title, creation date) was considered and rejected for exactly that
/// reason: it can attach a pull to the *wrong* card, which is the one movement
/// this whole change exists to make impossible.
struct ColumnState: Equatable {

    /// A lane a card can be pulled into. Deliberately not `KanbanStatus`: that
    /// type has `.backlog` and `.done` cases, and a storage format able to
    /// express them is one somebody will eventually write them into.
    ///
    /// The raw values are a persisted contract, exactly like `wipLimits`:
    /// renaming a case silently sends every pulled card back to Backlog.
    /// Pinned by test.
    enum Lane: String, CaseIterable {
        case next, inProgress

        /// The lane a column corresponds to, or nil for the two columns this
        /// format deliberately cannot hold: Backlog is the absence of an
        /// entry, and completion belongs to EventKit.
        init?(_ status: KanbanStatus) {
            switch status {
            case .next: self = .next
            case .inProgress: self = .inProgress
            case .backlog, .done: return nil
            }
        }

        var status: KanbanStatus {
            switch self {
            case .next: .next
            case .inProgress: .inProgress
            }
        }
    }

    struct Pull: Equatable {
        var lane: Lane
        /// When this lane was entered — what the dwell time counts from.
        var at: Date
    }

    /// How many pulls are kept at all, oldest first. Far above any real
    /// board's working set (the WIP limit keeps the lanes at a handful) and a
    /// hard bound on the file.
    ///
    /// Deliberately the *only* limit. There is no expiry by age: a card may
    /// legitimately sit in "Als Nächstes" for half a year, and any age limit
    /// would quietly push it back to Backlog — the forbidden direction. There
    /// is equally no pruning against the current fetch, for the reason
    /// `CorrectionLedger.retain` gives: a list switched off in Settings, an
    /// account that is briefly offline or a sync hiccup all remove identifiers
    /// temporarily, and dropping the pull for that would be the board
    /// forgetting work the user placed. An orphaned entry is inert and costs
    /// about sixty bytes.
    static let maxPulls = 200

    /// How long a release stays on record before the plain absence of an entry
    /// means Backlog again.
    ///
    /// It only has to outlive the staleness of the *other* device's copy: a
    /// Mac that has been off for a month and comes back carrying a pull older
    /// than this may revive that card once, costing one drag. Long enough that
    /// a holiday does not do it, short enough that the file stays small.
    static let releaseRetention: TimeInterval = 30 * 24 * 60 * 60

    private(set) var pulls: [String: Pull]

    /// Which lists have had their old hashtags read into this state, and when.
    ///
    /// Per *list*, not per installation: a single "migration done" flag would
    /// be set after the first refresh, and that refresh does not see
    /// everything — a list switched off in Settings, an account that syncs in
    /// minutes later, a machine that starts offline. Their tags would be lost
    /// for good. Stamped per list, each one is imported when it first appears,
    /// whenever that is. The set is small by nature (lists, not cards).
    ///
    /// Kept in this file rather than in UserDefaults so that the mark and what
    /// it describes are written in the same atomic operation. Separated, a
    /// restored defaults file could claim an import that this state never got.
    private(set) var importedLists: [String: Date]

    /// Exactly which records still carry an old status tag that the migration
    /// has to cut out — recorded when their list was imported, and removed
    /// again as each one is cleaned.
    ///
    /// **This list is what makes the cleanup a migration rather than a
    /// standing rule**, and it exists because the standing version was
    /// measured destroying a user's text (14.08.2026, in the app): typing
    /// "Notiz mit #inprogress darin" into a note and closing the editor left
    /// "Notiz mit darin" — the cleanup could not tell a tag left over from the
    /// old form from a word somebody had just written. Naming the records up
    /// front removes the ambiguity entirely: anything not on this list is the
    /// user's text, whatever it looks like.
    ///
    /// Empty means the migration is done and no note will ever be cut again.
    private(set) var pendingTagCleanup: Set<String>

    /// When a card was last sent *back* to Backlog, for cards this board once
    /// pulled. Deliberately a separate field from `pulls`, and deliberately
    /// invisible to `lane(of:)`.
    ///
    /// **Why this exists at all.** Merging two machines' states means asking,
    /// per card, which side knows the newer truth — and that needs a date on
    /// both answers. A pull carries one; releasing a card is the *absence* of
    /// an entry and carries none. Without a dated release, a stale pull from
    /// the other Mac would always look like the only real answer and would
    /// revive a card the user had put down. That is the forbidden direction:
    /// a card appearing in a working lane nobody pulled.
    ///
    /// **Why not simply store `.backlog` in `pulls`.** Because `Lane` cannot
    /// express it, on purpose: a format able to write Backlog into a pull is
    /// one somebody eventually writes it into, and then two different shapes
    /// mean the same column. That invariant is worth more than the
    /// convenience, so the release date lives beside the pulls rather than
    /// among them — a transport note, not a column. Nothing reading a column
    /// ever consults it.
    ///
    /// Entries expire (`releaseRetention`): once no other device can still be
    /// holding a pull older than the release, the absence speaks for itself
    /// again, which is exactly what it meant before this field existed.
    private(set) var released: [String: Date]

    init(pulls: [String: Pull] = [:], importedLists: [String: Date] = [:],
         pendingTagCleanup: Set<String> = [], released: [String: Date] = [:]) {
        self.pulls = pulls
        self.importedLists = importedLists
        self.pendingTagCleanup = pendingTagCleanup
        self.released = released
    }

    // MARK: - Asking

    /// The lane this card was pulled into, or nil when it rests in Backlog.
    func lane(of cardID: String) -> Lane? {
        pulls[cardID]?.lane
    }

    /// When this card entered its lane, or nil when the board never pulled it.
    /// Callers fall back to `lastModifiedDate` — what the whole board used
    /// before this type existed.
    func pulledAt(_ cardID: String) -> Date? {
        pulls[cardID]?.at
    }

    func hasImported(listID: String) -> Bool {
        importedLists[listID] != nil
    }

    // MARK: - Writing

    /// Records a pull. Pulling into Backlog is a removal — see `Lane`.
    ///
    /// Re-recording the lane a card already sits in leaves `at` alone: a
    /// refresh that merely re-confirms a column must not make an old card look
    /// freshly pulled.
    mutating func pull(_ cardID: String, into lane: Lane?, at now: Date) {
        guard let lane else {
            release(cardID, at: now)
            return
        }
        guard pulls[cardID]?.lane != lane else { return }
        pulls[cardID] = Pull(lane: lane, at: now)
        // A card is either pulled or released, never both: the two fields
        // together answer one question per card, and `merge` compares their
        // dates as if they were one timeline.
        released.removeValue(forKey: cardID)
        cap()
    }

    /// Forgets a card's lane — it rests in Backlog with no dwell time. Used
    /// when a pull is spent (a recurring series whose turn was completed),
    /// when the card is completed, and when it is deleted.
    ///
    /// Records *when*, so that a merge can tell this apart from a machine that
    /// simply never saw the card (see `released`). Releasing a card this board
    /// never pulled leaves no trace: there is nothing to outrank.
    mutating func release(_ cardID: String, at now: Date) {
        guard pulls.removeValue(forKey: cardID) != nil else { return }
        released[cardID] = now
        capReleases()
    }

    /// Moves a pull to a new identifier. EventKit hands out a fresh identifier
    /// when a deleted reminder is written back, and may do so when a reminder
    /// changes list — without this, undoing a deletion would lose the column.
    mutating func rekey(from oldID: String, to newID: String) {
        guard oldID != newID, let pull = pulls.removeValue(forKey: oldID) else { return }
        pulls[newID] = pull
        released.removeValue(forKey: newID)
    }

    /// Marks a list as taken over, together with exactly which of its records
    /// still carry an old tag to be cut out.
    mutating func markImported(listID: String, at now: Date, taggedIDs: Set<String> = []) {
        importedLists[listID] = now
        pendingTagCleanup.formUnion(taggedIDs)
    }

    /// Whether this record is one the migration still has to clean. Anything
    /// else is the user's text and is never touched.
    func awaitsTagCleanup(_ cardID: String) -> Bool {
        pendingTagCleanup.contains(cardID)
    }

    mutating func markTagCleaned(_ cardID: String) {
        pendingTagCleanup.remove(cardID)
    }

    private mutating func cap() {
        guard pulls.count > Self.maxPulls else { return }
        let newestFirst = pulls.sorted { $0.value.at > $1.value.at }
        for stale in newestFirst.dropFirst(Self.maxPulls) {
            pulls.removeValue(forKey: stale.key)
        }
    }

    private mutating func capReleases() {
        guard released.count > Self.maxPulls else { return }
        let newestFirst = released.sorted { $0.value > $1.value }
        for stale in newestFirst.dropFirst(Self.maxPulls) {
            released.removeValue(forKey: stale.key)
        }
    }

    /// Drops releases old enough that no other device can still be holding a
    /// pull that predates them.
    mutating func prune(now: Date) {
        released = released.filter { now.timeIntervalSince($0.value) < Self.releaseRetention }
    }

    // MARK: - Merging

    /// What one side knows about one card: when it last said something, and
    /// what it said. `lane == nil` is a release.
    private struct Claim {
        var at: Date
        var lane: Lane?
    }

    private func claim(for cardID: String) -> Claim? {
        if let pull = pulls[cardID] { return Claim(at: pull.at, lane: pull.lane) }
        if let at = released[cardID] { return Claim(at: at, lane: nil) }
        return nil
    }

    /// Combines this machine's state with another's, per card, newest wins.
    ///
    /// **Absence is not an answer.** A machine that has never seen a card has
    /// no claim on it, which is different from having put it down — that is
    /// the whole reason `released` carries a date. Anything one side knows and
    /// the other does not is taken as-is; only two real claims are compared.
    ///
    /// **A tie goes to Backlog.** Equal timestamps are vanishingly unlikely
    /// (two clocks, to the second, on the same card), but the rule has to be
    /// deterministic or two Macs would settle on different boards and keep
    /// overwriting each other. Backlog is the direction this board always
    /// picks when it does not know, and it is symmetric: both machines reach
    /// the same answer regardless of which side they call their own.
    ///
    /// **Clock skew is the known limit.** The winner is decided by two
    /// machines' clocks; with normal time sync that is seconds, while pulls
    /// are minutes apart. A badly wrong clock can make an older pull win, and
    /// the cost is one drag.
    ///
    /// `pendingTagCleanup` is deliberately *not* merged: it lists which notes
    /// this Mac still has to cut a legacy tag out of, which is a statement
    /// about work this machine owes, not about the cards. The other Mac keeps
    /// its own list, and whoever cuts first makes the other's entry a no-op.
    /// Everything else is symmetric — `merged(a, b)` and `merged(b, a)` agree.
    static func merged(_ local: ColumnState, _ remote: ColumnState, now: Date) -> ColumnState {
        var pulls: [String: Pull] = [:]
        var released: [String: Date] = [:]

        let cardIDs = Set(local.pulls.keys).union(local.released.keys)
            .union(remote.pulls.keys).union(remote.released.keys)

        for cardID in cardIDs {
            let winner: Claim?
            switch (local.claim(for: cardID), remote.claim(for: cardID)) {
            case let (mine?, theirs?):
                if mine.at == theirs.at {
                    // Same instant, two answers: prefer the release, so both
                    // machines land on Backlog rather than on each other's lane.
                    winner = mine.lane == nil ? mine : (theirs.lane == nil ? theirs : mine)
                } else {
                    winner = mine.at > theirs.at ? mine : theirs
                }
            case let (mine?, nil): winner = mine
            case let (nil, theirs?): winner = theirs
            case (nil, nil): winner = nil
            }

            guard let winner else { continue }
            if let lane = winner.lane {
                pulls[cardID] = Pull(lane: lane, at: winner.at)
            } else {
                released[cardID] = winner.at
            }
        }

        // The earlier stamp wins: a list is imported once, and the question
        // this answers is "has it been", not "when was it last".
        let importedLists = local.importedLists.merging(remote.importedLists) { min($0, $1) }

        var merged = ColumnState(
            pulls: pulls,
            importedLists: importedLists,
            pendingTagCleanup: local.pendingTagCleanup,
            released: released)
        merged.prune(now: now)
        merged.cap()
        merged.capReleases()
        return merged
    }

    // MARK: - Persistence

    private static let log = Logger(
        subsystem: "com.davidtrogemann.GlassKanban", category: "columnstate")

    /// Bumped when the stored shape changes *incompatibly*. A payload with a
    /// version this build does not know is discarded rather than guessed at —
    /// and an empty state simply means every card rests in Backlog, which one
    /// drag repairs and which is never wrong in the dangerous direction.
    ///
    /// `released` was added without a bump, on purpose: it is a new key that
    /// older builds ignore while still reading every pull correctly, and this
    /// build reads a file without it as "nothing released yet". Bumping would
    /// have made every downgrade drop the whole board to Backlog to protect a
    /// field the old build does not need. The cost is that an older build
    /// writing the file back drops the release notes — harmless, because
    /// without sync there is no foreign pull for them to outrank.
    private static let formatVersion = 1

    /// The container the board's own files live in.
    ///
    /// In one place on purpose. Whether the Mac App Store accepts this form or
    /// insists on a `<TeamID>.group.…` prefix is not yet settled (no team to
    /// ask with — see BACKLOG.md), and a change here must stay a one-line
    /// change plus one more entry in `knownFileURLs`, never a data migration.
    /// The iOS form is chosen so the planned iOS app can use the same one.
    static let appGroupIdentifier = "group.com.davidtrogemann.GlassKanban"

    /// Where the file is written.
    ///
    /// The group container rather than the app's private one, because a
    /// widget, a Live Activity and an App Intent each run in their own process
    /// and cannot see inside the app's own sandbox. None of them exist yet;
    /// moving the file while it is cheap is the point, since doing it later
    /// means migrating live user data.
    ///
    /// Falls back to Application Support when the group container is
    /// unavailable — an entitlement that did not make it into the signature,
    /// a build configured differently. Writing nowhere would lose every pull
    /// on quit; writing to the old place keeps the board working exactly as it
    /// did before.
    ///
    /// An earlier version of this comment ruled out iCloud on the grounds that
    /// a synchronising store would bring back the second writer this type
    /// exists to remove. That reasoning was too broad and has been retired: it
    /// holds for the reminder's notes, which every EventKit client may rewrite,
    /// but not for a container keyed to this app's identifier, which no other
    /// program can reach. What syncing does admit is a second *instance of
    /// this app* — the user's own other Mac — which is a far narrower thing,
    /// and what `merged(_:_:now:)` is for.
    static func defaultFileURL(fileManager: FileManager = .default) -> URL? {
        let base = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? (try? fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true))
        guard let base else { return nil }
        let directory = base.appendingPathComponent("GlassKanban", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("columns.json")
    }

    /// Every place the file has ever been written, newest first.
    ///
    /// Reading walks this list and takes the first location that yields
    /// anything; writing only ever touches the first. Nothing is deleted when
    /// the file moves — a build that goes back to the old location finds its
    /// file untouched, and a move that goes wrong costs nothing. Tidying the
    /// abandoned copies up is a separate, later step, deliberately not folded
    /// into the move itself (BACKLOG.md, "Aufräumen der alten Speicherorte").
    static func knownFileURLs(fileManager: FileManager = .default) -> [URL] {
        var urls: [URL] = []
        if let current = defaultFileURL(fileManager: fileManager) {
            urls.append(current)
        }
        // The app's private container, where the file lived until 14.08.2026.
        if let legacy = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false) {
            let path = legacy
                .appendingPathComponent("GlassKanban", isDirectory: true)
                .appendingPathComponent("columns.json")
            if !urls.contains(path) { urls.append(path) }
        }
        return urls
    }

    /// Reads from the first known location that has something to give.
    ///
    /// A location that exists but reads as empty — a corrupt file, a version
    /// this build does not know — deliberately does *not* fall through to an
    /// older one. That file is the newest thing the board wrote; treating its
    /// loss as a reason to resurrect a stale copy would put cards back in
    /// lanes the user had already moved them out of. Empty means Backlog,
    /// which one drag repairs.
    /// Expired releases are dropped on the way in, so that every launch is a
    /// tidy-up. Without this the 30-day retention would only ever apply during
    /// a merge — which is to say not at all until syncing exists, and the file
    /// would carry release notes for cards nobody has touched in a year.
    static func loadFromKnownLocations(
        fileManager: FileManager = .default, now: Date = .now
    ) -> ColumnState {
        for url in knownFileURLs(fileManager: fileManager)
        where fileManager.fileExists(atPath: url.path) {
            var state = load(from: url)
            state.prune(now: now)
            return state
        }
        return ColumnState()
    }

    /// Reads the state, tolerating anything: a missing file, foreign JSON, a
    /// version from another build, a half-written payload, a single broken
    /// entry.
    ///
    /// Read entry by entry on purpose, the way `CorrectionLedger.load` reads
    /// its fields — a `Codable` round trip would throw away all two hundred
    /// pulls over one unreadable one. Only a payload that is not an object, or
    /// carries an unknown version, is discarded whole.
    static func load(from url: URL?) -> ColumnState {
        guard let url, let data = try? Data(contentsOf: url) else { return ColumnState() }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["v"] as? Int == formatVersion
        else {
            log.notice("column state unreadable or from another build — starting empty")
            return ColumnState()
        }
        var pulls: [String: Pull] = [:]
        for (cardID, raw) in root["pulls"] as? [String: Any] ?? [:] {
            guard let entry = raw as? [String: Any],
                  let lane = (entry["lane"] as? String).flatMap(Lane.init(rawValue:)),
                  let at = entry["at"] as? Double
            else { continue }
            pulls[cardID] = Pull(lane: lane, at: Date(timeIntervalSince1970: at))
        }
        let imported = (root["importedLists"] as? [String: Double] ?? [:])
            .mapValues(Date.init(timeIntervalSince1970:))
        let pending = Set(root["pendingTagCleanup"] as? [String] ?? [])
        // Missing in files written before releases existed, and by any older
        // build that rewrote one — read as "nothing released yet".
        let released = (root["released"] as? [String: Double] ?? [:])
            .mapValues(Date.init(timeIntervalSince1970:))
        return ColumnState(
            pulls: pulls, importedLists: imported,
            pendingTagCleanup: pending, released: released)
    }

    /// Writes the state atomically, so a crash mid-write cannot leave half a
    /// file behind.
    ///
    /// Returns whether it worked. A failure is the caller's to log and
    /// otherwise swallow: the pull the user just made is already live on
    /// screen, and the one thing this board may never do is put a dialog about
    /// its own storage in front of somebody who dragged a card.
    @discardableResult
    func save(to url: URL?) -> Bool {
        guard let url else { return false }
        let root: [String: Any] = [
            "v": Self.formatVersion,
            "pulls": pulls.mapValues { ["lane": $0.lane.rawValue, "at": $0.at.timeIntervalSince1970] },
            "importedLists": importedLists.mapValues(\.timeIntervalSince1970),
            "pendingTagCleanup": Array(pendingTagCleanup),
            "released": released.mapValues(\.timeIntervalSince1970),
        ]
        do {
            let data = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            Self.log.error("could not write column state: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
