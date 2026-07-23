import SwiftUI

/// The one line the board says when it has nothing to show at all.
///
/// Deliberately not per lane: an empty lane is normal and stays quiet (see
/// `ColumnView.showsPullSlot`), but four blank columns without a word look
/// like a failure rather than a state. One line, no icon, no explanation —
/// same register as the empty slot's "Fertig werden beginnt hier".
///
/// It sits on paper, not on nothing. Laid bare over the lanes, the sentence
/// landed wherever the board's centre happened to be — usually straddling the
/// gap between two lanes, half over a recessed well and half over window
/// glass, with a tinted link floating beneath it. That reads as text which
/// lost its container, not as the board speaking. This board's own vocabulary
/// for "something is written here" is a paper note, so the notice takes one:
/// the same fill, contour and shadow a card gets, in the place cards would be.
struct EmptyBoardNotice: View {
    let emptiness: BoardEmptiness
    let onReset: () -> Void
    let onShowRecurring: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 8) {
            Text(line)
                .font(BoardText.title)
                // A step down from title's semibold: card-title size so the
                // sentence carries the same weight of announcement, but
                // lighter so it never reads as a ticket competing for
                // attention among (absent) real ones. Primary rather than
                // secondary now that it has paper under it — on a card, the
                // sentence *is* the content.
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            // Only the cases with a way out get a control: being done is not a
            // problem to solve, so it is stated, not acted upon.
            if let action {
                Button(action.label, action: action.perform)
                    .buttonStyle(.link)
                    .font(BoardText.body)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background { Board.cardShape.fill(paper) }
        .overlay { Board.cardShape.strokeBorder(Board.cardBorder(contrast)) }
        // Both card shadows, so the note sits at the same height above the
        // lanes as a real one does — the depth order stays readable.
        .shadow(
            color: Board.cardShadowResting.color,
            radius: Board.cardShadowResting.radius,
            y: Board.cardShadowResting.y)
        .shadow(
            color: Board.cardShadowAmbient.color,
            radius: Board.cardShadowAmbient.radius,
            y: Board.cardShadowAmbient.y)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The lanes stay visible behind it: the board never disappears, it
        // just has nothing on it right now.
        .allowsHitTesting(action != nil)
    }

    /// The same opaque paper a card is made of — see `CardView.cardFill` for
    /// why translucency is wrong on this plane.
    private var paper: Color {
        reduceTransparency
            ? Color(nsColor: .controlBackgroundColor)
            : Board.cardFill(colorScheme)
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
