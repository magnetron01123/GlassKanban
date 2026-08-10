import Foundation

/// What the board wrote over what, per field, so it can stand by its own
/// writes when another program undoes them.
///
/// The board is one writer among several. Reminders sync through iCloud,
/// shared lists have a second person on them, and other software — a calendar
/// client, an automation bridge, a script — writes into the same records.
/// Measured on a real board (10.08.2026): a calendar client running since
/// days before pushed a stale copy of records back every 19 to 55 minutes,
/// undoing whatever anyone else had written. Six records in thirty hours,
/// only one of them recurring; the rest went unnoticed only because a
/// restored tag on a *completed* reminder changes nothing anyone can see.
///
/// The rule this type exists for:
///
/// > **The board remembers which value it wrote over which. If a field later
/// > holds the displaced value again, letter for letter, the board writes its
/// > own value back once — at most once per ten minutes, for at most a day,
/// > and never a value the user did not enter here themselves.**
///
/// That last clause is the whole safety argument. Every value this mechanism
/// can ever write is one the user typed or dragged into being *on this board*
/// within the last day, written only onto a record that still carries, letter
/// for letter, the value that entry displaced. Never an invented value, never
/// a derived one, and above all never one adopted from the foreign writer:
/// defending merely *observed* transitions was designed, attacked and
/// discarded, because a writer that pushes more often than the user would get
/// its stale values adopted and then enforced with the board's own authority.
///
/// One deliberate exception, and only because its direction is safe: when a
/// working-lane tag disappears anywhere — on the phone, in Reminders, by a
/// script — that counts as a displacement too. All that can be restored from
/// it is the *absence* of a tag, so the worst it can cost is one drag, and
/// the card rests in Backlog rather than in a lane nobody pulled.
struct CorrectionLedger: Equatable {

    /// The protected fields. Exhaustive on purpose — what is missing here is
    /// not excluded by a runtime rule but cannot be defended safely at all:
    ///
    /// - `priority` has four values, so byte equality carries no evidence,
    ///   and the only direction that would be safe is the one that hurts
    ///   (defending the user's *clearing* of a priority against their
    ///   re-setting it elsewhere).
    /// - `isCompleted` has two values and no discriminator: a person
    ///   reopening a task and a stale writer reopening it produce identical
    ///   bits. Taking a completion away is the costliest false positive on
    ///   this board, and in thirty measured hours it never once flipped.
    /// - `calendar` is list membership, which the board never changes.
    /// - `recurrenceRules` is turned over by EventKit itself when a series
    ///   rolls on; writing it back would create a second live series.
    /// - `alarms` is the one field whose restoration is audible.
    /// - `startDate` and `location` are only ever written onto a freshly
    ///   created reminder, which has no history to defend.
    /// - Subtasks, attachments and Reminders' own tags are not reachable
    ///   through the public EventKit API at all — invisible in both
    ///   directions, so "the whole card" means "the whole card as EventKit
    ///   describes it".
    enum Field: String, CaseIterable {
        case notes, title, url, due
    }

    /// A protected value. Dates carry whether they had a time of day, since
    /// restoring an all-day date as a timed one would move it.
    enum Value: Equatable {
        case text(String?)
        case due(Date?, hasTime: Bool)
    }

    /// The protected values of one card plus the two facts the direction
    /// rules need. Purely transient — never persisted.
    struct CardState: Equatable {
        var title: String?
        var notes: String?
        /// The *parsed* form (`URL.absoluteString`), because that is what a
        /// record holds after a save; comparing the typed form would read
        /// percent-encoding as a permanent echo.
        var url: String?
        var due: Date?
        var hasDueTime: Bool
        var isCompleted: Bool
        var isRecurring: Bool

        init(title: String?, notes: String?, url: String?, due: Date?,
             hasDueTime: Bool, isCompleted: Bool, isRecurring: Bool) {
            self.title = title
            self.notes = notes
            self.url = url
            self.due = due
            self.hasDueTime = hasDueTime
            self.isCompleted = isCompleted
            self.isRecurring = isRecurring
        }

