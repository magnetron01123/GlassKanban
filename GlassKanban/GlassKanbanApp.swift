import SwiftUI
import ServiceManagement

@main
struct GlassKanbanApp: App {
    @StateObject private var store = RemindersStore()

    init() {
        Self.registerLoginItemOnFirstLaunch()
    }

    var body: some Scene {
        // Single window (one board); macOS restores its frame automatically.
        Window("Glass Kanban", id: "board") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1120, height: 700)
        .commands {
            CommandMenu("Board") {
                Button("In Erinnerungen öffnen") {
                    store.openRemindersApp()
                }
                .keyboardShortcut("n")

                Divider()

                Button("Aktualisieren") {
                    store.scheduleRefresh()
                }
                .keyboardShortcut("r")

                Button("Filter zurücksetzen") {
                    store.resetFilters()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }

    /// Spec: the app starts at login. Registered once on first launch;
    /// the user stays in control via the Settings toggle (and the system's
    /// own Login Items settings).
    private static func registerLoginItemOnFirstLaunch() {
        let key = "didRegisterLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
    }
}
