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
/// design/app-icon-concept.md), and an app cannot override that choice.
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

    /// Shared with `@AppStorage` in the views, so the key exists once.
    static let storageKey = "appAppearance"

    /// The stored choice, for applying at launch before any view exists.
    static var stored: AppAppearance {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
    }
}
