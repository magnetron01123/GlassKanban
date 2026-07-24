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
    static let generalHeight: CGFloat = 447
}

struct SettingsView: View {
    var body: some View {
        TabView {
            ListsSettingsView()
                .tabItem { Label("Listen", systemImage: "list.bullet") }
            GeneralSettingsView()
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
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
            Section("Diese Listen im Board anzeigen") {
                if store.reminderCalendars.isEmpty {
                    Text("Keine Erinnerungslisten gefunden.")
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
    /// Distinguishes the user flipping the switch from us loading its state,
    /// so syncing never re-registers the login item as a side effect.
    @State private var isSyncingLaunchAtLogin = false

    private static let maxWIPLimit = 20

    var body: some View {
        Form {
            // No `onChange` here on purpose: the controller's setter persists
            // and applies in one step, so the effect does not depend on this
            // window being open.
            Picker("Erscheinungsbild", selection: $appearance.selection) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Toggle("Beim Anmelden starten", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    guard !isSyncingLaunchAtLogin else { return }
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Revert the toggle if the system rejected the change.
                        syncLaunchAtLogin()
                    }
                }

            // The one sound the app makes (see `MoveFeedback`). It ships on —
            // the completion tick is part of the reward the board is built
            // around — but an app that lives on screen all day owes the off
            // switch a first-class place.
            Toggle("Ton beim Erledigen", isOn: $store.completionSoundEnabled)

            // The board's resting state for recurring cards. Set here rather
            // than only in the find popover, where every launch would start
            // over: this is a preference, the popover's row is a quick look.
            Section {
                Toggle(
                    "Wiederkehrende bis zur Fälligkeit ausblenden",
                    isOn: $store.hideRecurringUntilDue)
            } header: {
                Text("Backlog")
            } footer: {
                // Two things to convey, and the old wording only managed the
                // first: what the switch does, and that it is the *resting*
                // state the find popover's row starts from and returns to.
                // Without the second, the two controls look like a
                // contradiction the moment they disagree.
                Text("Wiederkehrende Aufgaben erscheinen im Backlog erst ab Fälligkeit. Unter „Finden“ vorübergehend umstellbar — Ausgangswert bleibt diese Einstellung.")
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
                Text("Work-in-Progress-Limits")
                    .help("Lieber abschließen als stapeln")
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
        return limit > 0 ? "\(limit)" : "Kein Limit"
    }
}
