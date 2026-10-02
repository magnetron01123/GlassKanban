import Foundation
import os

/// A ticket's rough size — the T-shirt sizing many Kanban boards use to see
/// at a glance how much work a card holds.
///
/// Three sizes on purpose (CONCEPT.md, "T-Shirt-Größen"): coarse beats
/// precise, nothing below S is worth a label, and anything beyond L is a card
/// Kanban would split before pulling it. Relative, never hours.
enum TicketSize: String, CaseIterable, Equatable {
    // Raw values are the stored form in `sizes.json` — a persisted contract,
    // pinned by a test. Never rename them.
    case small = "s"
    case medium = "m"
    case large = "l"

    /// The letter on the card's tab. Not localized: S, M and L are the
    /// clothing labels everywhere.
    var letter: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }

}

/// Which card carries which size, stored by the app in `sizes.json` — never in
/// the reminder, which every EventKit client may rewrite.
///
/// Built on the same terms as `ColumnState`: the same directory
/// (`BoardStorage`), keyed by card ID, read entry by entry, written
/// atomically, and every entry dated so two of the user's Macs can be merged
/// the day syncing exists. Its own file rather than a field in
/// `columns.json` (29.09.2026): the name would promise columns, and the
/// column merge has rules (releases, ties to Backlog) a size does not share.
struct SizeState: Equatable {

    /// A size, or its removal, and when that was decided.
    ///
    /// A removal is kept as a dated tombstone (`size == nil`) instead of
    /// deleting the entry: absence is not a statement, so without the
    /// tombstone a merge would let another Mac's older size bring back one
    /// the user had just taken off.
    struct Entry: Equatable {
        var size: TicketSize?
        var at: Date
    }

    /// Enough for every card a person realistically sizes. Oldest decisions
    /// go first. Deliberately not pruned against the reminders loaded right
    /// now: a hidden list is not a deleted one.
    static let maxEntries = 1000
    /// How long a removal is remembered — the same window `ColumnState`
    /// keeps its releases for.
    static let tombstoneRetention: TimeInterval = 30 * 24 * 60 * 60

    private(set) var entries: [String: Entry]

    init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    func size(of cardID: String) -> TicketSize? {
        entries[cardID]?.size
    }

    /// Sets a size, or removes it with nil. Setting what is already there is
    /// not a decision and leaves the date alone.
    mutating func set(_ size: TicketSize?, for cardID: String, at now: Date) {
        guard self.size(of: cardID) != size else { return }
        entries[cardID] = Entry(size: size, at: now)
        cap()
    }

    /// Carries the size across an identity change (a list move gives the
    /// reminder a new ID).
    mutating func rekey(from oldID: String, to newID: String) {
        guard oldID != newID, let entry = entries.removeValue(forKey: oldID) else { return }
        entries[newID] = entry
    }

    /// Drops tombstones older than the retention window.
    mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.tombstoneRetention)
        entries = entries.filter { $0.value.size != nil || $0.value.at >= cutoff }
    }

    private mutating func cap() {
        guard entries.count > Self.maxEntries else { return }
        let newestFirst = entries.sorted { $0.value.at > $1.value.at }
        entries = Dictionary(uniqueKeysWithValues: newestFirst.prefix(Self.maxEntries).map { ($0.key, $0.value) })
    }

    /// Two Macs' decisions, card by card: the newer one wins. A tie goes to
    /// the removal — the same direction `ColumnState` breaks a tie in
    /// (toward Backlog): the safe answer is the one that shows less.
    static func merged(_ local: SizeState, _ remote: SizeState, now: Date) -> SizeState {
        var result: [String: Entry] = [:]
        for cardID in Set(local.entries.keys).union(remote.entries.keys) {
            switch (local.entries[cardID], remote.entries[cardID]) {
            case let (mine?, theirs?):
                if mine.at != theirs.at {
                    result[cardID] = mine.at > theirs.at ? mine : theirs
                } else if mine.size == nil || theirs.size == nil {
                    result[cardID] = Entry(size: nil, at: mine.at)
                } else {
                    // Same moment, two different sizes: pick deterministically,
                    // so both Macs arrive at the same answer.
                    result[cardID] = mine.size!.rawValue <= theirs.size!.rawValue ? mine : theirs
                }
            case let (mine?, nil): result[cardID] = mine
            case let (nil, theirs?): result[cardID] = theirs
            case (nil, nil): break
            }
        }
        var merged = SizeState(entries: result)
        merged.prune(now: now)
        merged.cap()
        return merged
    }

    // MARK: - Persistence

    private static let log = Logger(
        subsystem: "com.davidtrogemann.GlassKanban", category: "sizestate")

    /// Bumped only when the stored shape changes incompatibly; an unknown
    /// version is discarded rather than guessed at. Losing sizes costs a few
    /// clicks, never a card.
    private static let formatVersion = 1

    static let fileName = "sizes.json"

    static func defaultFileURL(fileManager: FileManager = .default) -> URL? {
        BoardStorage.defaultFileURL(named: fileName, fileManager: fileManager)
    }

    /// Reads the current file and tidies expired tombstones on the way in.
    /// No legacy locations: this file has only ever lived where
    /// `BoardStorage` puts it.
    static func loadFromDefaultLocation(
        fileManager: FileManager = .default, now: Date = .now
    ) -> SizeState {
        var state = load(from: defaultFileURL(fileManager: fileManager))
        state.prune(now: now)
        return state
    }

    /// Reads the state, tolerating anything — a missing file, foreign JSON, a
    /// version from another build, a single broken entry. Entry by entry, for
    /// the reason `ColumnState.load(from:)` gives.
    static func load(from url: URL?) -> SizeState {
        guard let url, let data = try? Data(contentsOf: url) else { return SizeState() }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["v"] as? Int == formatVersion
        else {
            log.notice("size state unreadable or from another build — starting empty")
            return SizeState()
        }
        var entries: [String: Entry] = [:]
        for (cardID, raw) in root["sizes"] as? [String: Any] ?? [:] {
            guard let entry = raw as? [String: Any],
                  let at = entry["at"] as? Double
            else { continue }
            // A missing "size" is a tombstone; an unknown one is skipped
            // rather than read as a removal.
            let size: TicketSize?
            if let rawSize = entry["size"] as? String {
                guard let known = TicketSize(rawValue: rawSize) else { continue }
                size = known
            } else {
                size = nil
            }
            entries[cardID] = Entry(size: size, at: Date(timeIntervalSince1970: at))
        }
        return SizeState(entries: entries)
    }

    /// Writes atomically. Returns whether it worked; a failure is the
    /// caller's to log and otherwise swallow — never a dialog.
    @discardableResult
    func save(to url: URL?) -> Bool {
        guard let url else { return false }
        let root: [String: Any] = [
            "v": Self.formatVersion,
            "sizes": entries.mapValues { entry -> [String: Any] in
                var stored: [String: Any] = ["at": entry.at.timeIntervalSince1970]
                if let size = entry.size { stored["size"] = size.rawValue }
                return stored
            },
        ]
        do {
            let data = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            Self.log.error("could not write size state: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