        subscript(field: Field) -> Value {
            switch field {
            case .notes: return .text(notes)
            case .title: return .text(title)
            case .url: return .text(url)
            case .due: return .due(due, hasTime: hasDueTime)
            }
        }
    }

    struct Entry: Equatable {
        let replaced: Value
        let wrote: Value
        let at: Date
        /// When the board last answered this displacement. Not a one-way
        /// flag: it stands by its write for as long as something undoes it,
        /// and this only paces the answers.
        var answeredAt: Date?
    }

    /// The shortest gap between two answers to the same field of the same
    /// card. Not a retreat, a pace: it rules out two programs writing at each
    /// other faster than a person could notice, and a hygiene pass firing on
    /// every one of the dozens of syncs in an hour. Measured against the real
    /// case (a stale state returning every 19 to 55 minutes), ten minutes
    /// answers every single occurrence.
    static let cooldown: TimeInterval = 10 * 60

    /// How long an entry stays actionable. Echoes arrive within minutes to
    /// hours; a day is far past that. It also bounds what a restored
    /// preferences file can do to a board that has moved on for weeks.
    static let staleAfter: TimeInterval = 24 * 60 * 60

    /// How many cards the ledger keeps at all, oldest displacement dropped
    /// first. Far above any real board's working set, and a hard bound on a
    /// file that lives in UserDefaults.
    static let maxCards = 200

    private var entries: [String: [Field: Entry]] = [:]

    init(entries: [String: [Field: Entry]] = [:]) {
        self.entries = entries
    }

    // MARK: - Booking

    /// Records what the board just wrote over what, for one field.
    ///
    /// Called for the user's own moves and edits — that is the point: it is
    /// precisely a *user's* decision that a stale writer undoes, and only a
    /// record of it can tell that undoing from a fresh decision.
    mutating func record(cardID: String, field: Field, replaced: Value, wrote: Value, at: Date) {
        // A write that displaced nothing still ends what was remembered *for
        // this field*: the user has acted on it since, so an older
        // displacement has nothing left to say. Only this field, though —
        // clearing the whole card here let a hygiene pass that changes no
        // status quietly disarm the defence of the user's own move.
        guard replaced != wrote else {
            entries[cardID]?.removeValue(forKey: field)
            if entries[cardID]?.isEmpty == true { entries.removeValue(forKey: cardID) }
            return
        }
        entries[cardID, default: [:]][field] = Entry(
            replaced: replaced, wrote: wrote, at: at, answeredAt: nil)
    }

    /// Notes the state a card is actually in.
    ///
    /// A value that is neither what the board wrote nor what it displaced is
    /// a *third* state: somebody decided something new, and the old
    /// displacement is history. Withdrawing the entry here is what keeps this
    /// mechanism from fighting a user who changes their mind — only an exact
    /// reversal is ever contested.
    mutating func observe(cardID: String, state: CardState, now: Date) {
        guard var fields = entries[cardID] else { return }
        for (field, entry) in fields {
            let current = state[field]
            if current != entry.replaced && current != entry.wrote {
                fields.removeValue(forKey: field)
            }
        }
        if fields.isEmpty {
            entries.removeValue(forKey: cardID)
        } else {
            entries[cardID] = fields
        }
    }

    // MARK: - Asking

    /// Every field of this card that currently holds the displaced value and
    /// is owed an answer — with the value to restore.
    func pendingEchoes(for cardID: String, state: CardState, now: Date) -> [Field: Value] {
        guard let fields = entries[cardID] else { return [:] }
        var due: [Field: Value] = [:]
        for (field, entry) in fields {
            guard isFresh(entry, now: now),
                  state[field] == entry.replaced,
                  entry.answeredAt.map({ now.timeIntervalSince($0) >= Self.cooldown }) ?? true,
                  Self.restoring(entry.wrote, over: state, field: field)
            else { continue }
            due[field] = entry.wrote
        }
        return due
    }

