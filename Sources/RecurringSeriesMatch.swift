import Foundation

/// Which live series a completed reminder is an occurrence of.
///
/// Completing a repeating reminder detaches the finished turn into a record of
/// its own: new identifier, no recurrence rule, and nothing on the record
/// itself that says which series it came from. Until 10.08.2026 the board
/// matched on title and list, which was wrong in both directions — an ordinary
/// one-off named exactly like a live series could never be restored from
/// Erledigt ("die Serie ist bereits weitergelaufen", which was false about
/// that card), and renaming a series after a completion disabled the guard
/// entirely.
///
/// **Measured against real EventKit (10.08.2026, iCloud scratch list):** the
/// detached occurrence carries the *series'* `creationDate`, to the
/// microsecond — years old for a standing chore — while an ordinary one-off
/// carries its own. Even five reminders written in a single commit came out
/// with distinct creation dates, so this is an identity rather than a
/// coincidence. A series renamed after the completion still matched.
///
/// Compared for **equality, never for nearness**. A tolerance window would
/// turn an identity back into a similarity, and two chores created seconds
/// apart in one list would become each other's occurrences. The external
/// identifier is not usable here: the measurement showed the detached copy
/// gets a fresh one, and it is nil on local lists anyway.
///
/// Any doubt returns nil, and both callers read nil as "no proof": the drag
/// out of Erledigt is permitted, and the tag stays where it is.
enum RecurringSeriesMatch {

    /// One reminder reduced to what identity reads.
    struct Record: Equatable {
        let id: String
        let listID: String
        let createdAt: Date?
        let isCompleted: Bool
        let isRecurring: Bool

        init(id: String, listID: String, createdAt: Date?, isCompleted: Bool, isRecurring: Bool) {
            self.id = id
            self.listID = listID
            self.createdAt = createdAt
            self.isCompleted = isCompleted
            self.isRecurring = isRecurring
        }
    }

    /// The identifier of the live series this completed record is an
    /// occurrence of — or nil when nothing matches, and equally when more than
    /// one does.
    static func seriesID(of occurrence: Record, among candidates: [Record]) -> String? {
        guard occurrence.isCompleted, let created = occurrence.createdAt else { return nil }
        let matches = candidates.filter {
            !$0.isCompleted
                && $0.isRecurring
                && $0.listID == occurrence.listID
                && $0.createdAt == created
                && $0.id != occurrence.id
        }
        // Exactly one, or nothing. Ambiguity falls to "no proof" for the same
        // reason every other doubt on this board does: a wrong answer here
        // either strands a card in Erledigt or takes a tag off work somebody
        // pulled.
        guard matches.count == 1 else { return nil }
        return matches[0].id
    }

    /// Open records that are really finished turns somebody re-opened — the
    /// board shows these nowhere.
    ///
    /// Un-ticking a completed repeating reminder is one click in Reminders,
    /// on a phone, anywhere. It reads as "undo that completion", but the
    /// series rolled on the moment it was ticked and cannot roll back: what
    /// comes back is not the old turn, it is a second, identical-looking card
    /// beside a series that is already carrying the next one. Measured
    /// 11.08.2026 — the only operation that produces an *open* detached
    /// record. Renaming a series, moving its due date and completing it were
    /// all measured and produce none.
    ///
    /// This board already holds that this state is wrong: dragging a finished
    /// occurrence out of Erledigt is refused with "die Serie ist bereits
    /// weitergelaufen — das würde die Aufgabe doppelt aufs Board legen". The
    /// same judgement has to apply when the click happened elsewhere, or the
    /// app forbids itself what it then displays.
    ///
    /// Identified exactly like a finished turn is (same list, same creation
    /// date to the microsecond, exactly one live series) — the only
    /// difference being that this one is open. Anything ambiguous is left
    /// alone and shown, as everywhere else in this type.
    static func revivedOccurrenceIDs(among candidates: [Record]) -> Set<String> {
        var revived: Set<String> = []
        for record in candidates where !record.isCompleted && !record.isRecurring {
            guard let created = record.createdAt else { continue }
            let series = candidates.filter {
                !$0.isCompleted
                    && $0.isRecurring
                    && $0.listID == record.listID
                    && $0.createdAt == created
                    && $0.id != record.id
            }
            guard series.count == 1 else { continue }
            revived.insert(record.id)
        }
        return revived
    }
}
