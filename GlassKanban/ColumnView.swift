import SwiftUI

struct ColumnView: View {
    let status: KanbanStatus
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var isTargeted = false
    @State private var expanded = false

    private var cards: [KanbanCard] { store.cards(for: status) }
    private var compact: Bool { status.usesCompactCards }

    /// Backlog can be huge, so it shows a capped stack with "N weitere".
    private var displayedCards: [KanbanCard] {
        guard status == .backlog, !expanded, cards.count > Board.backlogCollapsedLimit else {
            return cards
        }
        return Array(cards.prefix(Board.backlogCollapsedLimit))
    }

    private var hiddenCount: Int { cards.count - displayedCards.count }

    /// Pull invitation: nothing in progress but something queued up next.
    private var pullActive: Bool {
        status == .next && store.cards(for: .inProgress).isEmpty && !cards.isEmpty
    }

    /// Completions done today, for the Erledigt header hint.
    private var todayCount: Int {
        let calendar = Calendar.current
        return cards.filter { $0.completionDate.map(calendar.isDateInToday) ?? false }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Hairline between header and cards, like a physical label strip.
            Rectangle()
                .fill(Board.columnBorder)
                .frame(height: 1)
                .padding(.horizontal, 10)

            ScrollView {
                LazyVStack(spacing: compact ? 5 : Board.cardSpacing) {
                    ForEach(Array(displayedCards.enumerated()), id: \.element.id) { index, card in
                        // No custom drag preview: SwiftUI rasterizes preview
                        // closures into a bitmap, which turned rotation and
                        // material fills into a pixelated snapshot. The
                        // system's native lift preview renders the card
                        // itself crisply and adds its own depth; the
                        // drag-preview content shape rounds its corners so
                        // no rectangular snapshot edge shows behind them.
                        CardView(card: card, compact: compact, pullSignal: pullActive && index == 0)
                            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: Board.cardRadius))
                            .draggable(card.id)
                    }

                    if isTargeted {
                        insertionSlot
                    } else if cards.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .mask(scrollFade)

            if status == .backlog, hiddenCount > 0, !expanded {
                moreButton
            }
        }
        .frame(
            minWidth: Board.columnMinWidth,
            maxWidth: compact ? Board.storageColumnMaxWidth : Board.workColumnMaxWidth,
            maxHeight: .infinity,
            alignment: .top)
        .background { columnSurface }
        .overlay { columnContour }
        .animation(Board.dropTargetAnimation, value: isTargeted)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            let changed = store.move(cardID: id, to: status)
            if changed { Haptics.drop() }
            return changed
        } isTargeted: { targeted in
            if targeted && !isTargeted { Haptics.alignmentTick() }
            isTargeted = targeted
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(status.displayName)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            // Erledigt counts today's completions ("2 · heute 1") as a quiet
            // progress hint; a bare "0 heute" next to visible cards read as
            // a bug, so the total always leads.
            Text(status == .done && todayCount > 0 ? "\(cards.count) · heute \(todayCount)" : "\(cards.count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.8), in: Capsule())
                .help(status == .done ? "\(todayCount) heute erledigt · \(cards.count) sichtbar" : "\(cards.count) Karten")
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 12))
    }

    // MARK: - Pieces

    /// Dashed placeholder marking where the dragged card will land.
    private var insertionSlot: some View {
        RoundedRectangle(cornerRadius: Board.cardRadius)
            .strokeBorder(
                Color.accentColor.opacity(0.35),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .background(
                Color.accentColor.opacity(0.05),
                in: RoundedRectangle(cornerRadius: Board.cardRadius))
            .frame(height: compact ? 34 : 72)
            .transition(.opacity)
    }

    private var emptyState: some View {
        Text("Keine Karten")
            .font(.system(size: 12))
            .foregroundStyle(.quaternary)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
    }

    private var moreButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { expanded = true }
        } label: {
            Text("\(hiddenCount) weitere anzeigen")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    /// Cards fade out at the bottom edge, hinting there is more to scroll
    /// without a hard cut-off.
    private var scrollFade: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 14)
        }
    }

    // MARK: - Recessed lane surface

    private var columnSurface: some View {
        RoundedRectangle(cornerRadius: Board.columnRadius)
            .fill(columnFill)
            .overlay {
                // Accent wash while a drag hovers over the lane.
                RoundedRectangle(cornerRadius: Board.columnRadius)
                    .fill(Color.accentColor.opacity(isTargeted ? 0.07 : 0))
            }
            .overlay {
                // Inner top shadow: the lane is carved into the board.
                RoundedRectangle(cornerRadius: Board.columnRadius)
                    .inset(by: 0.5)
                    .strokeBorder(
                        LinearGradient(colors: [Board.columnInnerShadow, .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 1.5)
                    .blur(radius: 1.5)
            }
            .allowsHitTesting(false)
    }

    private var columnContour: some View {
        RoundedRectangle(cornerRadius: Board.columnRadius)
            .strokeBorder(
                isTargeted
                    ? AnyShapeStyle(Color.accentColor.opacity(0.7))
                    : AnyShapeStyle(Board.columnBorder),
                lineWidth: isTargeted ? 1.5 : 1)
    }

    private var columnFill: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .underPageBackgroundColor))
            : AnyShapeStyle(Board.columnFill(colorScheme))
    }
}
