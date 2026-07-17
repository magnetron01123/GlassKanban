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
                    .background(.quaternary.opacity(0.6), in: Capsule())
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 12))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(cards) { card in
                        CardView(card: card)
                            .draggable(card.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(columnBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary.opacity(0.06)),
                    lineWidth: isTargeted ? 2 : 1)
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            store.move(cardID: id, to: status)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private var columnBackground: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .underPageBackgroundColor))
            : AnyShapeStyle(.ultraThinMaterial)
    }
}
