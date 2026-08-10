import Foundation

/// What the app has already corrected once, so it never corrects it twice.
///
/// The board is one writer among several. Reminders sync through iCloud,
/// shared lists have a second person on them, and other software — a
/// automation bridge, a calendar client, a script — writes into the same
/// records. Measured on a real board (10.08.2026): something outside pushed a
/// stale snapshot back every 30 to 55 minutes, and the app's tag hygiene
/// rewrote the same four reminders three times in three hours. Twelve writes
/// into someone else's data, not one of which held.
///
/// The rule that ends that, and the only one this type exists for:
///
/// > **Every correction the app makes to data it did not change itself
/// > happens once. If the same state comes back, the app accepts it.**
///
/// It is deliberately not "try harder", and deliberately not a rule about
/// hashtags, recurrence or due dates — it is an invariant over every write
/// the user did not ask for. What it buys, all from the same sentence:
///
/// - A write storm cannot form. A hostile writer gets one answer, not one
///   per refresh, forever.
/// - Two Macs running the board cannot fight. Each corrects at most once per
///   move its own user made, so the exchange terminates.
/// - The convergence promise of the sync hygiene holds by construction: a
///   correction that cannot repeat cannot loop.
/// - A single sync conflict — the ordinary case on a shared list — is still
///   healed, which is the whole point of correcting at all.
///
/// What it cannot buy: winning. Against a writer that keeps pushing an old
/// state, the app loses the column and shows what the data says, because the
/// data *is* the truth (the app owns no store of its own). That is a
/// deliberate choice over an endless fight, and it stays invisible: the board
/// says nothing about it, ever. A notice about column mechanics would be
/// standing noise on a surface whose whole point is quiet (user decision,
/// 10.08.2026 — see CONCEPT.md).
///
/// **Byte-exact, not status-exact.** An entry remembers the literal note text
/// that was replaced. A restored snapshot reproduces those bytes; a person
/// typing `#next` into notes on their phone produces a different string — a
/// different line, a different spelling, other whitespace — and is therefore
/// read as the decision it is. Comparing at status level would silently undo
/// that person instead, which is the opposite of what the board is for.
struct CorrectionLedger: Equatable {

    /// One write the app made, and what it displaced.
    struct Entry: Equatable {
        /// The note text as it stood before the app wrote — the exact string
        /// whose return marks an echo.
        let replaced: String?
        /// What the app put there instead, i.e. what a correction restores.
        let wrote: String?
        /// When the write happened. An entry that is old enough to predate
        /// any plausible sync delay has nothing left to say (see `staleAfter`).
        let at: Date
        /// Whether the one correction this displacement is owed has been
        /// spent. Kept rather than deleted: a forgotten entry would let the
        /// next sync start the argument over from the beginning, which is
        /// what a write storm is.
        var answered: Bool
    }

    /// How long an entry stays actionable. Echoes arrive within minutes to
    /// hours; a day is far past that. The limit matters for a case the
    /// consumption rule alone does not cover: preferences restored from a
    /// backup would otherwise carry a target state for every card on the
    /// board into a session whose data has moved on weeks ahead.
    static let staleAfter: TimeInterval = 24 * 60 * 60

    private var entries: [String: Entry] = [:]

    init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    /// Records a write the app made. Called for user moves and edits too, not
    /// only for automatic corrections: it is precisely a *user's* move that
    /// gets echoed back by a stale writer, and only a record of it can tell
    /// the echo from a fresh decision.
    mutating func record(cardID: String, replaced: String?, wrote: String?, at: Date) {
        guard replaced != wrote else { return }
        entries[cardID] = Entry(replaced: replaced, wrote: wrote, at: at, answered: false)
    }

    /// The text a correction would restore, or nil to leave the record alone.
    ///
    /// Answers only when the current text is byte-for-byte the state this app
    /// displaced, the entry is still fresh, and the one correction it is owed
    /// has not been spent.
    func unansweredEcho(for cardID: String, current: String?, now: Date) -> String?? {
        guard let entry = entries[cardID],
              !entry.answered,
              now.timeIntervalSince(entry.at) < Self.staleAfter,
              current == entry.replaced
        else { return nil }
        return .some(entry.wrote)
    }

    /// Whether the app may write to this record on its own initiative — the
    /// data hygiene, a spent pull, an echo.
    ///
    /// The single "no" is the invariant: this exact state has already been
    /// answered once. Everything else is allowed, including a state the app
    /// has never seen and one it displaced but has not yet answered.
    func permitsAutomaticWrite(for cardID: String, current: String?, now: Date) -> Bool {
        guard let entry = entries[cardID],
              entry.answered,
              now.timeIntervalSince(entry.at) < Self.staleAfter,
              current == entry.replaced
        else { return true }
        return false
    }

    /// Spends the correction this displacement was owed, whether or not it
    /// survives. One answer per displacement is the whole rule.
    mutating func markAnswered(cardID: String) {
        entries[cardID]?.answered = true
    }

    /// Drops what is remembered about a card because the user acted on it.
    /// Their hand outranks any bookkeeping: whatever this identifier used to
    /// stand for, the state they just chose is the one to keep.
    mutating func forget(cardID: String) {
        entries.removeValue(forKey: cardID)
    }

    /// Forgets cards that are no longer on the board and entries that have
    /// gone stale, so a session left open for days cannot grow without bound.
    mutating func retain(_ liveCardIDs: Set<String>, now: Date) {
        entries = entries.filter { id, entry in
            liveCardIDs.contains(id) && now.timeIntervalSince(entry.at) < Self.staleAfter
        }
    }

    // MARK: - Persistence

    /// One defaults key holding a nested plist dictionary, in the shape the
    /// rest of the app already uses for stored state (`wipLimits`,
    /// `tagReleaseMemory`). Reading tolerates anything: a missing key, foreign
    /// types, a half-written entry. Whatever cannot be vouched for is dropped,
    /// and an empty ledger simply means the app behaves as it did before this
    /// type existed.
    static let storageKey = "correctionLedger"

    static func load(from defaults: UserDefaults = .standard) -> CorrectionLedger {
        guard let stored = defaults.dictionary(forKey: storageKey) else { return CorrectionLedger() }
        var entries: [String: Entry] = [:]
        for (id, raw) in stored {
            guard let fields = raw as? [String: Any],
                  let timestamp = fields["at"] as? Double else { continue }
            entries[id] = Entry(
                replaced: fields["replaced"] as? String,
                wrote: fields["wrote"] as? String,
                at: Date(timeIntervalSince1970: timestamp),
                answered: fields["answered"] as? Bool ?? false)
        }
        return CorrectionLedger(entries: entries)
    }

    func save(to defaults: UserDefaults = .standard) {
        var stored: [String: Any] = [:]
        for (id, entry) in entries {
            var fields: [String: Any] = ["at": entry.at.timeIntervalSince1970, "answered": entry.answered]
            // nil means "no notes at all", which a plist cannot hold — the key
            // is simply absent, and reading turns that back into nil.
            if let replaced = entry.replaced { fields["replaced"] = replaced }
            if let wrote = entry.wrote { fields["wrote"] = wrote }
            stored[id] = fields
        }
        defaults.set(stored, forKey: Self.storageKey)
    }
}
