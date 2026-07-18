import SwiftUI

/// One card, styled as a paper sticky note tinted in its Reminders list color.
///
/// Three shapes, driven by the lane's information density:
/// - full (Als Nächstes / In Bearbeitung): hero title with priority marks,
///   optional notes preview, and a meta row (due date, recurrence, list).
/// - compact (Backlog): one line with what you need to triage — priority,
///   recurrence, due date.
/// - minimal (Erledigt): the title alone.
struct CardView: View {
    let card: KanbanCard
    /// The top card of "Als Nächstes" breathes when there is nothing in
    /// progress — a quiet invitation to pull the next task.
    var pullSignal = false

    private var density: CardDensity { card.status.cardDensity }

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var isHovered = false
    @State private var settleScale: CGFloat = 1
    @State private var settleFlash = false
    @State private var breathe = false

    var body: some View {
        Group {
            switch density {
            case .full: fullBody
            case .compact: compactBody
            case .minimal: minimalBody
            }
        }
        .background { surface }
        .overlay(alignment: .leading) { listStripe }
        .overlay { contour }
        .overlay { topHighlight }
        .overlay { flashOverlay }
        .shadow(color: contactShadow.color, radius: contactShadow.radius, y: contactShadow.y)
        .shadow(color: Board.cardShadowAmbient.color, radius: Board.cardShadowAmbient.radius, y: Board.cardShadowAmbient.y)
        .shadow(color: pullGlowColor, radius: pullGlowRadius)
        .scaleEffect(settleScale)
        .offset(y: isHovered && !reduceMotion ? -1 : 0)
        .contentShape(RoundedRectangle(cornerRadius: Board.cardRadius))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : Board.hoverAnimation) { isHovered = hovering }
        }
        .onTapGesture(count: 2) { openInReminders() }
        .contextMenu {
            Button("In Erinnerungen öffnen") { openInReminders() }
        }
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "In Erinnerungen öffnen") { openInReminders() }
        .onChange(of: pullSignal) { _, active in updateBreathing(active) }
        .onAppear {
            updateBreathing(pullSignal)
            // The completed card appears fresh in Erledigt with the flag
            // already set, so trigger the settle here rather than on change.
            playSettle(if: store.recentlyCompletedID)
        }
    }

    // MARK: - Layouts

    /// Ticket anatomy in three zones divided by hairlines, like a ruled
    /// index card. The header carries the card's PROCESS state (title, how
    /// long it has been sitting here), the footer carries the TASK's facts
    /// (due date, recurrence, source list) — the two time signals stay in
    /// opposite corners so they can never be confused.
    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                titleText
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                agingLabel
            }
            .padding(EdgeInsets(top: 11, leading: 14, bottom: 9, trailing: 12))

            zoneDivider

            Group {
                if card.notesExcerpt.isEmpty {
                    Spacer(minLength: 8)
                } else {
                    Text(card.notesExcerpt)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            zoneDivider

            HStack(spacing: 6) {
                if let badge = fullBadge {
                    badgeView(badge)
                }
                if card.isRecurring {
                    repeatIcon
                }
                Spacer(minLength: 8)
                // Secondary, not tertiary: on opaque paper the tertiary
                // style washes out to the point of being unreadable.
                Text(card.listName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(EdgeInsets(top: 8, leading: 14, bottom: 9, trailing: 12))
        }
        .frame(
            maxWidth: .infinity,
            minHeight: Board.fullCardMinHeight,
            alignment: .topLeading)
    }

    /// Hairline between ticket zones, inset to the text margin so it reads
    /// as a rule on the card, not a cut through it.
    private var zoneDivider: some View {
        Rectangle()
            .fill(Board.cardBorder)
            .frame(height: 1)
            .padding(.leading, 14)
            .padding(.trailing, 12)
    }

    /// Dwell time, top right in the header: process state, deliberately far
    /// from the due date in the footer.
    @ViewBuilder
    private var agingLabel: some View {
        if let days = card.daysInColumn(), days >= Board.agingThresholdDays {
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text("\(days) Tage")
                    .font(.system(size: 11))
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .help("Seit \(days) Tagen in dieser Spalte")
        }
    }

    /// Backlog: everything needed to decide what to pull next.
    private var compactBody: some View {
        HStack(spacing: 8) {
            titleText
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            if card.isRecurring {
                repeatIcon
            }
            if let badge = compactBadge {
                badgeView(badge)
            }
        }
        .padding(EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Erledigt: the work is done — the name is the only thing left to say.
    private var minimalBody: some View {
        titleText
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .padding(EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Title with Reminders-style priority marks ("!!" ) in front.
    private var titleText: Text {
        let base = Text(displayTitle)
            .foregroundStyle(card.status == .done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .strikethrough(card.status == .done)
        guard let marks = card.priorityMarks, card.status != .done else { return base }
        return Text(marks).foregroundStyle(.orange).bold() + Text(" ") + base
    }

    private var repeatIcon: some View {
        Image(systemName: "repeat")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .help("Wiederholende Erinnerung")
    }

    /// Compact rows have no room for the notes preview, so the tooltip
    /// carries it — information without pixels.
    private var helpText: String {
        var lines: [String] = []
        if density.isSingleLine && !card.notesPreview.isEmpty {
            lines.append(card.notesPreview)
        }
        lines.append("\(card.listName) · Doppelklick öffnet Erinnerungen")
        return lines.joined(separator: "\n")
    }

    private var displayTitle: String {
        card.title.isEmpty ? "Ohne Titel" : card.title
    }

    // MARK: - Surface (sticky note)

    private var surface: some View {
        RoundedRectangle(cornerRadius: Board.cardRadius)
            .fill(cardFill)
    }

    /// Slim list-color marker along the leading edge — the ticket's color
    /// code, inset like a physical tab so it reads as part of the card.
    private var listStripe: some View {
        Capsule()
            .fill(card.listColor.opacity(card.status == .done ? 0.45 : 0.9))
            .frame(width: Board.cardStripeWidth)
            .padding(.vertical, density.isSingleLine ? 7 : 9)
            .padding(.leading, 5)
            .allowsHitTesting(false)
    }

    /// Opaque "paper" so cards read as physical objects on the recessed
    /// lanes — independent of whatever wallpaper shines through the window.
    private var cardFill: Color {
        reduceTransparency
            ? Color(nsColor: .controlBackgroundColor)
            : Board.cardFill(colorScheme)
    }

    private var contour: some View {
        RoundedRectangle(cornerRadius: Board.cardRadius)
            .strokeBorder(Board.cardBorder)
    }

    private var topHighlight: some View {
        RoundedRectangle(cornerRadius: Board.cardRadius)
            .strokeBorder(
                LinearGradient(colors: [Board.cardTopHighlight, .clear], startPoint: .top, endPoint: .center),
                lineWidth: 1)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var flashOverlay: some View {
        RoundedRectangle(cornerRadius: Board.cardRadius)
            .fill(Color.green.opacity(settleFlash ? 0.18 : 0))
            .allowsHitTesting(false)
    }

    private var contactShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        isHovered ? Board.cardShadowHover : Board.cardShadowResting
    }

    private var pullGlowColor: Color {
        pullSignal ? Color.accentColor.opacity(breathe ? 0.5 : 0.12) : .clear
    }

    private var pullGlowRadius: CGFloat {
        pullSignal ? (breathe ? 12 : 5) : 0
    }

    // MARK: - Badges

    private struct BadgeInfo {
        let label: String
        let tint: Color?
    }

    /// Full cards (never Done) show the due date when there is one; the
    /// uninformative "Kein Datum" is deliberately omitted.
    private var fullBadge: BadgeInfo? {
        card.dueDate.map(badge(for:))
    }

    /// Compact cards always carry their date when they have one — essential
    /// in the backlog, where recurring reminders resurface by date. Urgency
    /// still tints, everything else stays a quiet grey.
    private var compactBadge: BadgeInfo? {
        guard card.status != .done, let due = card.dueDate else { return nil }
        return badge(for: due)
    }

    private func badge(for due: Date) -> BadgeInfo {
        let calendar = Calendar.current
        if calendar.isDateInToday(due) {
            return BadgeInfo(label: "Heute", tint: .orange)
        }
        if due < calendar.startOfDay(for: .now) {
            return BadgeInfo(label: "Überfällig", tint: .red)
        }
        if calendar.isDateInTomorrow(due) {
            return BadgeInfo(label: "Morgen", tint: nil)
        }
        return BadgeInfo(label: due.formatted(.dateTime.day().month()), tint: nil)
    }

    private func badgeView(_ info: BadgeInfo) -> some View {
        Text(info.label)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(info.tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                info.tint.map { AnyShapeStyle($0.opacity(0.14)) } ?? AnyShapeStyle(.quaternary.opacity(0.6)),
                in: RoundedRectangle(cornerRadius: Board.badgeRadius))
    }

    // MARK: - Motivation animations

    /// Brief squish-and-settle plus a green flash when this card completes.
    private func playSettle(if id: String?) {
        guard id == card.id, !reduceMotion else { return }
        Task { @MainActor in
            settleScale = 0.94
            settleFlash = true
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(Board.settleAnimation) { settleScale = 1 }
            withAnimation(.easeOut(duration: 0.55)) { settleFlash = false }
        }
    }

    private func updateBreathing(_ active: Bool) {
        guard !reduceMotion else {
            breathe = false
            return
        }
        if active {
            withAnimation(Board.pullBreath) { breathe = true }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { breathe = false }
        }
    }

    // MARK: - Actions

    /// Editing happens in the Reminders app (the board is read-only apart from
    /// drag & drop). Deep link to this reminder; if none resolves, at least
    /// bring Reminders to the front.
    private func openInReminders() {
        if let url = store.deepLinkURL(forCardID: card.id),
           NSWorkspace.shared.open(url) {
            return
        }
        store.openRemindersApp()
    }
}
