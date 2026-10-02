import SwiftUI

/// The pieces a ticket is drawn from, shared by the board's `CardView` and
/// the menu bar tray's `TrayCardView`.
///
/// The tray draws the same anatomy as the board — priority marks, title, date
/// badge, repeat glyph, list stripe, the strike through a finished title — but
/// not the same *card*: `CardView` also carries renaming, the editor, delete,
/// tooltips and the settle animations, none of which exist in the tray. Rather
/// than a second copy of the anatomy that drifts on the next edit, the pieces
/// live here and both surfaces assemble them.
enum CardParts {

    // MARK: - Text

    static func displayTitle(of card: KanbanCard) -> String {
        card.title.isEmpty ? String(localized: "Untitled") : card.title
    }

    /// Title with Reminders-style priority marks ("!!") in front. The marks
    /// are neutral on purpose: their count already encodes priority, and
    /// colouring them would spend orange — which on this board means "due
    /// today" — on a second, unrelated meaning.
    ///
    /// No `.strikethrough`: a done title's line is drawn as a shape so that
    /// completing it can animate (see `CardStrikeLine`). Full-strength colour
    /// even when done — the strike already marks completion, and dimming the
    /// text on top of it was a second signal for the same fact.
    static func titleText(for card: KanbanCard) -> Text {
        let base = Text(displayTitle(of: card)).foregroundStyle(.primary)
        guard let marks = card.priorityMarks, card.status != .done else { return base }
        // Interpolation rather than `+`: concatenating Text is deprecated as
        // of macOS 26 and each run keeps its own styling this way.
        let marksText = Text(marks).foregroundStyle(.secondary).bold()
        return Text("\(marksText) \(base)")
    }

    static func priorityDescription(of card: KanbanCard) -> String? {
        switch card.priority {
        case 1...4: String(localized: "High priority")
        case 5: String(localized: "Medium priority")
        case 6...9: String(localized: "Low priority")
        default: nil
        }
    }

    /// Built explicitly rather than left to `children: .combine`. Combining
    /// reads the priority marks as punctuation ("exclamation exclamation"),
    /// never mentions that a card is done — strikethrough carries no
    /// semantics — and reduces the list colour, which is the only channel
    /// carrying the source list on compact rows, to nothing at all.
    /// The lane itself is announced by the column's accessibility container.
    /// Joined as sentences, not a comma list: VoiceOver pauses at a full
    /// stop, and the parts are built to stand alone (CONCEPT.md, "Ton der
    /// Texte", rule 7).
    static func accessibilityLabel(for card: KanbanCard) -> String {
        var parts: [String] = []
        if card.status == .done {
            parts.append(String(localized: "Done"))
        }
        if let priority = priorityDescription(of: card) {
            parts.append(priority)
        }
        parts.append(displayTitle(of: card))
        // A finished card is not overdue, whatever its date says; the badge
        // leaves Done for the same reason (`compactBadge`).
        if card.status != .done, let due = card.dueDate {
            parts.append(spokenDue(due))
        }
        if card.isRecurring {
            parts.append(String(localized: "Repeats"))
        }
        parts.append(String(localized: "List \(card.listName)"))
        if CardOutline.hasSizeTab(card), let size = card.size {
            parts.append(String(localized: "Size \(size.letter)"))
        }
        // Only where the card itself shows it. Read out on every backlog and
        // done card, "In this column for 66 days" was a standing charge the
        // eye never sees (CONCEPT.md, "Belohnen, nie bestrafen").
        if card.status.cardDensity == .full,
           let days = card.daysInColumn(), days >= Board.agingThresholdDays {
            parts.append(String(localized: "In this column for \(days) days"))
        }
        return parts.joined(separator: ". ")
    }

    /// The badge's word read on its own is a fragment, and "Due" in front of
    /// it made it wrong: VoiceOver said "Due Overdue" and "Fällig Überfällig"
    /// (measured 28.09.2026). Overdue already says it; today and tomorrow
    /// need their own word order in German ("Heute fällig").
    private static func spokenDue(_ due: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(due) { return String(localized: "Due today") }
        if due < calendar.startOfDay(for: .now) { return String(localized: "Overdue") }
        if calendar.isDateInTomorrow(due) { return String(localized: "Due tomorrow") }
        return String(localized: "Due \(badge(for: due).label)")
    }

