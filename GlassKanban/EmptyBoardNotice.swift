import SwiftUI

/// The one line the board says when it has nothing to show at all.
///
/// Deliberately not per lane: an empty lane is normal and stays quiet (see
/// `ColumnView.showsPullSlot`), but four blank columns without a word look
/// like a failure rather than a state. One line, no icon, no explanation —
/// same register as the empty slot's "Fertig werden beginnt hier".
struct EmptyBoardNotice: View {
    let emptiness: RemindersStore.Emptiness
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(line)
                .font(BoardText.title)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Only the filtered case gets a control: being done is not a
            // problem to solve, so it is stated, not acted upon.
            if emptiness == .filteredAway {
                Button("Filter zurücksetzen", action: onReset)
                    .buttonStyle(.link)
                    .font(BoardText.body)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The lanes stay visible behind it: the board never disappears, it
        // just has nothing on it right now.
        .allowsHitTesting(emptiness == .filteredAway)
    }

    /// Both lines carry the comma rhythm the board already uses in the WIP
    /// dialog ("Weniger gleichzeitig, mehr fertig"), and both name a payoff
    /// rather than describing a lack: an empty board is the point of the
    /// method, and an empty search result is not lost data.
    private var line: String {
        switch emptiness {
        case .nothingToDo: "Board leer, Kopf frei"
        case .filteredAway: "Kein Treffer, nichts verloren"
        }
    }
}
