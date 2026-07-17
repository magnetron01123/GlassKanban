import SwiftUI

struct BoardView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(KanbanStatus.allCases) { status in
                ColumnView(status: status)
            }
        }
        .padding(12)
        .frame(minWidth: 960, minHeight: 560)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: store.cards)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuoteBar()
        }
        .toolbar {
            if store.streak > 0 {
                ToolbarItem(placement: .navigation) {
                    Text("🔥 \(store.streak)")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .help("\(store.streak) Tage in Folge mindestens eine Aufgabe erledigt")
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
            .italic()
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
    }
}
