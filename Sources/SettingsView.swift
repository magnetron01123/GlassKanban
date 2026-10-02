import SwiftUI
import AppKit
import EventKit
import ServiceManagement

/// Sizes of the settings window.
enum SettingsMetrics {
    static let width: CGFloat = 420

    /// The recorder's width, so the row keeps its shape whether it says
    /// "Kein Kurzbefehl", "Aufnahme …" or "⌥⌘K".
    static let shortcutWidth: CGFloat = 150

    /// Title bar and tab bar, which sit above the pane inside the same window.
    private static let windowChrome: CGFloat = 92
    /// The tallest a pane may be: what the screen the window is on leaves.
    static var maxPaneHeight: CGFloat {
        max(240, (NSScreen.main?.visibleFrame.height ?? 900) - windowChrome)
    }
}

/// How tall a settings pane is: exactly as tall as its form says it is.
///
/// **The rule, and it is the app's general one (12.09.2026, user):** a pane is
/// as tall as its content — the window grows downward rather than scrolling
/// inside itself — and it scrolls only when the screen is too short to show
/// the whole of it. The menu bar panel follows the same rule
/// (`MenuBarTrayController.contentHeightChanged`).
///
/// **No pane carries a height of its own (28.09.2026).** Until then every pane
/// had a number measured against its content, and every number went wrong
/// sooner or later: 455 cut the WIP rule off mid-sentence, 640 the whole WIP
/// footer, and on 28.09.2026 all three panes stood one or two points short of
/// the form's own bottom inset — enough to put a scroll bar on every one of
/// them (user: "mega nervig"). A longer footer or a translation moves the
/// number again. So the form is asked for its ideal height, in the same
/// layout pass — not measured after it appears, which was the stutter of
/// July 2026 — and the screen is the only thing that may cut it shorter.
struct ScreenBoundedPane: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let pane = subviews.first else { return .zero }
        let ideal = pane.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(ideal.height, SettingsMetrics.maxPaneHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Offered exactly the bounds: the whole form where it fits, and a
        // shorter frame — in which the form scrolls — only where it does not.
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// The settings window's panes, in the order a Mac app lists them: the app
/// first, then what feeds the board, then how work flows on it (28.09.2026).
enum SettingsPane: Hashable {
    case general, lists, board
}

/// Which pane the settings window shows. Shared, so a way in from elsewhere
/// can open the pane it is about: the empty board's "Choose Lists" landed on
/// the lists only because they used to be the first tab.
@MainActor
final class SettingsNavigation: ObservableObject {
    static let shared = SettingsNavigation()
    @Published var pane: SettingsPane = .general
}

struct SettingsView: View {
    @ObservedObject private var navigation = SettingsNavigation.shared

    var body: some View {
        TabView(selection: $navigation.pane) {
            ScreenBoundedPane { GeneralSettingsView() }
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsPane.general)
            ScreenBoundedPane { ListsSettingsView() }
                .tabItem { Label("Lists", systemImage: "list.bullet") }
                .tag(SettingsPane.lists)
            ScreenBoundedPane { BoardSettingsView() }
                // A system symbol like its two neighbours, not the menu bar
                // glyph: drawn for 1× pixels, that one stood heavier than the
                // gear and the list beside it (28.09.2026, user).
                .tabItem { Label("Board", systemImage: "rectangle.split.3x1") }
                .tag(SettingsPane.board)
        }
        .frame(width: SettingsMetrics.width)
        // Its own colour, not the desktop's. SwiftUI tints a settings window
        // from whatever lies behind it, and the window changes height with
        // the pane — so switching tabs changed the colour of the whole window
        // (measured 13.09.2026: toolbar 39/38/32 on one pane, 47/36/34 on
        // the other). `containerBackground(_:for: .window)` did not reach it.
        // The same rule as the board's applies — no surface changes without
        // an event of the user's (CONCEPT.md, "Immer-aktiv").
        .background(OpaqueSettingsWindow())
    }
}

/// Which reminder lists feed the board. The lists themselves are never
/// touched — this only controls visibility.
struct ListsSettingsView: View {
    @EnvironmentObject private var store: RemindersStore

