import SwiftUI

struct BoardView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .top, spacing: Board.columnSpacing) {
            ForEach(KanbanStatus.allCases) { status in
                ColumnView(status: status)
            }
        }
        .padding(Board.boardPadding)
        .frame(minWidth: 960, minHeight: 560)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: store.cards)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuoteBar()
        }
        .toolbar {
            if store.streak > 0 {
                ToolbarItem(placement: .navigation) {
                    streakPill
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                filterMenu(
                    title: "Dringlichkeit",
                    systemImage: "flag",
                    selection: $store.priorityFilter,
                    isActive: store.priorityFilter != .all)
                filterMenu(
                    title: "Fälligkeit",
                    systemImage: "calendar",
                    selection: $store.dueFilter,
                    isActive: store.dueFilter != .all)
            }
        }
    }

    /// Streak counter as a small glass capsule — the one place where Liquid
    /// Glass is appropriate (control layer, not content).
    @ViewBuilder
    private var streakPill: some View {
        let label = HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange.gradient)
            Text("\(store.streak)")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)

        Group {
            if reduceTransparency {
                label.background(.quaternary.opacity(0.6), in: Capsule())
            } else {
                label.glassEffect(in: .capsule)
            }
        }
        .help("\(store.streak) Tage in Folge mindestens eine Aufgabe erledigt")
    }

    private func filterMenu<F: CaseIterable & Identifiable & Hashable>(
        title: String,
        systemImage: String,
        selection: Binding<F>,
        isActive: Bool
    ) -> some View where F.AllCases: RandomAccessCollection, F: FilterDisplayable {
        Menu {
            Picker(title, selection: selection) {
                ForEach(F.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(title, systemImage: systemImage)
                .symbolVariant(isActive ? .fill : .none)
        }
        .help(isActive ? "\(title): gefiltert" : "\(title): alle anzeigen")
    }
}

/// Small protocol so both filter enums share one toolbar menu builder.
protocol FilterDisplayable {
    var displayName: String { get }
}

extension PriorityFilter: FilterDisplayable {}
extension DueFilter: FilterDisplayable {}

struct QuoteBar: View {
    var body: some View {
        Text(Quotes.quote())
            .font(.system(size: 12))
            .fontDesign(.serif)
            .italic()
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
    }
}
