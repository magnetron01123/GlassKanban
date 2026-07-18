import SwiftUI
import AppKit

/// Design tokens for the board, ported from design/board-mockup.html and
/// iteration 2 (design/iteration-2-concept.md).
///
/// Depth model ("a real kanban board"): the window is the only large glass
/// surface, columns are recessed lanes cut into the board, cards are
/// near-opaque paper sticky notes resting on top. Depth comes from
/// contrasting treatments (fill, contour, shadow), not from stacking blur.
enum Board {
    // Layout — a centered block of four equally wide lanes with real air
    // between them. Focus comes from what the cards reveal (see
    // KanbanStatus.cardDensity), not from lane geometry.
    static let boardPadding: CGFloat = 20
    static let columnSpacing: CGFloat = 20
    static let columnMinWidth: CGFloat = 280
    static let columnMaxWidth: CGFloat = 400
    static let boardMinWidth: CGFloat = columnMinWidth * 4 + columnSpacing * 3 + boardPadding * 2
    static let cardSpacing: CGFloat = 8
    /// The lane's inner margin — one value for the header, its hairline, the
    /// cards and the "more" button, so everything inside a lane shares a
    /// single left edge.
    static let laneMargin: CGFloat = 12
    /// A card's own text margins. Leading is wider because the list stripe
    /// sits inside it; the zone hairlines follow the same insets.
    static let cardInsetLeading: CGFloat = 14
    static let cardInsetTrailing: CGFloat = 12
    /// Working-lane cards hold this much height even when nearly empty, so
    /// they read as sticky notes with a body instead of flat title bars.
    static let fullCardMinHeight: CGFloat = 118
    /// One-line rows in the storage lanes: 13pt text plus 9pt padding above
    /// and below. Only used for the drop placeholder in an empty lane —
    /// once a lane holds a card, its real height is measured instead.
    static let compactCardHeight: CGFloat = 34
    /// A card only reports its dwell time once it has lingered this long —
    /// below it, sitting in a column is simply normal.
    static let agingThresholdDays = 3

    // Radii (mockup: column 14, card 11, badge 6)
    static let columnRadius: CGFloat = 14
    static let cardRadius: CGFloat = 11
    static let badgeRadius: CGFloat = 6

    // Contours
    static let columnBorder = Color.primary.opacity(0.12)
    static let cardBorder = Color.primary.opacity(0.10)
    /// Top edge of a card catches light, like the edge of a paper note.
    static let cardTopHighlight = Color.white.opacity(0.5)

    /// Cards stay neutral paper (Apple surfaces are never tinted wholesale);
    /// the Reminders list color appears as a slim marker stripe on the
    /// leading edge, the way physical tickets carry a color code.
    static let cardStripeWidth: CGFloat = 3

    // Surfaces. Cards are OPAQUE paper: translucent materials made card
    // brightness depend on the wallpaper behind the window, which inverted
    // the elevation (cards rendered darker than the lanes). Solid fills keep
    // the depth order deterministic — lanes always recede below the window
    // glass, paper always sits above them ("elevated = lighter" in dark).
    static func columnFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.065)
    }

    /// Finished work recedes a step — but only a step. Dimming it to the
    /// ~92% that "receding" suggests would collapse the contrast against
    /// the lane (measured: 28 grey values down to 6) and undo the elevation
    /// entirely, so the paper stays bright and the shadow does the receding.
    static func cardFill(_ scheme: ColorScheme, isDone: Bool = false) -> Color {
        if scheme == .dark {
            return isDone ? Color(white: 0.22) : Color(white: 0.25)
        }
        return isDone ? Color(white: 0.97) : .white
    }

    static let columnInnerShadow = Color.black.opacity(0.10)

    // Card shadows: tight contact shadow + soft ambient = physical elevation
    static let cardShadowResting = (color: Color.black.opacity(0.10), radius: CGFloat(1.5), y: CGFloat(1))
    static let cardShadowAmbient = (color: Color.black.opacity(0.05), radius: CGFloat(5), y: CGFloat(3))
    static let cardShadowHover = (color: Color.black.opacity(0.16), radius: CGFloat(9), y: CGFloat(5))

    /// Backlog shows this many cards before offering "N weitere anzeigen".
    static let backlogCollapsedLimit = 15

    // Motion
    static let hoverAnimation: Animation = .easeOut(duration: 0.16)
    static let dropTargetAnimation: Animation = .easeOut(duration: 0.15)
    /// Card "settling" into Erledigt — a small reward on completion.
    static let settleAnimation: Animation = .spring(response: 0.32, dampingFraction: 0.5)
    /// Slow breathing glow inviting the user to pull the next card.
    static let pullBreath: Animation = .easeInOut(duration: 1.7).repeatForever(autoreverses: true)
}

/// Subtle trackpad haptics — a sensory reward for moving and completing work.
/// Not gated behind Reduce Motion: these are physical feedback, not visual
/// animation, and match how the system itself (Finder, sliders) behaves.
enum Haptics {
    static func alignmentTick() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func drop() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