    var body: some View {
        Form {
            Section("Show These Lists on the Board") {
                // Access first, lists second. Two different states looked the
                // same here, and asking `isEmpty` first got the order wrong
                // twice over: without permission EventKit returns nothing, so
                // the window blamed the user's lists for the app's missing
                // access — and when access is revoked while the app is
                // running, the calendars already fetched stay in memory, so
                // the pane went on offering switches for lists it could no
                // longer read. The state decides what is shown, never the
                // leftovers of the last successful fetch.
                if store.accessState == .denied {
                    Text("No access to Reminders. Allow it in System Settings under “Privacy & Security”.")
                        .foregroundStyle(.secondary)
                } else if store.reminderCalendars.isEmpty {
                    Text("No reminder lists found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.reminderCalendars, id: \.calendarIdentifier) { calendar in
                        Toggle(isOn: inclusionBinding(for: calendar)) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(nsColor: calendar.color ?? .controlAccentColor))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func inclusionBinding(for calendar: EKCalendar) -> Binding<Bool> {
        Binding(
            get: { !store.excludedCalendarIDs.contains(calendar.calendarIdentifier) },
            set: { include in
                if include {
                    store.excludedCalendarIDs.remove(calendar.calendarIdentifier)
                } else {
                    store.excludedCalendarIDs.insert(calendar.calendarIdentifier)
                }
            })
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: RemindersStore
    @ObservedObject private var appearance = AppearanceController.shared
    @ObservedObject private var presence = PresenceController.shared
    @ObservedObject private var trayShortcut = TrayShortcutController.shared

    /// Seeded with the real state rather than a placeholder corrected in
    /// `onAppear`: that correction is a state change on the first frame, so
    /// with the login item enabled the switch would visibly flick from off
    /// to on as the pane appears. The read is an IPC round trip to the
    /// service-management daemon, measured at 2–3 ms — cheap enough to do
    /// once here, and it is refreshed on focus for changes made elsewhere.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Why the switch sprang back, when it did.
    @State private var launchAtLoginError: String?
    /// Distinguishes the user flipping the switch from us loading its state,
    /// so syncing never re-registers the login item as a side effect.
    @State private var isSyncingLaunchAtLogin = false

    var body: some View {
        Form {
            // No `onChange` here on purpose: the controller's setter persists
            // and applies in one step, so the effect does not depend on this
            // window being open.
            Picker("Appearance", selection: $appearance.selection) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Toggle("Start at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    // The flag alone did not hold: SwiftUI delivers this after
                    // the sync has already cleared it, so pulling the real
                    // state in looked like a user decision and unregistered
                    // the login item the user had just switched on. Comparing
                    // against the system is the guard that cannot race —
                    // if it already stands this way, there is nothing to do.
                    guard !isSyncingLaunchAtLogin,
                          (SMAppService.mainApp.status == .enabled) != enabled
                    else { return }
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Revert the toggle if the system rejected the change —
                        // and say so. Silently springing back looks like a
                        // broken switch; the usual cause is macOS blocking the
                        // registration in "Anmeldeobjekte", which the user can
                        // only act on if they are told.
                        // Not `error.localizedDescription`: that is
                        // "SMAppServiceErrorDomain error 1", in English, in a
                        // German app, naming neither cause nor remedy. The
                        // cause is nearly always the same one, and it is
                        // actionable — so the app says that instead.
                        launchAtLoginError = String(
                            localized: "macOS blocks the login item. Allow Glass Kanban under Login Items in System Settings.")
                        syncLaunchAtLogin()
                    }
                }
                .alert(
                    "Couldn't Start at Login",
                    isPresented: Binding(
                        get: { launchAtLoginError != nil },
                        set: { if !$0 { launchAtLoginError = nil } })
                ) {
                    // A way there, not just the news — the same shape the
                    // access notice uses.
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(launchAtLoginError ?? "")
                }

            // The one sound the app makes (see `MoveFeedback`). It ships on —
            // the completion tick is part of the reward the board is built
            // around — but an app that lives on screen all day owes the off
            // switch a first-class place.
            Toggle("Sound on Completion", isOn: $store.completionSoundEnabled)

            // Its own section rather than a fourth single row: unlike the
            // three above, this one changes where the app *is*, and the
            // footer has to say what that costs. No `onChange` either — the
            // controller persists and applies in one step (measured 08.09.2026,
            // M2: the activation policy really does switch at runtime).
            Section {
                Picker("Show In", selection: $presence.selection) {
                    ForEach(AppPresence.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                // Under the switch that decides whether there is a panel at
                // all, and disabled with it: a key combination that answers
                // with nothing is worse than none.
                LabeledContent("Shortcut") {
                    VStack(alignment: .trailing, spacing: 2) {
                        ShortcutRecorder(
                            shortcut: trayShortcut.shortcut,
                            record: { TrayShortcutController.shared.record($0) })
                            // A control, not a banner: left to itself the
                            // button takes the whole trailing half of the row.
                            .frame(width: SettingsMetrics.shortcutWidth)
                        if trayShortcut.isTaken {
                            Text("In use by another app")
                                .font(BoardText.meta)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!presence.selection.showsMenuBarItem)
            } header: {
                Text("Menu Bar")
            } footer: {
                // Names the facts and stops: what is up there — all four
                // sections since the Backlog became one (12.09.2026) —, what happens
                // to the app without a Dock icon, and the one thing about the
                // shortcut a user cannot see — the system does not report a
                // combination another app already holds, so it simply stays
                // with that app (measured 12.09.2026).
                Text("The menu bar shows Backlog, Next Up, In Progress and Done. Without a Dock icon the app keeps running while the board is closed. The shortcut opens and closes the panel from any app; one that another app already uses stays with that app.")
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            syncLaunchAtLogin()
        }
    }

    /// Pulls the real login-item state into the toggle without that write
    /// being mistaken for a user action (see `isSyncingLaunchAtLogin`).
    private func syncLaunchAtLogin() {
        isSyncingLaunchAtLogin = true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        isSyncingLaunchAtLogin = false
    }
}

/// The board's own rules: what rests behind the Backlog's fold, and how much
/// work may be started at once. Apart from the app's settings so the one
/// rule Kanban asks to make explicit is found where the board is.
struct BoardSettingsView: View {
    @EnvironmentObject private var store: RemindersStore
    @ObservedObject private var boardScale = BoardScaleController.shared

    private static let maxWIPLimit = 20

    var body: some View {
        Form {
            // First, because it is the one setting here about how the board
            // looks rather than how it works. Segments rather than a menu:
            // three steps, all visible, the chosen one lands on the board at
            // once — so trying them is how one chooses.
            // The name stands as the section's head, like its two neighbours:
            // as a row label it pushed the segments onto a line of their own
            // in both languages (28.09.2026).
            Section {
                Picker("Display Size", selection: $boardScale.selection) {
                    ForEach(BoardScale.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                Text("Display Size")
            } footer: {
                // The only place the keys are named: they live on the board
                // window, not in the menu bar (29.09.2026, user), so this is
                // where someone looking for the size learns the shortcut.
                Text("⌘+ and ⌘− change the size on the board as well, ⌘0 resets it.")
            }

            // Where workflows differ most. Backlog is the pool of options the
            // board could pull *now*, which is why this ships on — but "now"
            // is a judgement some people would rather make themselves, with
            // the whole pool in view. Unlike the rule this replaced, neither
            // position hides anything: both fold, both count what they hold,
            // both are one click from the full pile (see `BacklogFold`).
            Section {
                Toggle("Collapse Not-Yet-Due Tasks", isOn: $store.foldNotYetDue)
            } header: {
                Text("Backlog")
            } footer: {
                // Says what the switch does *and* that nothing disappears
                // either way — the previous version of this feature did make
                // cards vanish, and that is the fear worth answering here.
                Text("Recurring tasks whose next due date hasn't arrived yet rest behind the fold at the bottom of the Backlog — one click brings them forward, nothing is ever hidden for good. Beyond \(BacklogFold.collapsedLimit) cards, the rest folds regardless.")
            }

            // Deliberately the only place a limit can be changed: a limit you
            // can raise from the board, in the moment it gets inconvenient,
            // stops being a commitment.
            Section {
                ForEach(KanbanStatus.allCases.filter(\.supportsWIPLimit)) { status in
                    Stepper(value: limitBinding(for: status), in: 0...Self.maxWIPLimit) {
                        HStack {
                            Text(status.displayName)
                            Spacer()
                            Text(limitLabel(for: status))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Work-in-Progress Limits")
            } footer: {
                // The rule was written down in exactly one place: a hover tip
                // on this header. A limit nobody can read is not an explicit
                // policy, and "make policies explicit" is the one Kanban rule
                // this board owes the user in words. The settings pane is
                // where that costs nothing — the board itself stays wordless.
                //
                // Says what happens and what 0 means, and stops there. The
                // tip it replaces ("Finish before you stack") was a maxim;
                // this board's chrome names things, it does not coach.
                //
                // Two lines, not one sentence after the other: run on, the
                // wrap left the "0" alone at the end of a line and its meaning
                // on the next (28.09.2026, user).
                VStack(alignment: .leading, spacing: 2) {
                    Text("When a column is full, the board asks before another card goes in.")
                    Text("0 means no limit.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func limitBinding(for status: KanbanStatus) -> Binding<Int> {
        Binding(
            get: { store.wipLimits[status.rawValue] ?? 0 },
            set: { store.setWIPLimit($0, for: status) })
    }

    private func limitLabel(for status: KanbanStatus) -> String {
        let limit = store.wipLimits[status.rawValue] ?? 0
        return limit > 0 ? "\(limit)" : String(localized: "No Limit")
    }
}

/// Keeps the settings window's colour its own instead of the desktop's (see
/// `SettingsView`).
///
/// Measured 14.09.2026 by dumping the window's view and layer trees: the
/// tint does not come from an `NSVisualEffectView` — the window's are all
/// within-window, and hiding them changed nothing — but from the
/// `CAChameleonLayer`s SwiftUI lays under its hosting view on macOS 26,
/// which sample whatever lies behind the window. Hidden here by class name,
/// so a system without them simply keeps its look. What remains is the
/// system's `windowBackgroundColor` (white in the light appearance on this
/// macOS, 30/30/30 in the dark one). Every pane brings its own chameleons,
/// so this runs on every layout pass.
private struct OpaqueSettingsWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.hideChameleons() }

    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            hideChameleons()
        }

        override func layout() {
            super.layout()
            hideChameleons()
            // The pane being switched to lays out after this view does.
            DispatchQueue.main.async { [weak self] in self?.hideChameleons() }
        }

        func hideChameleons() {
            guard let root = window?.contentView?.superview?.layer else { return }
            hide(in: root)
        }

        private func hide(in layer: CALayer) {
            if String(describing: type(of: layer)) == "CAChameleonLayer" {
                layer.isHidden = true
            }
            for child in layer.sublayers ?? [] { hide(in: child) }
        }
    }
}
