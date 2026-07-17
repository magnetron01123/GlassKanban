import SwiftUI

/// One card, styled as a paper sticky note tinted in its Reminders list color.
///
/// Two shapes:
/// - full (Als Nächstes / In Bearbeitung): hero title over two lines, a notes
///   preview, and a due badge when there is one.
/// - compact (Backlog / Erledigt): a single-line row so storage lanes stay
///   dense and the working lanes keep the focus.
struct CardView: View {
    let card: KanbanCard
    var compact = false
    /// The top card of "Als Nächstes" breathes when there is nothing in
    /// progress — a quiet invitation to pull the next task.
    var pullSignal = false

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isHovered = false
    @State private var settleScale: CGFloat = 1
    @State private var settleFlash = false
    @State private var breathe = false

    var body: some View {
        Group {
            if compact { compactBody } else { fullBody }
        }
        .background { surface }
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
        .help("\(card.listName) · Doppelklick öffnet Erinnerungen")
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

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(card.status == .done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .strikethrough(card.status == .done)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            Text(card.notesPreview)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1, reservesSpace: true)

            if let badge = fullBadge {
                badgeView(badge)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactBody: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(card.status == .done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .strikethrough(card.status == .done)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge = compactBadge {
                badgeView(badge)
            }
        }
        .padding(EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayTitle: String {
        card.title.isEmpty ? "Ohne Titel" : card.title
    }

    // MARK: - Surface (sticky note)

    private var surface: some View {
        RoundedRectangle(cornerRadius: Board.cardRadius)
            .fill(cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: Board.cardRadius)
                    .fill(card.listColor.opacity(Board.cardTintOpacity))
            }
    }

    /// Near-opaque "paper" so cards read as physical objects on the recessed
    /// lanes, instead of glass on glass.
    private var cardFill: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
            : AnyShapeStyle(.thickMaterial)
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

    /// Compact cards only surface urgency (overdue / today); everything else
    /// stays quiet to keep storage lanes calm.
    private var compactBadge: BadgeInfo? {
        guard card.status != .done, let due = card.dueDate else { return nil }
        let info = badge(for: due)
        return info.tint == nil ? nil : info
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
