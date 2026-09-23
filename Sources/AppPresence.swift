import SwiftUI
import AppKit

/// Where the app shows itself: Dock, menu bar, or both.
///
/// Modelled on `AppAppearance`, and for the same reason: a setting that says
/// something about the whole app has to be applied from one place, not from
/// whichever view happens to be on screen.
enum AppPresence: String, CaseIterable, Identifiable {
    case dock
    case menuBar
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dock: String(localized: "Dock")
        case .menuBar: String(localized: "Menu Bar")
        case .both: String(localized: "Dock and Menu Bar")
        }
    }

    var showsDockIcon: Bool { self != .menuBar }
    var showsMenuBarItem: Bool { self != .dock }

    /// Whether the board window may open on its own at launch. In the menu
    /// bar mode the tray is the app; the board comes when asked for.
    /// Measured 08.09.2026 (M3): `.defaultLaunchBehavior(.suppressed)` really
    /// does keep the window shut — though a window macOS *restores* needs
    /// closing separately (see `AppearanceDelegate`).
    var opensBoardAtLaunch: Bool { self != .menuBar }

    /// Measured 08.09.2026 (M2): switching this at runtime takes the Dock
    /// icon away and brings it back cleanly, so the setting can act at once
    /// rather than promising to act at the next launch.
    var activationPolicy: NSApplication.ActivationPolicy {
        showsDockIcon ? .regular : .accessory
    }

    /// Whether closing the board's window ends the app.
    ///
    /// It always did — a SwiftUI `Window` scene is the app, and shutting it
    /// quits. With a menu bar item that is wrong twice over: the item would
    /// vanish with the app that owns it, and the promise the setting makes —
    /// "the app keeps running while the board is closed" — would be broken by
    /// the first close. Measured 08.09.2026: without this the app quit the
    /// moment the restored board was closed at launch, leaving no process and
    /// no item behind.
    var quitsWithLastWindow: Bool { !showsMenuBarItem }

    /// The user dragged the item out of the menu bar (⌘-drag). Without a
    /// Dock icon the app would be unreachable, so this always lands on Dock.
    var afterMenuBarItemRemoved: AppPresence { .dock }

    func apply() {
        NSApplication.shared.setActivationPolicy(activationPolicy)
    }

    static let storageKey = StoredSetting.presence.key

    /// Default is the behaviour every existing user already has.
    static var stored: AppPresence {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(AppPresence.init(rawValue:)) ?? .dock
    }
}

/// Owns the setting, so that storing it and applying it are one step — the
/// same shape as `AppearanceController`, and for the reason written down
/// there: bound straight to `@AppStorage`, the effect would depend on the
/// Settings window being open.
final class PresenceController: ObservableObject {
    static let shared = PresenceController()

    @Published var selection: AppPresence {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: AppPresence.storageKey)
            selection.apply()
        }
    }

    private init() {
        // As in `AppearanceController`: assigning here deliberately does not
        // run `didSet` — there is nothing to persist yet, and launch applies
        // the value separately.
        selection = AppPresence.stored
    }

    /// Called once from the app delegate, before the first window exists.
    func applyStored() { selection.apply() }
}