    // MARK: - Badges

    struct BadgeInfo {
        let label: String
        let tint: Color?
        /// Solid fill instead of a tint. Reserved for overdue — the one
        /// state that has already failed and should catch the eye from
        /// across the room. Everything else stays quiet.
        var isEmphasized = false
    }

    static func badge(for due: Date) -> BadgeInfo {
        let calendar = Calendar.current
        if calendar.isDateInToday(due) {
            return BadgeInfo(label: String(localized: "Today"), tint: .orange)
        }
        if due < calendar.startOfDay(for: .now) {
            return BadgeInfo(label: String(localized: "Overdue"), tint: .red, isEmphasized: true)
        }
        if calendar.isDateInTomorrow(due) {
            return BadgeInfo(label: String(localized: "Tomorrow"), tint: nil)
        }
        return BadgeInfo(label: due.formatted(.dateTime.day().month()), tint: nil)
    }

    /// Full cards (never Done) show the due date when there is one; the
    /// uninformative "Kein Datum" is deliberately omitted.
    static func fullBadge(for card: KanbanCard) -> BadgeInfo? {
        card.dueDate.map(badge(for:))
    }

    /// Compact cards always carry their date when they have one — essential
    /// in the backlog, where recurring reminders resurface by date. Urgency
    /// still tints, everything else stays a quiet grey.
    static func compactBadge(for card: KanbanCard) -> BadgeInfo? {
        guard card.status != .done, let due = card.dueDate else { return nil }
        return badge(for: due)
    }

    // MARK: - Surface

    /// Reminders list colours are chosen by the user and some are very light —
    /// a pale yellow stripe vanishes on white paper, and the stripe is the only
    /// channel carrying the source list on compact rows. Mixing in a little
    /// label colour keeps every list distinguishable without shifting its hue:
    /// `labelColor` is near-black in light mode and near-white in dark, so the
    /// stripe moves away from the card's own fill in both.
    static func stripeColor(of card: KanbanCard) -> Color {
        card.listColor.mix(with: Color(nsColor: .labelColor), by: 0.18)
    }
}

/// Three weights, so urgency reads at a glance: solid (overdue), tinted
/// (today), quiet grey (everything else).
struct CardBadgeView: View {
    let info: CardParts.BadgeInfo
    @Environment(\.boardScale) private var scale

    var body: some View {
        Text(info.label)
            .font(BoardText.chip(scale))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .padding(.horizontal, 7 * scale)
            .padding(.vertical, 3 * scale)
            .background(background, in: Board.chipShape)
    }

    /// The tint colours the capsule, never the label. System orange as 11pt
    /// text on white paper measures ~2.2:1, well under the 4.5:1 minimum —
    /// and Apple never uses it that way either: in Reminders and Calendar
    /// orange is always a plane or a glyph.
    private var foreground: AnyShapeStyle {
        if info.isEmphasized { return AnyShapeStyle(.white) }
        return info.tint == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    private var background: AnyShapeStyle {
        guard let tint = info.tint else { return AnyShapeStyle(.quaternary.opacity(Board.chipFill)) }
        if info.isEmphasized { return AnyShapeStyle(Board.overdueFill) }
        return AnyShapeStyle(tint.opacity(Board.badgeTintFill))
    }
}

struct CardRepeatIcon: View {
    @Environment(\.boardScale) private var scale

    var body: some View {
        Image(systemName: "repeat")
            .font(BoardText.glyph(scale))
            .foregroundStyle(.secondary)
    }
}

/// A card's T-shirt size, as a clear index tab clipped onto its trailing edge
/// (CONCEPT.md, "T-Shirt-Größen"). The card places it; this is only the tab.
///
/// Translucent, so the card's edge runs on visibly underneath — that is what
/// makes it read as a tab gripping the card rather than a sticker on it. It
/// is the one see-through thing that touches a card, a deliberate and
/// narrowed exception to "glass is chrome, never content": the tab is an
/// accessory on the card's edge, not a surface content stands on, and what
/// lies under it is opaque paper and the lane, not the wallpaper whose
/// brightness made glass cards fail. Why it is drawn instead of using a
/// system material: see `Board.sizeTabFill`.
///
/// "Reduce transparency" turns it into card paper, the same solid fallback
/// every other translucent surface of the board takes.
struct CardSizeTab: View {
    let size: TicketSize

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.boardScale) private var scale

