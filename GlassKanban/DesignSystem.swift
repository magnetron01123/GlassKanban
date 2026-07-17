import SwiftUI

/// Design tokens for the board, ported from design/board-mockup.html.
///
/// Depth model ("a real kanban board"): the window is the only large glass
/// surface, columns are recessed lanes cut into the board, cards are
/// near-opaque paper resting on top. Depth comes from contrasting
/// treatments (fill, contour, shadow), not from stacking blur.
enum Board {
    // Spacing (mockup: board gap 14, padding 16, cards gap 8)
    static let boardPadding: CGFloat = 16
    static let columnSpacing: CGFloat = 14
    static let cardSpacing: CGFloat = 8

    // Radii (mockup: column 14, card 11, badge 6)
    static let columnRadius: CGFloat = 14
    static let cardRadius: CGFloat = 11
    static let badgeRadius: CGFloat = 6

    // Contours
    static let columnBorder = Color.primary.opacity(0.10)
    static let cardBorder = Color.primary.opacity(0.10)
    /// Top edge of a card catches light, like the edge of a paper card.
    static let cardTopHighlight = Color.white.opacity(0.5)

    // Recessed column fill (replaces glass-on-glass material)
    static let columnFill = Color.primary.opacity(0.045)
    static let columnInnerShadow = Color.black.opacity(0.10)

    // Card shadows: tight contact shadow + soft ambient = physical elevation
    static let cardShadowResting = (color: Color.black.opacity(0.10), radius: CGFloat(1.5), y: CGFloat(1))
    static let cardShadowAmbient = (color: Color.black.opacity(0.05), radius: CGFloat(5), y: CGFloat(3))
    static let cardShadowHover = (color: Color.black.opacity(0.16), radius: CGFloat(9), y: CGFloat(5))

    // Motion
    static let hoverAnimation: Animation = .easeOut(duration: 0.16)
    static let dropTargetAnimation: Animation = .easeOut(duration: 0.15)
}
