import Foundation

/// Which card identifiers have quietly changed hands, and what may still be
/// written through them.
///
/// Completing a repeating reminder does not complete the record the board is
/// holding. Measured against real EventKit (08.08.2026): the finished turn is
/// filed away as a *new*, detached reminder with its own identifier and no
/// recurrence rule, while the series keeps the identifier the board has been
/// carrying and simply rolls on to its next date. From that moment the card id
/// no longer means "the chore you just finished" — it means "the next turn of
/// that chore", which nobody has pulled.
///
/// Everything queued against that id *before* the completion is therefore
/// aimed at the wrong work. The undo stack is the sharp edge: ⌘Z after
/// finishing a repeating card replayed the move that led into it, writing
/// `#inprogress` onto next week's occurrence — and a second ⌘Z `#next`. A
/// chore whose turn had not come sat in a working lane, counting against the
/// WIP limit, with nothing on screen to say why. Found on a real board: a
/// weekly shop completed at 22:08 was carrying `#next` at 22:34, without ever
/// being pulled.
///
/// So the rule this type holds: a replayed write (undo or redo) is refused
/// and explained when the entry behind it was recorded **before or at** the
/// completion. Entries recorded *after* it belong to the returned occurrence
/// and replay normally — the user's own later edits and moves are theirs.
///
/// **Why an order and not a clock.** The question here is "before or after?",
/// never "how long ago?". A duration would have to be calibrated against sync
/// latency, machine speed and a person's pace, and it would be wrong on both
/// sides of whatever value was picked; an order has no value to get wrong. It
/// also survives a clock change, a daylight-saving jump and a preferences file
/// restored from a backup, none of which an interval does. The store already
/// uses exactly this device twice for exactly this reason (`refreshGeneration`,
/// `writeGeneration`).
///
/// The decisive property is the direction it fails in: a write path that
/// forgets to take a stamp inherits an older one and gets **refused** — a
/// visible, recoverable annoyance. A time window would instead expire quietly
/// and let the write land on unpulled work. On a board whose forbidden
/// direction is "silently move a card", only one of the two is admissible.
///
/// Deliberately not "undo is disabled after a completion": the entry stays on
/// the stack and is spent on the explanation. Silently dropping it would let
/// the *next* ⌘Z reach past into an edit the user did mean to keep — the same
/// hazard `RemindersStore.move` already guards when a save fails.
struct RecurringHandoff {

    /// Where a write sits in this session's order of writes.
    ///
    /// A bare counter on purpose: it answers a two-valued question and carries
    /// no magnitude, so there is nothing to calibrate and nothing to get
    /// wrong. See the type's doc comment for why this is not a time constant.
    struct Generation: Comparable, Hashable {
        private let value: Int

        /// Before every write this session makes.
        static let first = Generation(value: 0)

        private init(value: Int) { self.value = value }

        func next() -> Generation { Generation(value: value + 1) }

        static func < (lhs: Generation, rhs: Generation) -> Bool { lhs.value < rhs.value }
    }

    /// Where each handed-over identifier was completed, in write order.
    private var handedOverAt: [String: Generation] = [:]

    /// Identifiers the user has acted on since — see
    /// `refusesUnattributedWrite(to:)`, the one question an order cannot
    /// answer.
    private var touchedSinceHandover: Set<String> = []

    /// How many handovers are kept. Far above any real session, and a hard
    /// bound on something that would otherwise grow all day.
    static let maxHandovers = 200

    /// Records the result of a completion.
    ///
    /// `isRecurringSeries` must be read from the reminder *before* the save:
    /// afterwards the record is the rolled-on series, which says nothing about
    /// what just happened to the occurrence.
    ///
    /// `at` is the position of the write that completed the card — the same
    /// stamp that write's own undo entry carries, which is precisely why that
    /// entry is refused too: undoing the completion is the step that was
    /// measured writing `#inprogress` onto the next turn.
    mutating func completed(cardID: String, isRecurringSeries: Bool, at generation: Generation) {
        guard isRecurringSeries else { return }
        handedOverAt[cardID] = generation
        touchedSinceHandover.remove(cardID)
        prune()
    }

    /// Records a move the user made themselves — a drag, the context menu, the
    /// VoiceOver action.
    ///
    /// This deliberately does **not** reopen the undo stack. An entry from
    /// before the completion still aims at work that no longer exists, however
    /// many deliberate moves came after it; clearing the fence here is exactly
    /// what let a second ⌘Z tag the never-pulled occurrence. It records only
    /// that the identifier names a card the user has touched again, which is
    /// what an *unattributed* write needs to know.
    mutating func movedDeliberately(cardID: String) {
        guard handedOverAt[cardID] != nil else { return }
        touchedSinceHandover.insert(cardID)
    }

    /// Whether a replayed write recorded at `recordedAt` would land on the
    /// next turn of a series instead of on the work it was recorded for.
    ///
    /// `<=`, not `<`: the completing write and its own undo entry share a
    /// stamp, and that entry is the one the original bug was found on.
    func refusesReplay(of cardID: String, recordedAt: Generation) -> Bool {
        guard let handover = handedOverAt[cardID] else { return false }
        return recordedAt <= handover
    }

    /// Whether the board may write to this identifier on its own initiative —
    /// an echo answer, a hygiene pass, a spent pull.
    ///
    /// Those carry no undo entry and therefore no position in the write order,
    /// so the only answerable question is whether this identifier still points
    /// at a turn nobody has pulled. Here a deliberate move genuinely does hand
    /// the identifier back: the user is acting on the card in front of them.
    func refusesUnattributedWrite(to cardID: String) -> Bool {
        handedOverAt[cardID] != nil && !touchedSinceHandover.contains(cardID)
    }

    /// Bounds the fence without throwing it away.
    ///
    /// Deliberately no longer an intersection with the board: a series whose
    /// list is switched off in Settings vanishes from the refresh while its
    /// undo entries stay on the stack, and forgetting the handover there let
    /// exactly the measured write land. Oldest handover dropped first.
    mutating func retain(atMost limit: Int = maxHandovers) {
        guard handedOverAt.count > limit else { return }
        let oldestFirst = handedOverAt.sorted { $0.value < $1.value }
        for entry in oldestFirst.prefix(handedOverAt.count - limit) {
            handedOverAt.removeValue(forKey: entry.key)
            touchedSinceHandover.remove(entry.key)
        }
    }

    private mutating func prune() {
        retain()
    }
}
