import SwiftUI
import AppKit

/// Whether the app follows the system appearance or pins its own.
///
/// Applied through `NSApp.appearance` rather than SwiftUI's
/// `.preferredColorScheme`. The SwiftUI modifier only reaches the scene it is
/// attached to, which would leave the Settings window, the menus and every
/// popover on the system setting — a setting that says "the whole app" has to
/// mean the whole app.
///
/// Note this covers the app's windows only. The Dock icon always follows the
/// system: macOS picks the icon's light or dark appearance itself (see
/// the git history of AppIcon.icon), and an app cannot override that choice.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Nach System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    /// `nil` is not a missing value here — it is how AppKit spells "inherit
    /// the system appearance", so `.system` maps onto it directly.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// Deliberately `NSApplication.shared` and not `NSApp`: the latter is an
    /// implicitly unwrapped global that is still nil while SwiftUI runs
    /// `App.init()`, so calling this too early would trap rather than fail
    /// visibly. `shared` always hands back an instance.
    func apply() {
        NSApplication.shared.appearance = nsAppearance
    }

    /// Shared with the controller below, so the key exists once.
    static let storageKey = "appAppearance"

    /// The stored choice, for applying at launch before any view exists.
    static var stored: AppAppearance {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
    }
}

/// Owns the setting, so that storing it and applying it are one step.
///
/// The first version bound the picker straight to `@AppStorage` and applied
/// the change in the view's `onChange`. That ties the effect to the Settings
/// window being on screen: change the value while Settings is closed — as a
/// synced preference or another window can — and the board keeps rendering the
/// old appearance until the next launch, with the stored preference quietly
/// disagreeing with what is visible. Writing through one setter removes the
/// failure mode instead of documenting it.
final class AppearanceController: ObservableObject {
    static let shared = AppearanceController()

    @Published var selection: AppAppearance {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: AppAppearance.storageKey)
            selection.apply()
        }
    }

    private init() {
        // Assigning in init deliberately does not run `didSet`: there is
        // nothing to persist yet, and launch applies the value separately.
        selection = AppAppearance.stored
    }

    /// Called once from the app delegate, before the first window exists.
    func applyStored() {
        selection.apply()
    }
}
