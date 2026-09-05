import SwiftUI
import AppKit

/// The one line the board says when it has nothing to show at all.
///
/// Deliberately not per lane: a single empty lane carries its own quiet
/// invitation (see `ColumnView.showsEmptySlot`), but four blank columns
/// without a word look like a failure rather than a state. This panel and
/// those slots never appear together — with nothing on the board at all, the
/// slots stand down and let this one line speak. One line, no icon, no
/// explanation — same register as the slots' own appeals.
///
/// It gets a surface, and that surface is glass. Laid bare over the lanes the
/// sentence landed on whatever was behind the board's middle — usually
/// straddling the gap between two lanes, half over a recessed well and half
/// over window glass, reading as text that had lost its container.
///
/// Glass, not the paper a card is made of: this is the board *saying*
/// something about its own state, not a ticket. Paper is the content plane
/// and belongs to things that hold work; a transient message floating above
/// the lanes is chrome, and chrome is where Liquid Glass lives. It therefore
/// borrows the tooltip's treatment wholesale — same material, same shape
/// family, same lifted shadow pair, same hairline — because a tooltip is the
/// one thing in this app that already answers "a panel the board puts in
/// front of its own content, briefly".
struct EmptyBoardNotice: View {
    let emptiness: BoardEmptiness
    let onReset: () -> Void
    /// Injected like `onReset` rather than reached for directly: opening the
    /// Reminders app is the store's job, and it already knows the one way to
    /// do it that uses documented API (`openRemindersApp`).
    let onOpenReminders: () -> Void

    /// SwiftUI's own way into the Settings window (macOS 14+), so the one
    /// state whose way out lives *outside* the board can still offer one.
    @Environment(\.openSettings) private var openSettings
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
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background { surface }
        .overlay { edge }
        .overlay { topHighlight }
        // The tooltip's shadow pair: a tight contact shadow to keep the edge
        // readable wherever it lands, and a wide ambient one that says the
        // panel is floating above the board rather than lying on it.
        .shadow(
            color: Board.tooltipShadowContact.color,
            radius: Board.tooltipShadowContact.radius,
            y: Board.tooltipShadowContact.y)
        .shadow(
            color: Board.tooltipShadowAmbient.color,
            radius: Board.tooltipShadowAmbient.radius,
            y: Board.tooltipShadowAmbient.y)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The lanes stay visible behind it: the board never disappears, it
        // just has nothing on it right now.
        .allowsHitTesting(action != nil)
    }

    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            Board.tooltipShape.fill(Board.opaqueGlassFill(colorScheme))
        } else {
            // `.withinWindow`: this floats above the board's own content, so
            // it frosts the lanes behind it rather than punching through to
            // the desktop.
            HUDGlassMaterial(blending: .withinWindow)
                .clipShape(Board.tooltipShape)
        }
    }

    /// Half a point, like the tooltip's — at this scale a full hairline is
    /// what makes a glass panel read as a bordered box.
    private var edge: some View {
        Board.tooltipShape
            .strokeBorder(Board.cardBorder(contrast), lineWidth: 0.5)
    }

    /// The lit top edge every glass surface here carries, dark mode only:
    /// on a light surface a white highlight is invisible and pure render cost.
    @ViewBuilder
    private var topHighlight: some View {
        if colorScheme == .dark {
            Board.tooltipShape
                .strokeBorder(
                    LinearGradient(colors: [Board.cardTopHighlight, .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    /// Plain statements of what is the case.
    ///
    /// These were three comma-rhythm phrases that each turned the state into
    /// a small consolation ("Kein Treffer, nichts verloren"). Read once they
    /// are charming; met every time the board runs dry they are a wink from
    /// software that was asked to be quiet, and the second half of each one
    /// says nothing the first half did not. A calm app is allowed to simply
    /// name the state and stop.
    private var line: String {
        switch emptiness {
        case .nothingToDo: String(localized: "Nothing to Do")
        case .filteredAway: String(localized: "No Matches")
        // Not "Nothing to Do": the board has no source, which is a setting,
        // not an achievement.
        case .noListsSelected: String(localized: "No List Selected")
        // The board has nothing to draw from because this Mac has no
        // reminder lists at all. Sending someone to Settings here would only
        // repeat the news in a second place.
        case .noListsAtAll: String(localized: "No Reminder Lists")
        // Nothing is claimed before the first answer is in.
        case .loading: ""
        }
    }

    /// The way out, where there is one. `nothingToDo` has none on purpose:
    /// there is nothing to undo and nothing to fix.
    private var action: (label: String, perform: () -> Void)? {
        switch emptiness {
        case .nothingToDo: nil
        case .filteredAway: (String(localized: "Reset Filters"), onReset)
        case .noListsSelected: (String(localized: "Choose Lists"), { openSettings() })
        // The way out is the Reminders app, where a list can actually be
        // made — not this app's settings, which would have nothing to list.
        //
        // Through the store, not through `x-apple-reminderkit://`, which is
        // what stood here until 14.08.2026: that is the undocumented scheme
        // RELEASE.md removes for 1.0 (guideline 2.5.1), and this second use of
        // it was not on that list — it would have shipped after the documented
        // one was gone. `openRemindersApp()` does the same thing through
        // `urlForApplication(withBundleIdentifier:)` and needs no force-unwrap.
        case .noListsAtAll: (String(localized: "Open Reminders"), onOpenReminders)
        case .loading: nil
        }
    }
}
