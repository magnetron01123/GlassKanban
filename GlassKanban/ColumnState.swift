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

    init(pulls: [String: Pull] = [:], importedLists: [String: Date] = [:]) {
        self.pulls = pulls
        self.importedLists = importedLists
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
            release(cardID)
            return
        }
        guard pulls[cardID]?.lane != lane else { return }
        pulls[cardID] = Pull(lane: lane, at: now)
        cap()
    }

    /// Forgets a card's lane — it rests in Backlog with no dwell time. Used
    /// when a pull is spent (a recurring series whose turn was completed),
    /// when the card is completed, and when it is deleted.
    mutating func release(_ cardID: String) {
        pulls.removeValue(forKey: cardID)
    }

    /// Moves a pull to a new identifier. EventKit hands out a fresh identifier
    /// when a deleted reminder is written back, and may do so when a reminder
    /// changes list — without this, undoing a deletion would lose the column.
    mutating func rekey(from oldID: String, to newID: String) {
        guard oldID != newID, let pull = pulls.removeValue(forKey: oldID) else { return }
        pulls[newID] = pull
    }

    mutating func markImported(listID: String, at now: Date) {
        importedLists[listID] = now
    }

    private mutating func cap() {
        guard pulls.count > Self.maxPulls else { return }
        let newestFirst = pulls.sorted { $0.value.at > $1.value.at }
        for stale in newestFirst.dropFirst(Self.maxPulls) {
            pulls.removeValue(forKey: stale.key)
        }
    }

    // MARK: - Persistence

    private static let log = Logger(
        subsystem: "com.davidtrogemann.GlassKanban", category: "columnstate")

    /// Bumped when the stored shape changes. A payload with a version this
    /// build does not know is discarded rather than guessed at — and an empty
    /// state simply means every card rests in Backlog, which one drag repairs
    /// and which is never wrong in the dangerous direction.
    private static let formatVersion = 1

    /// The app's own Application Support directory, inside the sandbox
    /// container. Not iCloud: a synchronising store would reintroduce exactly
    /// the second writer this change exists to remove.
    static func defaultFileURL(fileManager: FileManager = .default) -> URL? {
        guard let base = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        else { return nil }
        let directory = base.appendingPathComponent("GlassKanban", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("columns.json")
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
        return ColumnState(pulls: pulls, importedLists: imported)
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
