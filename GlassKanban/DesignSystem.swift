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
    // Layout — the board is a centered object, not stretched to the screen.
    static let boardPadding: CGFloat = 16
    static let columnSpacing: CGFloat = 14
    static let columnMinWidth: CGFloat = 230
    static let columnMaxWidth: CGFloat = 300
    /// Cap so cards keep sticky-note proportions on wide displays.
    static let boardMaxWidth: CGFloat = columnMaxWidth * 4 + columnSpacing * 3
    static let boardMinWidth: CGFloat = columnMinWidth * 4 + columnSpacing * 3 + boardPadding * 2
    static let cardSpacing: CGFloat = 8

    // Radii (mockup: column 14, card 11, badge 6)
    static let columnRadius: CGFloat = 14
    static let cardRadius: CGFloat = 11
    static let badgeRadius: CGFloat = 6

    // Contours
    static let columnBorder = Color.primary.opacity(0.10)
    static let cardBorder = Color.primary.opacity(0.10)
    /// Top edge of a card catches light, like the edge of a paper note.
    static let cardTopHighlight = Color.white.opacity(0.5)

    /// List color laid over the paper fill — this is what makes a card read
    /// as a colored sticky note. Kept subtle so the board stays calm.
    static let cardTintOpacity: Double = 0.12

    // Recessed column fill (replaces glass-on-glass material)
    static let columnFill = Color.primary.opacity(0.045)
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
