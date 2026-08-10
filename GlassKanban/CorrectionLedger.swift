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
/// > **A decision the user made is restored whenever something undoes it —
/// > but never more than once per `cooldown` for the same card.**
///
/// The board has to work next to other software. Reminders, Fantastical, a
/// home automation bridge, a shortcut: any of them may read and write the
/// same records, and an app that only works when it is the sole writer would
/// be no product at all. So the board stands by what the user decided for as
/// long as something keeps undoing it. The pace is the only thing bounded —
/// what it rules out is not the fight but the *storm*: two programs writing
/// at each other faster than a person could notice, or a hygiene pass firing
/// on every one of the dozens of refreshes an hour.
///
/// It is deliberately not a rule about hashtags, recurrence or due dates —
/// it is an invariant over every write the user did not ask for. What follows
/// from it:
///
/// - The measured storm cannot recur: a state is answered at most once per
///   cooldown, no matter how many refreshes see it.
/// - Two Macs running the board write at each other at most six times an hour
///   each — bounded and slow enough to stay a curiosity, not a loop.
/// - A single sync conflict — the ordinary case on a shared list — is healed
///   immediately, which is the whole point of correcting at all.
/// - A stale writer that keeps pushing an old state keeps losing: every
///   occurrence is answered, so the card spends its time in the column the
///   user put it in.
///
/// All of it stays invisible: the board says nothing about any of this, ever.
/// A notice about column mechanics would be standing noise on a surface whose
/// whole point is quiet (user decision, 10.08.2026 — see CONCEPT.md).
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
        /// When the app last answered this displacement, if it has. Not a
        /// one-way flag: the board keeps standing by its decision for as long
        /// as something keeps undoing it, and this timestamp is only what
        /// paces the answers (see `cooldown`).
        var answeredAt: Date?
    }

    /// The shortest gap between two answers to the same card.
    ///
    /// Not a retreat, a pace. Another program writing into the same reminders
    /// is normal — the board must work next to Reminders, Fantastical, a home
    /// automation bridge, whatever the user runs; being usable only alone
    /// would be no product at all. So a decision the user made is restored as
    /// often as something undoes it, and the only thing this limit prevents
    /// is two programs writing at each other faster than a person could
    /// notice. Measured against the real case (a stale snapshot returning
    /// every 19 to 55 minutes), ten minutes restores every single occurrence
    /// while capping the worst case at six writes an hour per card.
    static let cooldown: TimeInterval = 10 * 60

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
        // A write that displaced nothing still ends whatever was remembered
        // here: the user has acted on this card since, so an older
        // displacement has nothing left to say. Backlog → Erledigt is exactly
        // that shape — both are tagless, so the notes come out unchanged.
        guard replaced != wrote else {
            entries.removeValue(forKey: cardID)
            return
        }
        entries[cardID] = Entry(replaced: replaced, wrote: wrote, at: at, answeredAt: nil)
    }

    /// The text a correction would restore, or nil to leave the record alone.
    ///
    /// Answers when the current text is byte-for-byte the state this app
    /// displaced, the entry is still fresh, and the last answer is longer ago
    /// than `cooldown`.
    func pendingEcho(for cardID: String, current: String?, now: Date) -> String?? {
        guard let entry = entries[cardID],
              now.timeIntervalSince(entry.at) < Self.staleAfter,
              current == entry.replaced,
              entry.answeredAt.map({ now.timeIntervalSince($0) >= Self.cooldown }) ?? true
        else { return nil }
        return .some(entry.wrote)
    }

    /// Whether the app may write to this record on its own initiative — the
    /// data hygiene, a spent pull, an echo.
    ///
    /// The single "no" is the pace: this exact state was answered less than
    /// `cooldown` ago. Everything else is allowed, including a state the app
    /// has never seen.
    func permitsAutomaticWrite(for cardID: String, current: String?, now: Date) -> Bool {
        guard let entry = entries[cardID],
              let answeredAt = entry.answeredAt,
              now.timeIntervalSince(entry.at) < Self.staleAfter,
              current == entry.replaced,
              now.timeIntervalSince(answeredAt) < Self.cooldown
        else { return true }
        return false
    }

    /// Notes that an answer just went out, whether or not it survives. The
    /// entry stays armed — if the same state returns after the cooldown, the
    /// board answers again.
    mutating func markAnswered(cardID: String, at: Date) {
        entries[cardID]?.answeredAt = at
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
                answeredAt: (fields["answeredAt"] as? Double).map(Date.init(timeIntervalSince1970:)))
        }
        return CorrectionLedger(entries: entries)
    }

    func save(to defaults: UserDefaults = .standard) {
        var stored: [String: Any] = [:]
        for (id, entry) in entries {
            var fields: [String: Any] = ["at": entry.at.timeIntervalSince1970]
            if let answeredAt = entry.answeredAt {
                fields["answeredAt"] = answeredAt.timeIntervalSince1970
            }
            // nil means "no notes at all", which a plist cannot hold — the key
            // is simply absent, and reading turns that back into nil.
            if let replaced = entry.replaced { fields["replaced"] = replaced }
            if let wrote = entry.wrote { fields["wrote"] = wrote }
            stored[id] = fields
        }
        defaults.set(stored, forKey: Self.storageKey)
    }
}
