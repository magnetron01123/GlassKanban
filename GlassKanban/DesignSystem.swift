import SwiftUI
import AppKit

/// Design tokens for the board (see design/iteration-2-concept.md).
///
/// Depth model ("a real kanban board"): the window is the only large glass
/// surface, columns are recessed lanes cut into the board, cards are
/// near-opaque paper sticky notes resting on top. Depth comes from
/// contrasting treatments (fill, contour, shadow), not from stacking blur.
///
/// This is also the Liquid Glass model Apple describes: glass belongs to the
/// chrome — window backdrop, toolbar, popovers — never to the content plane.
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

    // Radii, stepped down with nesting depth so a card's corner never looks
    // wider than the lane holding it.
    static let columnRadius: CGFloat = 14
    static let cardRadius: CGFloat = 11

    // Shapes. Always `.continuous`: `RoundedRectangle(cornerRadius:)` defaults
    // to `.circular`, a plain arc, while every shape macOS itself draws — the
    // window, sheets, popovers and each Liquid Glass control — is the
    // continuous squircle. Mixing the two is the difference between "native"
    // and "nearly native" that a viewer notices but cannot name. Exported as
    // tokens so the style cannot be forgotten at an individual call site.
    static let columnShape = RoundedRectangle(cornerRadius: columnRadius, style: .continuous)
    static let cardShape = RoundedRectangle(cornerRadius: cardRadius, style: .continuous)

    /// One shape for every chip that carries a small, quiet value — the date
    /// badge on a card and the count in a lane header. These had drifted into
    /// three different treatments for one role (rounded rect 6, capsule,
    /// rounded rect 7) at two different fill strengths. Same role, same shape,
    /// same fill; the capsule is also what macOS 26 uses for value chips.
    /// The search field deliberately stays a rounded rect: it is an input
    /// control, not a value, and should not read as one.
    static let chipShape = Capsule()
    static let chipFill: Double = 0.7

    /// A WIP limit is a statement about *capacity*, not urgency, so it stays
    /// out of the warm family (orange = due today, red = overdue). Teal reads
    /// as neutral flow and, unlike the accent colour, cannot collide with a
    /// user who runs their system in orange.
    static let wipLimitTint = Color.teal

    // Badges. Three weights carry urgency: solid (overdue), tinted (today),
    // quiet grey (everything else). System colours are calibrated as fills and
    // glyphs, never as small text on a light background — Reminders and
    // Calendar both use orange as a plane, not as a label. So the tint colours
    // the capsule and the label always takes a system text colour.
    static let badgeTintFill: Double = 0.22
    /// System red behind white 11pt semibold lands near 3.5:1 — under the
    /// 4.5:1 minimum. Darkening the fill keeps the alarm and clears the bar.
    static let overdueFill = Color.red.mix(with: .black, by: 0.24)
    /// The over-limit capsule needs the same treatment as a badge: teal text
    /// on a teal wash measured ~2:1, so the label moves to the system colour
    /// and the capsule carries the teal.
    static let wipCapsuleFill: Double = 0.28

    // Contours. Depth here is carried almost entirely by contour rather than
    // fill (the lane wash is only 6.5% in light mode), so Increase Contrast
    // has to reach these values — otherwise the setting does nothing on the
    // board's two most important edges.
    static func columnBorder(_ contrast: ColorSchemeContrast) -> Color {
        Color.primary.opacity(contrast == .increased ? 0.30 : 0.12)
    }

    static func cardBorder(_ contrast: ColorSchemeContrast) -> Color {
        Color.primary.opacity(contrast == .increased ? 0.26 : 0.10)
    }

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

    /// Wells that zone the stats popover's sections — the lanes' recessed
    /// treatment at panel scale, the way the system's own inset groups zone
    /// Settings. Same fill as a lane (`columnFill`), radius one step under
    /// the tooltip's per the nesting rule. Not glass: a well is content
    /// sitting *in* the popover's glass, and the one thing it must never do
    /// is blur what is behind it a second time.
    static let wellShape = RoundedRectangle(cornerRadius: 9, style: .continuous)

    // Tooltips. Chrome, not content — so glass is right here, unlike on a
    // card. The radius is the card's own, less one: a tooltip rests directly
    // on paper, and matching its curve family is what keeps it from reading
    // as a foreign box dropped onto the board.
    static let tooltipRadius: CGFloat = 10
    static let tooltipShape = RoundedRectangle(cornerRadius: tooltipRadius, style: .continuous)
    /// A hard cap, not a width. The panel measures its own text and only
    /// wraps once a line would pass this — so a three-word tooltip stays
    /// three words wide instead of sitting in an oversized plate.
    static let tooltipMaxWidth: CGFloat = 240
    /// Slower than a hover highlight, faster than the system's own tooltip:
    /// long enough not to fire while the cursor crosses the board, short
    /// enough that looking something up does not feel like waiting.
    static let tooltipDelay: Duration = .milliseconds(450)
    /// Two layers, like a card — but lifted. The contact shadow keeps its
    /// edge readable on white paper, the ambient one says it is floating
    /// rather than lying on the board.
    static let tooltipShadowContact = (color: Color.black.opacity(0.10), radius: CGFloat(2), y: CGFloat(1))
    static let tooltipShadowAmbient = (color: Color.black.opacity(0.14), radius: CGFloat(16), y: CGFloat(6))

    // Motion
    static let hoverAnimation: Animation = .easeOut(duration: 0.16)
    static let dropTargetAnimation: Animation = .easeOut(duration: 0.15)
    /// Card "settling" into Erledigt — a small reward on completion.
    /// The board's only recurring animation: motion is spent on things that
    /// just happened, never on a standing invitation. An empty lane is its own
    /// pull signal — Kanban's answer to "what should I start next" has always
    /// been the free slot on the board, not an effect layered over it.
    static let settleAnimation: Animation = .spring(response: 0.32, dampingFraction: 0.5)
}