    /// Whether the board may write this field on its own initiative — the
    /// data hygiene, a spent pull, an echo. The single "no" is the pace: this
    /// exact state was answered less than `cooldown` ago.
    func permitsWrite(cardID: String, field: Field, state: CardState, now: Date) -> Bool {
        guard let entry = entries[cardID]?[field],
              let answeredAt = entry.answeredAt,
              isFresh(entry, now: now),
              state[field] == entry.replaced,
              now.timeIntervalSince(answeredAt) < Self.cooldown
        else { return true }
        return false
    }

    /// Notes that an answer went out, whether or not it survives.
    mutating func markAnswered(cardID: String, field: Field, at: Date) {
        entries[cardID]?[field]?.answeredAt = at
    }

    /// How long until the earliest deferred answer comes due, or nil when
    /// nothing is waiting. Corrections only run during a sync, and a sync
    /// only happens when something changes — a state that merely *stays*
    /// wrong triggers none, so without this a deferred answer would never be
    /// given at all.
    func nextAnswerDue(now: Date) -> TimeInterval? {
        entries.values
            .flatMap { $0.values }
            .compactMap { entry -> TimeInterval? in
                guard let answeredAt = entry.answeredAt, isFresh(entry, now: now) else { return nil }
                let due = Self.cooldown - now.timeIntervalSince(answeredAt)
                return due > 0 ? due : nil
            }
            .min()
    }

    // MARK: - Direction rules

    /// Whether restoring `value` into `field` is a direction the board is
    /// allowed to write in.
    ///
    /// Every rule here answers the same question: what does it cost when we
    /// are wrong? "A stale writer undid it" and "a person undid it by hand"
    /// are indistinguishable in the data, so each field is only defended in
    /// the direction whose false positive is cheap and quiet.
    private static func restoring(_ value: Value, over state: CardState, field: Field) -> Bool {
        switch field {
        case .title, .url:
            // Both directions. High-cardinality text: an exact byte match is
            // real evidence, and being wrong costs a word the user retypes.
            return true
        case .notes:
            // An automatic write may leave the column alone or let the card
            // fall to Backlog — it must never lift it into a working lane.
            // That is the same doubt the whole board resolves the same way.
            guard case let .text(restored) = value else { return false }
            let current = StatusTagger.status(fromNotes: state.notes, isCompleted: state.isCompleted)
            let target = StatusTagger.status(fromNotes: restored, isCompleted: state.isCompleted)
            return target == current || target == .backlog
        case .due:
            // Only a date that *vanished* comes back. Restoring a *moved*
            // date would let the board delete a deadline the user just set,
            // and dates cluster on few days, so byte equality proves little.
            // A recurring series is off limits entirely: EventKit moves its
            // date itself when the series rolls on.
            guard case let .due(restored, _) = value else { return false }
            return restored != nil && state.due == nil && !state.isRecurring
        }
    }

    private func isFresh(_ entry: Entry, now: Date) -> Bool {
        let age = now.timeIntervalSince(entry.at)
        // A negative age means the entry is stamped in the future — a clock
        // change, or a file from another machine. Nothing to trust there.
        return age >= 0 && age < Self.staleAfter
    }

    // MARK: - Housekeeping

    /// Drops entries that have gone stale and caps the ledger at `maxCards`,
    /// oldest first.
    ///
    /// Deliberately not filtered by "cards in the current fetch": an entry
    /// for a card that happens not to be loaded right now is simply inert,
    /// while dropping it would throw the defence away during exactly the sync
    /// hiccup it exists for — and lose it for good when a list is switched
    /// off in Settings.
    mutating func retain(now: Date) {
        for (cardID, fields) in entries {
            let fresh = fields.filter { isFresh($0.value, now: now) }
            if fresh.isEmpty {
                entries.removeValue(forKey: cardID)
            } else {
                entries[cardID] = fresh
            }
        }
        guard entries.count > Self.maxCards else { return }
        let byAge = entries
            .map { (id: $0.key, newest: $0.value.values.map(\.at).max() ?? .distantPast) }
            .sorted { $0.newest > $1.newest }
        for stale in byAge.dropFirst(Self.maxCards) {
            entries.removeValue(forKey: stale.id)
        }
    }

