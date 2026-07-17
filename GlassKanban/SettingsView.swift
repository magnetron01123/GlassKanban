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
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
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
        }
        .formStyle(.grouped)
    }
}
