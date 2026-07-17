import SwiftUI

struct BoardView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showStreak = false

    var body: some View {
        HStack(alignment: .top, spacing: Board.columnSpacing) {
            ForEach(KanbanStatus.allCases) { status in
                ColumnView(status: status)
            }
        }
        .frame(maxWidth: Board.boardMaxWidth)
        .frame(maxWidth: .infinity)   // center the board as an object in the window
        .padding(Board.boardPadding)
        .frame(minWidth: Board.boardMinWidth, minHeight: 560)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: store.cards)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                streakPill
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
                remindersButton
            }
        }
    }

    // MARK: - Streak pill + popover

    /// The streak counter, clickable to reveal details. The flame fills as the
    /// day's work gets done (see StreakStats.flameLevel).
    private var streakPill: some View {
        Button {
            showStreak.toggle()
        } label: {
            pillLabel
        }
        .buttonStyle(.plain)
        .help("Streak-Details anzeigen")
        .popover(isPresented: $showStreak, arrowEdge: .bottom) {
            StreakPopover(stats: store.streakStats)
                .frame(width: 260)
        }
    }

    @ViewBuilder
    private var pillLabel: some View {
        let content = HStack(spacing: 4) {
            FlameIcon(level: store.streakStats.flameLevel)
            Text("\(store.streakStats.current)")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)

        if reduceTransparency {
            content.background(.quaternary.opacity(0.6), in: Capsule())
        } else {
            content.glassEffect(in: .capsule)
        }
    }

    // MARK: - Reminders jump

    /// The one prominent, accent-colored control: it makes clear you leave the
    /// board to Reminders (where tasks are created and edited).
    private var remindersButton: some View {
        Button {
            store.openRemindersApp()
        } label: {
            Label("Erinnerungen", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.glassProminent)
        .help("Erinnerungen öffnen, um Aufgaben anzulegen oder zu bearbeiten (⌘N)")
    }

    // MARK: - Filters

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
