import SwiftUI

struct BoardView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showStreak = false
    @State private var showFind = false

    var body: some View {
        // Wraps the lanes, not the window: the tooltip has to escape the
        // ScrollView that clips each lane's cards, but must still be drawn
        // inside the board so it is positioned against the board's own bounds.
        TooltipHost {
            board
        }
        .environment(\.boardTooltipsSuppressed, store.draggingCardID != nil)
    }

    private var board: some View {
        HStack(alignment: .top, spacing: Board.columnSpacing) {
            ForEach(KanbanStatus.allCases) { status in
                ColumnView(status: status)
            }
        }
        // Four wordless empty lanes read as a broken app. Individual lanes stay
        // silent — only the whole board being blank is worth a sentence, and
        // then exactly one, laid over the lanes rather than inside them.
        .overlay {
            if let emptiness = store.emptiness {
                EmptyBoardNotice(emptiness: emptiness) {
                    store.resetFilters()
                }
            }
        }
        // Lanes flex between ticket-friendly bounds; the whole block sits
        // centered in the window like a board mounted on a wall.
        .frame(maxWidth: .infinity)
        .padding(Board.boardPadding)
        .frame(minWidth: Board.boardMinWidth, minHeight: 560)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: store.cards)
        .toolbar {
            // Shown as soon as there is any history at all — not just during
            // a live streak. The pill is the only way into the statistics, and
            // a broken streak must not also lock away everything else. At
            // streak 0 it shows the grey flame alone: a "0" beside the window
            // controls looks broken, and reads as a reprimand besides.
            if store.wrappedStats.totalCompleted > 0 {
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
        // Deliberately NOT `.toolbarBackgroundVisibility(.hidden, …)`.
        //
        // Hiding the toolbar's shared background does not make the toolbar
        // disappear — it takes away the surface the items sit on, so every
        // item falls back to carrying its own Liquid Glass capsule. Compared
        // side by side with Safari, whose toolbar buttons are bare glyphs at
        // rest, that read as two raised plates floating over the board.
        //
        // The band this was written to avoid does not appear: on macOS 26 the
        // toolbar background is the scroll edge effect, transparent until
        // content scrolls under it, and this board never scrolls at window
        // level — its lanes scroll individually.
        // One alert for the whole board, driven by the store, so it fires for
        // every route into a move — drag, context menu, VoiceOver action.
        .alert(overflowTitle, isPresented: overflowBinding, presenting: store.pendingOverflow) { overflow in
            // Every easy way out of this dialog respects the limit: the safe
            // action is the prominent one, carries Return, and — via the
            // cancel role — Escape too. Overloading takes a deliberate click.
            Button("Erst abschließen", role: .cancel) {
                store.move(cardID: overflow.cardID, to: overflow.origin)
            }
            .keyboardShortcut(.defaultAction)
            // "Passt schon" rather than "Trotzdem": the board does not get to
            // decide that the user is wrong about their own capacity.
            Button("Passt schon") {}
        } message: { _ in
            // The Kanban idea in four words, no jargon and no lecture — then
            // an offer, not an instruction.
            Text("Weniger gleichzeitig, mehr fertig. Erst etwas abschließen?")
        }
    }

    private var overflowBinding: Binding<Bool> {
        Binding(
            get: { store.pendingOverflow != nil },
            set: { if !$0 { store.pendingOverflow = nil } })
    }

    private var overflowTitle: String {
        guard let overflow = store.pendingOverflow else { return "" }
        guard let limit = store.wipLimit(for: overflow.status) else {
            return overflow.status.displayName
        }
        return "\(overflow.status.displayName): \(store.cards(for: overflow.status).count) von \(limit)"
    }

    // MARK: - Streak pill + popover

    /// The streak counter, clickable to reveal the statistics. The flame fills
    /// as the day's work gets done (see StreakStats.flameLevel). No custom
    /// background: the macOS 26 toolbar already wraps its items in Liquid
    /// Glass, and glass inside glass renders as a boxed artifact. Every item
    /// in this toolbar obeys that rule — see `remindersButton` for what
    /// happens when one does not.
    private var streakPill: some View {
        Button {
            showStreak.toggle()
        } label: {
            HStack(spacing: 4) {
                FlameIcon(level: store.streakStats.flameLevel)
                // The count disappears at 0 rather than showing one, leaving
                // the flame as the button. See the toolbar's visibility rule.
                if store.streakStats.current > 0 {
                    Text("\(store.streakStats.current)")
                        .font(BoardText.value)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 2)
        }
        // A bare number plus a decorative flame announces as "1" — true and
        // useless. The label says what the number counts.
        .accessibilityLabel(streakPillLabel)
        .help("Statistiken")
        .popover(isPresented: $showStreak, arrowEdge: .bottom) {
            StatsPopover(
                streak: store.streakStats,
                wrapped: store.wrappedStats,
                wip: store.cards(for: .inProgress).count,
                wipLimit: store.wipLimit(for: .inProgress))
        }
    }

    private var streakPillLabel: String {
        store.streakStats.current > 0
            ? "Statistiken. Folge: \(store.streakStats.current) Tage nacheinander mit mindestens einer erledigten Aufgabe"
            : "Statistiken. Zurzeit keine Folge"
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
            // The count, not just a colour. There is no `magnifyingglass.fill`
            // in SF Symbols, so the old `.symbolVariant(.fill)` was a no-op and
            // the tint was carrying the whole "board is filtered" message on
            // its own — invisible to anyone who does not separate those hues,
            // and gone entirely at a glance from across the room.
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                if store.isFiltering {
                    Text("\(store.activeRestrictionCount)")
                        .font(BoardText.value)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
        }
        .keyboardShortcut("f")
        // A board must never be filtered without saying so, or cards look lost
        // rather than hidden.
        .tint(store.isFiltering ? Color.accentColor : nil)
        .accessibilityLabel(store.isFiltering
            ? "Finden, Board ist gefiltert, \(store.activeRestrictionCount) Einschränkungen aktiv"
            : "Aufgabe finden")
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
    ///
    /// Prominence comes from the accent colour, not from a second material.
    /// This carried `.buttonStyle(.glass)`, which broke the rule stated above
    /// on `streakPill`: the toolbar already wraps its items in Liquid Glass,
    /// so an explicit glass style composited a second capsule on top and the
    /// button read as a raised plate with a hard rim. `.glass` was not buying
    /// prominence either — it renders at the same weight as a plain item.
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
                    .font(BoardText.glyph)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.accentColor)
        .help("Apple Erinnerungen öffnen, um Aufgaben anzulegen oder zu bearbeiten (⌘N)")
    }

    /// The real Reminders icon, read from the installed app once.
    private static let remindersAppIcon: NSImage? = {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.reminders") else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }()

}
