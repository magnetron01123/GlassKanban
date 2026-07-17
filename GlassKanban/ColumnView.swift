import SwiftUI

struct ColumnView: View {
    let status: KanbanStatus
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isTargeted = false

    private var cards: [KanbanCard] { store.cards(for: status) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(status.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(cards.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.8), in: Capsule())
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 12))

            // Hairline between header and cards, like a physical label strip.
            Rectangle()
                .fill(Board.columnBorder)
                .frame(height: 1)
                .padding(.horizontal, 10)

            ScrollView {
                LazyVStack(spacing: Board.cardSpacing) {
                    ForEach(cards) { card in
                        CardView(card: card)
                            .draggable(card.id) {
                                // The "picked up" card: slight tilt and a
                                // bigger, softer shadow while dragging.
                                CardView(card: card)
                                    .environmentObject(store)
                                    .frame(width: 240)
                                    .rotationEffect(.degrees(2))
                                    .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                            }
                    }
                    if isTargeted {
                        insertionSlot
                    } else if cards.isEmpty {
                        Text("Keine Karten")
                            .font(.system(size: 12))
                            .foregroundStyle(.quaternary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: Board.columnRadius)
                .fill(columnBackground)
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
                            LinearGradient(
                                colors: [Board.columnInnerShadow, .clear],
                                startPoint: .top, endPoint: .center),
                            lineWidth: 1.5)
                        .blur(radius: 1.5)
                }
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Board.columnRadius)
                .strokeBorder(
                    isTargeted
                        ? AnyShapeStyle(Color.accentColor.opacity(0.7))
                        : AnyShapeStyle(Board.columnBorder),
                    lineWidth: isTargeted ? 1.5 : 1)
        }
        .animation(Board.dropTargetAnimation, value: isTargeted)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            store.move(cardID: id, to: status)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    /// Dashed placeholder marking where the dragged card will land.
    private var insertionSlot: some View {
        RoundedRectangle(cornerRadius: Board.cardRadius)
            .strokeBorder(
                Color.accentColor.opacity(0.35),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .background(
                Color.accentColor.opacity(0.05),
                in: RoundedRectangle(cornerRadius: Board.cardRadius))
            .frame(height: 72)
            .transition(.opacity)
    }

    private var columnBackground: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .underPageBackgroundColor))
            : AnyShapeStyle(Board.columnFill)
    }
}
