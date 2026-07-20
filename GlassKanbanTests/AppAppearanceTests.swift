import XCTest
import AppKit

/// The appearance setting. Nothing here exercises the window — what can
/// actually break is the mapping onto AppKit and the stored value surviving a
/// restart, since `@AppStorage` in the view and `AppAppearance.stored` at
/// launch have to agree on one key and one spelling.
final class AppAppearanceTests: XCTestCase {

    private var savedValue: Any?

    override func setUp() {
        super.setUp()
        savedValue = UserDefaults.standard.object(forKey: AppAppearance.storageKey)
    }

    override func tearDown() {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: AppAppearance.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: AppAppearance.storageKey)
        }
        super.tearDown()
    }

    /// `nil` is AppKit's spelling of "inherit the system appearance", so
    /// `.system` has to map onto it rather than onto `.aqua` — pinning light
    /// would silently ignore the user's own Dark Mode.
    func testSystemInheritsRatherThanPinningLight() {
        XCTAssertNil(AppAppearance.system.nsAppearance)
        XCTAssertEqual(AppAppearance.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(AppAppearance.dark.nsAppearance?.name, .darkAqua)
    }

    /// The raw values end up in UserDefaults, so changing one would silently
    /// reset every existing install to the default.
    func testRawValuesAreStable() {
        XCTAssertEqual(AppAppearance.system.rawValue, "system")
        XCTAssertEqual(AppAppearance.light.rawValue, "light")
        XCTAssertEqual(AppAppearance.dark.rawValue, "dark")
        XCTAssertEqual(AppAppearance.allCases.count, 3)
    }

    func testStoredRoundTripsThroughDefaults() {
        UserDefaults.standard.set("dark", forKey: AppAppearance.storageKey)
        XCTAssertEqual(AppAppearance.stored, .dark)

        UserDefaults.standard.set("light", forKey: AppAppearance.storageKey)
        XCTAssertEqual(AppAppearance.stored, .light)
    }

    /// A fresh install and a value written by some future version both have to
    /// land on "follow the system" rather than on a hard-pinned appearance.
    func testUnsetOrUnknownFallsBackToSystem() {
        UserDefaults.standard.removeObject(forKey: AppAppearance.storageKey)
        XCTAssertEqual(AppAppearance.stored, .system)

        UserDefaults.standard.set("solarized", forKey: AppAppearance.storageKey)
        XCTAssertEqual(AppAppearance.stored, .system)
    }

    func testEveryCaseHasALabel() {
        for option in AppAppearance.allCases {
            XCTAssertFalse(option.displayName.isEmpty, "\(option) hat kein Label")
        }
    }

    /// The controller persists on assignment rather than leaving it to the
    /// view. Applying used to live in the Settings window's `onChange`, which
    /// meant a value changed while that window was closed never reached the
    /// board — the preference and what was on screen could disagree.
    func testSettingTheSelectionPersistsImmediately() {
        UserDefaults.standard.removeObject(forKey: AppAppearance.storageKey)

        AppearanceController.shared.selection = .dark
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: AppAppearance.storageKey), "dark")
        XCTAssertEqual(AppAppearance.stored, .dark)

        AppearanceController.shared.selection = .system
        XCTAssertEqual(AppAppearance.stored, .system)
    }
}
