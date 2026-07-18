import SwiftUI

struct ColumnView: View {
    let status: KanbanStatus
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var isTargeted = false
    @State private var expanded = false
    /// Height of a real card in this lane, so the drop placeholder can match
    /// it exactly instead of guessing at a constant.
    @State private var cardHeight: CGFloat?

    private var cards: [KanbanCard] { store.cards(for: status) }
    private var singleLine: Bool { status.cardDensity.isSingleLine }

    /// Backlog can be huge, so it shows a capped stack with "N weitere".
    private var displayedCards: [KanbanCard] {
        guard status == .backlog, !expanded, cards.count > Board.backlogCollapsedLimit else {
            return cards
        }
        return Array(cards.prefix(Board.backlogCollapsedLimit))
    }

    private var hiddenCount: Int { cards.count - displayedCards.count }

    /// True while a card from this very lane is being dragged. Dropping it
    /// back here changes nothing, so the lane must not promise a landing
    /// spot it will not honour.
    private var isDragSource: Bool {
        guard let draggingID = store.draggingCardID else { return false }
        return cards.contains { $0.id == draggingID }
    }

    /// Only lanes that would actually receive the card light up.
    private var showsDropFeedback: Bool { isTargeted && !isDragSource }

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
                .padding(.horizontal, Board.laneMargin)

            ScrollView {
                LazyVStack(spacing: singleLine ? 5 : Board.cardSpacing) {
                    ForEach(Array(displayedCards.enumerated()), id: \.element.id) { index, card in
                        // No custom drag preview: SwiftUI rasterizes preview
                        // closures into a bitmap, which turned rotation and
                        // material fills into a pixelated snapshot. The
                        // system's native lift preview renders the card
                        // itself crisply and adds its own depth; the
                        // drag-preview content shape rounds its corners so
                        // no rectangular snapshot edge shows behind them.
                        CardView(card: card, pullSignal: pullActive && index == 0)
                            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: Board.cardRadius))
                            .draggable(card.id)
                            // Runs alongside the system drag purely to note
                            // which card is moving. Deliberately additive:
                            // if it ever stops firing, dragging still works.
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 6)
                                    .onChanged { _ in store.beginDrag(cardID: card.id) }
                                    .onEnded { _ in store.endDrag() })
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                if index == 0 { cardHeight = height }
                            }
                            // A card arriving in a lane settles into place
                            // instead of blinking on: it grows the last few
                            // percent into the shape this lane gives it.
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.93).combined(with: .opacity),
                                removal: .opacity))
                    }

                    if showsDropFeedback {
                        insertionSlot
                    }
                }
                .padding(.horizontal, Board.laneMargin)
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
            maxWidth: Board.columnMaxWidth,
            maxHeight: .infinity,
            alignment: .top)
        .background { columnSurface }
        .overlay { columnContour }
        .animation(Board.dropTargetAnimation, value: showsDropFeedback)
        .dropDestination(for: String.self) { ids, _ in
            store.endDrag()
            guard let id = ids.first else { return false }
            let changed = store.move(cardID: id, to: status)
            if changed { Haptics.drop() }
            return changed
        } isTargeted: { targeted in
            // No tick for the lane the card came from — nothing snaps there.
            if targeted && !isTargeted && !isDragSource { Haptics.alignmentTick() }
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
        .padding(EdgeInsets(top: 12, leading: Board.laneMargin, bottom: 10, trailing: Board.laneMargin))
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
            .frame(height: slotHeight)
            .transition(.opacity)
    }

    /// Matches a real card in this lane; falls back to the lane's own card
    /// metrics while the lane is still empty.
    private var slotHeight: CGFloat {
        cardHeight ?? (singleLine ? Board.compactCardHeight : Board.fullCardMinHeight)
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
        .buttonStyle(.glass)
        .padding(.horizontal, Board.laneMargin)
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
                    .fill(Color.accentColor.opacity(showsDropFeedback ? 0.07 : 0))
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
                showsDropFeedback
                    ? AnyShapeStyle(Color.accentColor.opacity(0.7))
                    : AnyShapeStyle(Board.columnBorder),
                lineWidth: showsDropFeedback ? 1.5 : 1)
    }

    private var columnFill: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .underPageBackgroundColor))
            : AnyShapeStyle(Board.columnFill(colorScheme))
    }
}