/// The board's type scale.
///
/// Typography was the one design axis with no tokens: every size sat inline
/// at its call site. That is how the lane header and the card title ended up
/// 13pt and 14pt at the same weight and the same colour — a difference too
/// small to read as hierarchy, so the two competed instead of ranking.
/// Separation now comes from weight and colour (see `Board.headerStyle`),
/// not from a single point of size.
enum BoardText {
    /// Card title in the working lanes — the board's primary content.
    static let title = Font.system(size: 14, weight: .semibold)
    /// Card title in the single-line lanes, where a row is a list entry
    /// rather than a ticket.
    static let titleCompact = Font.system(size: 13, weight: .medium)
    /// Lane header. Always paired with the secondary foreground: a header
    /// labels content, it is not content.
    static let header = Font.system(size: 13, weight: .semibold)
    /// Running text — notes excerpt, popover copy.
    static let body = Font.system(size: 12)
    /// Chips: date badges, lane counts, dwell time.
    static let chip = Font.system(size: 11, weight: .semibold)
    /// Quiet metadata — list name, "N weitere anzeigen", weekday letters.
    static let meta = Font.system(size: 11)
    /// Inline symbols sitting beside `meta` or `chip` text. Deliberately
    /// smaller than its companion text: a glyph reads at a smaller size than
    /// a letterform does.
    static let glyph = Font.system(size: 9, weight: .semibold)
    /// A single emphasised number — the streak counter.
    static let value = Font.system(size: 12, weight: .semibold)

    /// The streak count at the top of the stats popover — the one number in
    /// the app set large, and the only place SF Pro is departed from.
    ///
    /// Rounded is the face Apple sets numbers in when the number is an
    /// achievement rather than a measurement: Fitness, Activity, Screen Time.
    /// At this size SF Pro's flat terminals read as a spreadsheet cell.
    /// Everything else in the popover stays at reading size, so this carries
    /// the hierarchy on its own and nothing has to compete with it.
    static let heroValue = Font.system(size: 52, weight: .bold, design: .rounded)

    // Tooltip lines. Both 11pt — the rank comes from weight and colour, as
    // everywhere else on this board. The first draft set the lead at 11.5
    // against 11, which is both off the macOS grid (11/12/13) and exactly the
    // half-point distinction this scale exists to prevent.
    //
    // Declared as NSFont because the tooltip measures its own text before
    // drawing it, and a measurement taken in a different font than the one
    // drawn is how text ends up clipped. The SwiftUI faces are derived from
    // these, so the two cannot drift apart.
    static let tooltipLeadFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let tooltipDetailFont = NSFont.systemFont(ofSize: 11)
    static let tooltipLead = Font(tooltipLeadFont)
    static let tooltipDetail = Font(tooltipDetailFont)
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
