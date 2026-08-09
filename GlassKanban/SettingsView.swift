import SwiftUI
import EventKit
import ServiceManagement

/// Each pane states its own height as a constant, rather than letting the
/// panes measure themselves with `fixedSize`.
///
/// That measuring was a visible bug: the window opened at a default size and
/// only then resized to fit its content, and the correction showed as a
/// stutter with the tab bar redrawing mid-flight. A height that is known
/// before the window appears has nothing to correct — the window opens right
/// the first time, and switching tabs is one deterministic resize rather
/// than a measure-then-adjust.
///
/// The two panes differ enough that a shared height would leave Listen half
/// empty, so they are sized individually. Listen fits a typical set of
/// reminder lists and scrolls internally beyond that; Allgemein is fixed
/// content, so its number only changes when a setting is added.
enum SettingsMetrics {
    static let width: CGFloat = 420
    static let listsHeight: CGFloat = 260
    static let generalHeight: CGFloat = 455
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
                if store.reminderCalendars.isEmpty {
                    // Two different states looked the same here. Without
                    // permission EventKit simply returns nothing, so the
                    // window blamed the user's lists for what is the app's
                    // missing access — and the one sentence that could have
                    // explained it said the opposite.
                    Text(store.accessState == .denied
                        ? "No access to Reminders. Allow it in System Settings under “Privacy & Security”."
                        : "No reminder lists found")
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
        .frame(height: SettingsMetrics.listsHeight)
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
                    guard !isSyncingLaunchAtLogin else { return }
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
                        launchAtLoginError = error.localizedDescription
                        syncLaunchAtLogin()
                    }
                }
                .alert(
                    "Couldn't Start at Login",
                    isPresented: Binding(
                        get: { launchAtLoginError != nil },
                        set: { if !$0 { launchAtLoginError = nil } })
                ) {
                    Button("OK") {}
                } message: {
                    Text(launchAtLoginError ?? "")
                }

            // The one sound the app makes (see `MoveFeedback`). It ships on —
            // the completion tick is part of the reward the board is built
            // around — but an app that lives on screen all day owes the off
            // switch a first-class place.
            Toggle("Sound on Completion", isOn: $store.completionSoundEnabled)

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
                    .help("Finish before you stack")
            }
        }
        .formStyle(.grouped)
        .frame(height: SettingsMetrics.generalHeight)
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
