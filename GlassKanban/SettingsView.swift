import SwiftUI
import EventKit
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            ListsSettingsView()
                .tabItem { Label("Listen", systemImage: "list.bullet") }
            GeneralSettingsView()
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
        }
        .frame(width: 420)
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
        // Matches `GeneralSettingsView`: without this the window keeps
        // whichever height the other tab last reported, leaving blank space
        // under a short list. A very long one still scrolls within the
        // window instead of growing past the screen — `Form` stays
        // internally scrollable regardless of this modifier.
        .fixedSize(horizontal: false, vertical: true)
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
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @ObservedObject private var appearance = AppearanceController.shared

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
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Revert the toggle if the system rejected the change.
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

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
        // `Form` reports a flexible, not an intrinsic, height — without this
        // the Settings window sizes itself from some default rather than
        // this tab's actual content, and clips the last row behind a
        // scrollbar. Only this tab: `ListsSettingsView` grows with however
        // many reminder lists exist, which should scroll rather than push
        // the window past the screen.
        .fixedSize(horizontal: false, vertical: true)
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