    var body: some View {
        let shape = Board.sizeTabShape(scale)
        let shadow = Board.sizeTabShadow(colorScheme)
        return Text(size.letter)
            .font(BoardText.sizeTab(scale))
            // Primary, against the board's own two-rank rule (a size only
            // *describes* the ticket, see `BoardText`). Tried secondary first
            // and it failed on legibility: one grey letter on a pale tab is
            // not readable from where the board is looked at (01.10.2026).
            .foregroundStyle(.primary)
            // Changing S to M swaps only the letter; the tab itself stays.
            .contentTransition(.opacity)
            .frame(width: Board.sizeTabSide * scale, height: Board.sizeTabSide * scale)
            .background {
                shape
                    .fill(reduceTransparency ? Board.cardFill(colorScheme) : Board.sizeTabFill(colorScheme))
                    .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
            }
            .overlay {
                if reduceTransparency && contrast != .increased {
                    shape.strokeBorder(Board.cardBorder(contrast), lineWidth: 1)
                } else {
                    shape.strokeBorder(Board.sizeTabRim(colorScheme, contrast), lineWidth: 1)
                }
            }
            .accessibilityHidden(true)
    }
}

/// The card's silhouette including its size tab — what a click hits and what
/// a drag lifts. With the bare card shape the half of the tab that stands out
/// past the edge was dead to the pointer and cut off the lifted card.
struct CardOutline: Shape {
    let hasSizeTab: Bool
    /// The board's display size; the outline grows with the card.
    var scale: CGFloat = 1
    /// How far the card's own edge sits inside `rect` on the trailing side —
    /// non-zero where the frame was widened to hold the tab (the drag
    /// preview, see `ColumnView`).
    var trailingInset: CGFloat = 0

    /// Done cards say only their name, so they carry no tab.
    static func hasSizeTab(_ card: KanbanCard) -> Bool {
        card.size != nil && card.status != .done
    }

    func path(in rect: CGRect) -> Path {
        var rect = rect
        rect.size.width -= trailingInset
        var path = Board.cardShape(scale).path(in: rect)
        if hasSizeTab {
            let tab = CGRect(
                x: rect.maxX - Board.sizeTabOverhang * scale,
                y: rect.minY + Board.sizeTabTop * scale,
                width: Board.sizeTabSide * scale, height: Board.sizeTabSide * scale)
            path.addPath(Board.sizeTabShape(scale).path(in: tab))
        }
        return path
    }
}

/// Slim list-color marker along the leading edge — the ticket's color
/// code, inset like a physical tab so it reads as part of the card.
struct CardListStripe: View {
    let card: KanbanCard
    let isSingleLine: Bool
    @Environment(\.boardScale) private var scale

    /// The width stays put at every display size: a colour code reads by
    /// its hue, and a fatter bar would start to look like a border. Where it
    /// sits grows with the card, so it keeps its place on the paper.
    var body: some View {
        Capsule()
            .fill(CardParts.stripeColor(of: card).opacity(card.status == .done ? 0.45 : 0.9))
            .frame(width: Board.cardStripeWidth)
            .padding(.vertical, (isSingleLine ? 7 : 9) * scale)
            .padding(.leading, 5 * scale)
            .allowsHitTesting(false)
    }
}

/// The done title's strike, drawn by the board instead of by
/// `Text.strikethrough` — because on the board the completion reward *is*
/// this line being drawn. On a settled card it simply sits there at full
/// width, indistinguishable from the text attribute it replaces; on a card
/// that just completed it starts at zero and sweeps left to right. Scaled
/// rather than measured: `scaleEffect(x:anchor:)` animates the sweep without
/// a GeometryReader, and a 1pt line has no content to distort.
///
/// The tray always passes 1: the sweep is the board's reward for finishing,
/// and the board is where it plays.
struct CardStrikeLine: View {
    var progress: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(.secondary)
            .frame(height: 1)
            .scaleEffect(x: progress, anchor: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
