import SwiftUI
import ServiceManagement

/// Applies the stored appearance before the first window is on screen, so the
/// board never flashes in the system appearance on the way to the chosen one.
///
/// This cannot live in `GlassKanbanApp.init()`. SwiftUI runs that before
/// `NSApp` exists, and an early attempt to set the appearance there crashed
/// the app on every launch — a failure the build and the unit tests both
/// pass straight through, because it only exists at runtime.
final class AppearanceDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppearanceController.shared.applyStored()
    }
}

@main
struct GlassKanbanApp: App {
    @StateObject private var store = RemindersStore()
    @NSApplicationDelegateAdaptor(AppearanceDelegate.self) private var appearanceDelegate

    init() {
        Self.registerLoginItemOnFirstLaunch()
    }

    var body: some Scene {
        // Single window (one board); macOS restores its frame automatically.
        Window("Glass Kanban", id: "board") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1280, height: 760)
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
