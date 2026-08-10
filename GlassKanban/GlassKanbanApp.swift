import SwiftUI

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

extension Notification.Name {
    /// Raised by "New Ticket" so the Backlog lane can run the same creation
    /// its "+" button does — one path, one set of rules.
    static let glassKanbanNewTicket = Notification.Name("GlassKanbanNewTicket")

    /// Raised by the "Find …" menu item so the board can open its popover.
    /// The popover's presentation lives in `BoardView`'s own state; a menu
    /// command has no route into that except through the app's own bus.
    static let glassKanbanShowFind = Notification.Name("GlassKanbanShowFind")
}

@main
struct GlassKanbanApp: App {
    @StateObject private var store = RemindersStore()
    @NSApplicationDelegateAdaptor(AppearanceDelegate.self) private var appearanceDelegate

    var body: some Scene {
        // Single window (one board); macOS restores its frame automatically.
        Window("Glass Kanban", id: "board") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1280, height: 760)
        .commands {
            CommandMenu("Board") {
                // Every board command answers the same two questions the
                // toolbar buttons already answer: is there access, and is a
                // card being held up in front of the board? A shortcut that
                // slips past a disabled button is the same bug four times —
                // ⌘F opened a second panel over the open editor, ⌘N left an
                // untitled ghost behind, and without access ⌘F and ⌘R were
                // simply clickable and pointless.
                let isBusy = store.editingCardID != nil
                let hasAccess = store.accessState == .granted

                // ⌘F lived only on a toolbar button, so the one shortcut a
                // Mac user looks for by name was findable only by hovering.
                // The button keeps its own `.keyboardShortcut`; this entry is
                // where the convention says to look for it.
                Button("Find …") {
                    NotificationCenter.default.post(name: .glassKanbanShowFind, object: nil)
                }
                .keyboardShortcut("f")
                .disabled(isBusy || !hasAccess)

                Divider()

                // ⌘N means "new" on every Mac, and here it opened another
                // application. The "+" in the Backlog had no shortcut at all,
                // so the reflex produced the one thing it never means.
                Button("New Ticket") {
                    NotificationCenter.default.post(name: .glassKanbanNewTicket, object: nil)
                }
                .keyboardShortcut("n")
                .disabled(isBusy || !hasAccess)

                Button("Open in Reminders") {
                    store.openRemindersApp()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(isBusy)

                Divider()

                Button("Refresh") {
                    store.scheduleRefresh()
                }
                .keyboardShortcut("r")
                .disabled(!hasAccess)

                Button("Reset Filters") {
                    store.resetFilters()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                // The same condition the popover's own reset button uses. A
                // menu item that is always available but does nothing most of
                // the time teaches the user to distrust the menu.
                .disabled(isBusy || !store.isFiltering)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
