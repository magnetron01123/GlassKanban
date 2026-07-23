import SwiftUI

/// The one line the board says when it has nothing to show at all.
///
/// Deliberately not per lane: an empty lane is normal and stays quiet (see
/// `ColumnView.showsPullSlot`), but four blank columns without a word look
/// like a failure rather than a state. One line, no icon, no explanation —
/// same register as the empty slot's "Fertig werden beginnt hier".
struct EmptyBoardNotice: View {
    let emptiness: BoardEmptiness
    let onReset: () -> Void
    let onShowRecurring: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(line)
                .font(BoardText.title)
                // A step down from title's semibold: card-title size so the
                // sentence carries the same weight of announcement, but
                // lighter so it never reads as a ticket competing for
                // attention among (absent) real ones.
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Only the cases with a way out get a control: being done is not a
            // problem to solve, so it is stated, not acted upon.
            if let action {
                Button(action.label, action: action.perform)
                    .buttonStyle(.link)
                    .font(BoardText.body)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The lanes stay visible behind it: the board never disappears, it
        // just has nothing on it right now.
        .allowsHitTesting(action != nil)
    }

    /// All three lines carry the comma rhythm the board already uses in the WIP
    /// dialog ("Weniger gleichzeitig, mehr fertig"), and each names a payoff
    /// rather than describing a lack: an empty board is the point of the
    /// method, an empty search result is not lost data, and a board holding
    /// nothing but future chores is a quiet day rather than a broken app.
    private var line: String {
        switch emptiness {
        case .nothingToDo: "Board leer, Kopf frei"
        case .filteredAway: "Kein Treffer, nichts verloren"
        case .recurringOnly: "Nichts fällig, Wiederkehrendes wartet"
        }
    }

    /// The way out, where there is one. `recurringOnly` deliberately does not
    /// offer "Filter zurücksetzen": the filters are already at rest, and that
    /// button would do nothing at all.
    private var action: (label: String, perform: () -> Void)? {
        switch emptiness {
        case .nothingToDo: nil
        case .filteredAway: ("Filter zurücksetzen", onReset)
        case .recurringOnly: ("Wiederkehrende anzeigen", onShowRecurring)
        }
    }
}