    // MARK: - Persistence

    /// One defaults key holding a nested plist dictionary, in the shape the
    /// rest of the app already uses for stored state. Reading tolerates
    /// anything: a missing key, foreign types, a half-written entry, a
    /// payload from an older build. Whatever cannot be vouched for is
    /// dropped, and an empty ledger simply means the app behaves as it did
    /// before this type existed.
    static let storageKey = "correctionLedger"

    /// Bumped when the stored shape changes. A payload without it comes from
    /// the single-field build and is discarded rather than guessed at.
    private static let formatVersion = 2

    static func load(from defaults: UserDefaults = .standard) -> CorrectionLedger {
        guard let stored = defaults.dictionary(forKey: storageKey),
              stored["v"] as? Int == formatVersion,
              let cards = stored["cards"] as? [String: [String: Any]]
        else { return CorrectionLedger() }
        var entries: [String: [Field: Entry]] = [:]
        for (cardID, rawFields) in cards {
            var fields: [Field: Entry] = [:]
            for (rawField, rawEntry) in rawFields {
                guard let field = Field(rawValue: rawField),
                      let dict = rawEntry as? [String: Any],
                      let at = dict["at"] as? Double,
                      let replaced = decodeValue(dict["replaced"], field: field),
                      let wrote = decodeValue(dict["wrote"], field: field)
                else { continue }
                fields[field] = Entry(
                    replaced: replaced,
                    wrote: wrote,
                    at: Date(timeIntervalSince1970: at),
                    answeredAt: (dict["answeredAt"] as? Double).map(Date.init(timeIntervalSince1970:)))
            }
            if !fields.isEmpty { entries[cardID] = fields }
        }
        return CorrectionLedger(entries: entries)
    }

    func save(to defaults: UserDefaults = .standard) {
        var cards: [String: [String: Any]] = [:]
        for (cardID, fields) in entries {
            var stored: [String: Any] = [:]
            for (field, entry) in fields {
                var dict: [String: Any] = ["at": entry.at.timeIntervalSince1970]
                if let answeredAt = entry.answeredAt {
                    dict["answeredAt"] = answeredAt.timeIntervalSince1970
                }
                dict["replaced"] = Self.encodeValue(entry.replaced)
                dict["wrote"] = Self.encodeValue(entry.wrote)
                stored[field.rawValue] = dict
            }
            cards[cardID] = stored
        }
        defaults.set(["v": Self.formatVersion, "cards": cards] as [String: Any], forKey: Self.storageKey)
    }

    /// A value becomes a small dictionary rather than a bare string, so that
    /// "no notes at all" stays distinguishable from an empty note — the two
    /// are different states, and a plist cannot hold nil.
    private static func encodeValue(_ value: Value) -> [String: Any] {
        switch value {
        case let .text(text):
            var dict: [String: Any] = ["kind": "text"]
            if let text { dict["text"] = text }
            return dict
        case let .due(date, hasTime):
            var dict: [String: Any] = ["kind": "due", "hasTime": hasTime]
            if let date { dict["date"] = date.timeIntervalSince1970 }
            return dict
        }
    }

    private static func decodeValue(_ raw: Any?, field: Field) -> Value? {
        guard let dict = raw as? [String: Any], let kind = dict["kind"] as? String else { return nil }
        switch kind {
        case "text":
            guard field != .due else { return nil }
            return .text(dict["text"] as? String)
        case "due":
            guard field == .due else { return nil }
            return .due(
                (dict["date"] as? Double).map(Date.init(timeIntervalSince1970:)),
                hasTime: dict["hasTime"] as? Bool ?? false)
        default:
            return nil
        }
    }
}
