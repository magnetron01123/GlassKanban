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
        .frame(width: 420, height: 380)
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
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    private static let maxWIPLimit = 20

    var body: some View {
        Form {
            // Applied here as well as at launch: the board window may be
            // closed while Settings is open, so the change cannot rely on
            // anything in the main scene noticing it.
            Picker("Erscheinungsbild", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .onChange(of: appearance) { _, choice in choice.apply() }

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
