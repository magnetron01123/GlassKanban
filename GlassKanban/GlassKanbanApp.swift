import SwiftUI

/// Applies the stored appearance before the first window is on screen, so the
/// board never flashes in the system appearance on the way to the chosen one.
///
/// This cannot live in `GlassKanbanApp.init()`. SwiftUI runs that before
/// `NSApp` exists, and an early attempt to set the appearance there crashed
/// the app on every launch — a failure the build and the unit tests both
/// pass straight through, because it only exists at runtime.
@MainActor
final class AppearanceDelegate: NSObject, NSApplicationDelegate {
    /// The board's data, owned here rather than by the `App` struct.
    ///
    /// In the menu bar mode there is no window, so a `@StateObject` on the
    /// scene would be created only once the board is opened — and the tray,
    /// which is AppKit and lives outside every scene, would have nothing to
    /// read. One store, held by the one object that exists in both modes.
    let store = RemindersStore()

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppearanceController.shared.applyStored()
        // Same moment, same reason: the activation policy decides whether a
        // Dock icon appears at all, and that has to be settled before the
        // app is on screen rather than corrected afterwards.
        PresenceController.shared.applyStored()
    }

    /// The board has to be told which display it belongs to from here: a
    /// representable in `ContentView`'s background never reaches the window
    /// (see `WindowPlacementController`).
    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowPlacementController.shared.start()
        MenuBarTrayController.shared.start(store: store)
        closeRestoredBoardInMenuBarMode()
    }

    /// A `Window` scene is the whole app as far as SwiftUI is concerned, so
    /// closing the board quit. With an item in the menu bar that is the one
    /// thing it must not do — see `AppPresence.quitsWithLastWindow`.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        PresenceController.shared.selection.quitsWithLastWindow
    }

    /// `.defaultLaunchBehavior(.suppressed)` stops SwiftUI from *opening* the
    /// board at launch, and that much was measured (08.09.2026, M3). What it
    /// does not stop is macOS restoring a window that was open when the app
    /// last quit — so in the menu bar mode a board came back anyway, which is
    /// exactly the login-time surprise the setting exists to prevent.
    ///
    /// The board window carries `identifier == "board"` from its scene
    /// (measured 08.09.2026); the status bar windows carry none. Run twice,
    /// because restoration finishes after launch does.
    private func closeRestoredBoardInMenuBarMode() {
        guard !PresenceController.shared.selection.opensBoardAtLaunch else { return }
        closeBoardWindows()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishRestoringWindowsNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                guard !PresenceController.shared.selection.opensBoardAtLaunch else { return }
                Self.closeBoardWindows()
            }
        }
    }

    private func closeBoardWindows() { Self.closeBoardWindows() }

    /// Clicking the Dock icon of a running app with no window open has to
    /// bring the board back.
    ///
    /// This never came up before: closing the board *quit* the app, so the
    /// state "running, no window" did not exist. It does now (see
    /// `AppPresence.quitsWithLastWindow`), and without this the Dock icon
    /// answered a click with nothing at all. The window itself survives its
    /// close — measured 08.09.2026, it stays in `NSApp.windows` carrying
    /// `identifier == "board"` — so ordering it front is the whole of it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        Self.showBoardWindow()
        return true
    }

    static func showBoardWindow() {
        for window in NSApp.windows where window.identifier?.rawValue == "board" {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Brings the board forward once it exists, waiting for it if it does not
    /// yet.
    ///
    /// `openWindow(id:)` returns before the window is on screen, so an
    /// activation fired right after it has nothing of ours to activate and is
    /// dropped — in the menu bar mode the board then stood behind whatever
    /// app the user came from (measured 12.09.2026, first through the status
    /// item's menu). Polling the run loop rather than guessing a delay: the
    /// window appears on the next turn or two, and this stops the moment it
    /// does. `ignoringOtherApps` because the request came from a status item
    /// while another app was frontmost, which is exactly the case the plain
    /// `activate()` refuses.
    static func bringBoardForward(remainingTries: Int = 20) {
        guard remainingTries > 0 else { return }
        let board = NSApp.windows.first { $0.identifier?.rawValue == "board" }
        if let board {
            NSApp.activate(ignoringOtherApps: true)
            board.makeKeyAndOrderFront(nil)
        }
        // Only the window's existence is worth waiting for. Owning the menu
        // bar is not: in the menu bar mode the app runs as an accessory, and
        // an accessory app leaves the menu bar to whoever had it — the window
        // still comes to the front and takes the keyboard, which is what the
        // request was about.
        guard board == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            bringBoardForward(remainingTries: remainingTries - 1)
        }
    }

    private static func closeBoardWindows() {
        for window in NSApp.windows where window.identifier?.rawValue == "board" {
            window.close()
        }
    }
}

extension Notification.Name {
    /// Raised by "New Ticket" so the Backlog lane can run the same creation
    /// its "+" button does — one path, one set of rules.
    static let glassKanbanNewTicket = Notification.Name("GlassKanbanNewTicket")

    /// Raised by the menu bar item's own menu when the board has to come up
    /// and no window exists yet — only SwiftUI can make one, and only from
    /// inside a view (see `MenuBarTrayController.openBoard`).
    static let glassKanbanOpenBoard = Notification.Name("GlassKanbanOpenBoard")
    /// The item's menu asking for the Settings window — answered by the
    /// tray view, which holds `openSettings` (see `MenuBarTrayView`).
    static let glassKanbanOpenSettings = Notification.Name("GlassKanbanOpenSettings")

    /// Raised when the menu bar panel closes and again as it opens, so
    /// everything in it goes back to rest: the capture row drops its draft,
    /// every fold shuts. The panel's view is built once and then lives on —
    /// it has no `onAppear` per opening — and a half-typed title that
    /// reappeared days later would be noise, not a draft.
    /// A section in the tray has just begun to fold, by the height in
    /// `userInfo["travel"]`; the panel's edge travels with the rows
    /// (`MenuBarTrayController.foldStarted`).
    static let glassKanbanTrayFolds = Notification.Name("GlassKanbanTrayFolds")
    static let glassKanbanTrayResets = Notification.Name("GlassKanbanTrayResets")

    /// Raised by the "Find…" menu item so the board can open its popover.
    /// The popover's presentation lives in `BoardView`'s own state; a menu
    /// command has no route into that except through the app's own bus.
    static let glassKanbanShowFind = Notification.Name("GlassKanbanShowFind")
}

@main
struct GlassKanbanApp: App {
    @NSApplicationDelegateAdaptor(AppearanceDelegate.self) private var appearanceDelegate
    @ObservedObject private var presence = PresenceController.shared

    private var store: RemindersStore { appearanceDelegate.store }

    var body: some Scene {
        // Single window (one board); macOS restores its frame automatically.
        Window("Glass Kanban", id: "board") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1280, height: 760)
        // In the menu bar mode the board waits to be asked for. SwiftUI opens
        // a `Window` scene at launch on its own, so with "start at login" on
        // a board would spring up at every single login (measured 08.09.2026,
        // M3: this modifier really does keep it shut).
        .defaultLaunchBehavior(presence.selection.opensBoardAtLaunch ? .automatic : .suppressed)
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
                Button("Find…") {
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
