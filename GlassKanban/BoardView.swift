import SwiftUI

struct BoardView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showStreak = false
    @State private var showFind = false

    var body: some View {
        HStack(alignment: .top, spacing: Board.columnSpacing) {
            ForEach(KanbanStatus.allCases) { status in
                ColumnView(status: status)
            }
        }
        // Lanes flex between ticket-friendly bounds; the whole block sits
        // centered in the window like a board mounted on a wall.
        .frame(maxWidth: .infinity)
        .padding(Board.boardPadding)
        .frame(minWidth: Board.boardMinWidth, minHeight: 560)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: store.cards)
        .toolbar {
            // Only shown once there is a streak — a "0" pill next to the
            // window controls just looks broken.
            if store.streakStats.current > 0 {
                ToolbarItem(placement: .navigation) {
                    streakPill
                }
            }
            // Two separate glass groups, not one: narrowing the view down and
            // leaving for Reminders are different jobs, and sharing a capsule
            // would dilute the one deliberately prominent button on the board.
            ToolbarItem(placement: .primaryAction) {
                findButton
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                remindersButton
            }
        }
        // The window paints its own always-active glass edge to edge (see
        // WindowGlass); an opaque toolbar strip on top would cut a flat band
        // across it. The toolbar items keep their own Liquid Glass.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    // MARK: - Streak pill + popover

    /// The streak counter, clickable to reveal details. The flame fills as the
    /// day's work gets done (see StreakStats.flameLevel). No custom background:
    /// the macOS 26 toolbar already wraps its items in Liquid Glass, and glass
    /// inside glass renders as a boxed artifact.
    private var streakPill: some View {
        Button {
            showStreak.toggle()
        } label: {
            HStack(spacing: 4) {
                FlameIcon(level: store.streakStats.flameLevel)
                Text("\(store.streakStats.current)")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 2)
        }
        .help("Tage nacheinander mit mindestens einer erledigten Aufgabe")
        .popover(isPresented: $showStreak, arrowEdge: .bottom) {
            StreakPopover(stats: store.streakStats)
                .frame(width: 260)
        }
    }

    // MARK: - Find

    /// Search, urgency and due date are one job for the user — "find a ticket" —
    /// so they share one control instead of three pieces of chrome. At rest it
    /// is a single glyph; everything else lives in a popover, which floats
    /// above the board rather than pushing it down: this window is meant to
    /// stand still all day, and a bar sliding in would move every card.
    private var findButton: some View {
        Button {
            showFind.toggle()
        } label: {
            Label("Finden", systemImage: "magnifyingglass")
                .symbolVariant(store.isFiltering ? .fill : .none)
        }
        .keyboardShortcut("f")
        // A board must never be filtered without saying so, or cards look lost
        // rather than hidden. The glyph carries that state even when closed.
        .tint(store.isFiltering ? Color.accentColor : nil)
        .help(store.isFiltering
            ? "Board ist gefiltert — \(store.activeRestrictionCount) aktiv (⌘F)"
            : "Aufgabe finden (⌘F)")
        .popover(isPresented: $showFind, arrowEdge: .bottom) {
            FindPopover()
                .environmentObject(store)
        }
    }

    // MARK: - Reminders jump

    /// The one prominent control on the board. It carries Reminders' own app
    /// icon: no wording identifies another app as unmistakably as its icon,
    /// and the trailing arrow says you are leaving this window.
    private var remindersButton: some View {
        Button {
            store.openRemindersApp()
        } label: {
            HStack(spacing: 5) {
                if let icon = Self.remindersAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 15, height: 15)
                }
                Text("Erinnerungen")
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.glass)
        .help("Apple Erinnerungen öffnen, um Aufgaben anzulegen oder zu bearbeiten (⌘N)")
    }

    /// The real Reminders icon, read from the installed app once.
    private static let remindersAppIcon: NSImage? = {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.reminders") else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }()

}
