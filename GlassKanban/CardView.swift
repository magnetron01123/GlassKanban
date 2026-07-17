import SwiftUI

/// One card. Fixed height regardless of content: the title always reserves
/// two lines, the notes preview always reserves one (spec: uniform cards).
struct CardView: View {
    let card: KanbanCard
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title.isEmpty ? "Ohne Titel" : card.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(card.status == .done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .strikethrough(card.status == .done)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            Text(card.notesPreview)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1, reservesSpace: true)

            HStack(spacing: 6) {
                dueBadge
                Spacer(minLength: 0)
                Circle()
                    .fill(card.listColor)
                    .frame(width: 8, height: 8)
                    .help(card.listName)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: Board.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Board.cardRadius)
                .strokeBorder(Board.cardBorder)
        }
        .overlay {
            // Paper edge catching light along the top.
            RoundedRectangle(cornerRadius: Board.cardRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [Board.cardTopHighlight, .clear],
                        startPoint: .top, endPoint: .center),
                    lineWidth: 1)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .shadow(color: contactShadow.color, radius: contactShadow.radius, y: contactShadow.y)
        .shadow(
            color: Board.cardShadowAmbient.color,
            radius: Board.cardShadowAmbient.radius,
            y: Board.cardShadowAmbient.y)
        .offset(y: isHovered && !reduceMotion ? -1 : 0)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : Board.hoverAnimation) {
                isHovered = hovering
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Board.cardRadius))
        .onTapGesture(count: 2) {
            openInReminders()
        }
        .contextMenu {
            Button("In Erinnerungen öffnen") {
                openInReminders()
            }
        }
        .help("Doppelklick: in Erinnerungen öffnen")
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "In Erinnerungen öffnen") {
            openInReminders()
        }
    }

    /// Editing happens in the Reminders app (spec: the board is read-only
    /// apart from drag & drop). Deep link to this reminder; if no link can
    /// be resolved, at least bring Reminders to the front.
    private func openInReminders() {
        if let url = store.deepLinkURL(forCardID: card.id),
           NSWorkspace.shared.open(url) {
            return
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Near-opaque "paper" fill so cards read as physical objects on the
    /// recessed column lanes, instead of glass on glass.
    private var cardBackground: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
            : AnyShapeStyle(.thickMaterial)
    }

    private var contactShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        isHovered ? Board.cardShadowHover : Board.cardShadowResting
    }

    private var dueBadge: some View {
        let info = dueInfo
        return Text(info.label)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(info.tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                info.tint.map { AnyShapeStyle($0.opacity(0.14)) } ?? AnyShapeStyle(.quaternary.opacity(0.6)),
                in: RoundedRectangle(cornerRadius: Board.badgeRadius))
    }

    private var dueInfo: (label: String, tint: Color?) {
        if card.status == .done {
            return ("Erledigt", nil)
        }
        guard let due = card.dueDate else {
            return ("Kein Datum", nil)
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(due) {
            return ("Heute", .orange)
        }
        if due < calendar.startOfDay(for: .now) {
            return ("Überfällig", .red)
        }
        if calendar.isDateInTomorrow(due) {
            return ("Morgen", nil)
        }
        return (due.formatted(.dateTime.day().month()), nil)
    }
}
