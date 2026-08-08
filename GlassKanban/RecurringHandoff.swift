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
/// Everything queued against that id before the completion is therefore aimed
/// at the wrong work. The undo stack is the sharp edge: ⌘Z after finishing a
/// repeating card replayed the move that led into it, writing `#inprogress`
/// onto next week's occurrence — and a second ⌘Z `#next`. A chore whose turn
/// had not come sat in a working lane, counting against the WIP limit, with
/// nothing on screen to say why. Found on a real board: a weekly shop
/// completed at 22:08 was carrying `#next` at 22:34, without ever being
/// pulled.
///
/// So the rule this type holds: once a repeating card has been completed,
/// replayed writes (undo and redo) through that id are refused and explained,
/// rather than landing on work that has not been started. A *deliberate* move
/// — the user pulling the new occurrence when its turn does come round — hands
/// the id back, and undo means what it says again from there.
///
/// Deliberately not "undo is disabled after a completion": the entry stays on
/// the stack and is spent on the explanation. Silently dropping it would let
/// the *next* ⌘Z reach past into an edit the user did mean to keep — the same
/// hazard `RemindersStore.move` already guards when a save fails.
struct RecurringHandoff {

    private var handedOver: Set<String> = []

    /// Records the result of a completion.
    ///
    /// `isRecurringSeries` must be read from the reminder *before* the save:
    /// afterwards the record is the rolled-on series, which says nothing about
    /// what just happened to the occurrence.
    mutating func completed(cardID: String, isRecurringSeries: Bool) {
        guard isRecurringSeries else { return }
        handedOver.insert(cardID)
    }

    /// Records a move the user made themselves — a drag, the context menu, the
    /// VoiceOver action. Whatever this id used to stand for, the user is now
    /// acting on the card in front of them, so it is theirs again.
    mutating func movedDeliberately(cardID: String) {
        handedOver.remove(cardID)
    }

    /// Whether a replayed write (undo/redo) through this id would land on the
    /// next turn of a series instead of on the work it was recorded for.
    func refusesReplay(of cardID: String) -> Bool {
        handedOver.contains(cardID)
    }

    /// Forgets ids that are no longer on the board — a deleted card cannot be
    /// undone into a wrong lane, and nothing should grow without bound over a
    /// session that stays open for days.
    mutating func retain(_ liveCardIDs: Set<String>) {
        handedOver.formIntersection(liveCardIDs)
    }
}
