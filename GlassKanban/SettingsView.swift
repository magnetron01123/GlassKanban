import SwiftUI
import AppKit
import EventKit
import ServiceManagement

/// How tall a settings pane is.
///
/// **The rule, and it is the app's general one (12.09.2026, user):** a pane is
/// as tall as its content — the window grows downward rather than scrolling
/// inside itself — and it scrolls only when the screen is too short to show
/// the whole of it. The menu bar panel follows the same rule
/// (`MenuBarTrayController.contentHeightChanged`).
///
/// The heights are *computed*, not measured at runtime. Measuring was a
/// visible bug once: the window opened at a default size and only then
/// resized to fit, and the correction showed as a stutter with the tab bar
/// redrawing mid-flight. A height that is known before the window appears has
/// nothing to correct — the window opens right the first time, and switching
/// tabs is one deterministic resize rather than a measure-then-adjust. So
/// "Listen" derives its height from the number of rows it will draw, and
/// "Allgemein" is fixed content with a number measured against it.
enum SettingsMetrics {
    static let width: CGFloat = 420

    /// One list row in a grouped form: the toggle, its colour dot and its
    /// title. Measured, not guessed — see the note above.
    static let listRowHeight: CGFloat = 37
    /// Everything in the Listen pane that is not a row: the form's own
    /// insets, the section header, the box's padding.
    static let listsChrome: CGFloat = 64

    /// The Listen pane grows with the number of lists the user actually has.
    /// A fixed 260 pt scrolled from the seventh list on and stood half empty
    /// with two.
    static func listsHeight(rowCount: Int) -> CGFloat {
        onScreen(listsChrome + CGFloat(max(rowCount, 1)) * listRowHeight)
    }

    /// Measured against the content, not guessed: the pane is a fixed height,
    /// so a footer that grows silently loses its last line. 455 cut the WIP
    /// rule off mid-sentence the day it stopped being a hover tip; 640 cut the
    /// whole WIP footer off the day the shortcut row arrived.
    static let generalHeight: CGFloat = 706

    /// The recorder's width, so the row keeps its shape whether it says
    /// "Kein Kurzbefehl", "Aufnahme …" or "⌥⌘K".
    static let shortcutWidth: CGFloat = 150

    /// Title bar and tab bar, which sit above the pane inside the same window.
    private static let windowChrome: CGFloat = 92
    /// Never taller than the screen the window is on. Past that the pane
    /// keeps its own scrolling — the only case in which it scrolls at all.
    static func onScreen(_ height: CGFloat) -> CGFloat {
        let available = (NSScreen.main?.visibleFrame.height ?? 900) - windowChrome
        return min(height, max(240, available))
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            ListsSettingsView()
                .tabItem { Label("Lists", systemImage: "list.bullet") }
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: SettingsMetrics.width)
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
        .frame(height: SettingsMetrics.listsHeight(rowCount: visibleRowCount))
    }

    /// What the pane will actually draw: one row per list, or the single line
    /// that stands in for them when there is no access and nothing to show.
    private var visibleRowCount: Int {
        if store.accessState == .denied || store.reminderCalendars.isEmpty { return 2 }
        return store.reminderCalendars.count
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

    private static let maxWIPLimit = 20

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
                // Names the facts and stops: what is up there, what happens
                // to the app without a Dock icon, and the one thing about the
                // shortcut a user cannot see — the system does not report a
                // combination another app already holds, so it simply stays
                // with that app (measured 12.09.2026).
                Text("The menu bar shows Next Up, In Progress and Done. Without a Dock icon the app keeps running while the board is closed. The shortcut opens and closes the panel from any app; one that another app already uses stays with that app.")
            }

            // Where workflows differ most. Backlog is the pool of options the
            // board could pull *now*, which is why this ships on — but "now"
            // is a judgement some people would rather make themselves, with
            // the whole pool in view. Unlike the rule this replaced, neither
            // position hides anything: both fold, both count what they hold,
            // both are one click from the full pile (see `BacklogFold`).
            Section {
                Toggle("Collapse Not-Yet-Due Items", isOn: $store.foldNotYetDue)
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
                Text("When a lane is full, the board asks before another card goes in. 0 means no limit.")
            }
        }
        .formStyle(.grouped)
        .frame(height: SettingsMetrics.onScreen(SettingsMetrics.generalHeight))
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
