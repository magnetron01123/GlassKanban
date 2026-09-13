import XCTest
import AppKit

/// Where the app shows itself — the one setting that can make the app
/// unreachable if it gets a case wrong.
final class AppPresenceTests: XCTestCase {

    /// **A persisted contract**, like `StoredSetting`'s keys: these strings
    /// are what lands in `UserDefaults`. Renaming one silently resets the
    /// user's choice to the default.
    func testRawValuesArePinned() {
        XCTAssertEqual(AppPresence.dock.rawValue, "dock")
        XCTAssertEqual(AppPresence.menuBar.rawValue, "menuBar")
        XCTAssertEqual(AppPresence.both.rawValue, "both")
    }

    /// Without a stored value the app has to behave exactly as it did before
    /// this setting existed — a Dock app with a board window.
    func testDefaultIsWhatEveryExistingUserAlreadyHas() {
        UserDefaults.standard.removeObject(forKey: AppPresence.storageKey)
        XCTAssertEqual(AppPresence.stored, .dock)
    }

    func testAnUnknownStoredValueFallsBackToDock() {
        UserDefaults.standard.set("desktopWidget", forKey: AppPresence.storageKey)
        defer { UserDefaults.standard.removeObject(forKey: AppPresence.storageKey) }
        XCTAssertEqual(AppPresence.stored, .dock)
    }

    func testEachCaseShowsWhatItsNameSays() {
        XCTAssertTrue(AppPresence.dock.showsDockIcon)
        XCTAssertFalse(AppPresence.dock.showsMenuBarItem)

        XCTAssertFalse(AppPresence.menuBar.showsDockIcon)
        XCTAssertTrue(AppPresence.menuBar.showsMenuBarItem)

        XCTAssertTrue(AppPresence.both.showsDockIcon)
        XCTAssertTrue(AppPresence.both.showsMenuBarItem)
    }

    /// The board waits to be asked for in the menu bar mode — with "start at
    /// login" on, anything else would throw a board onto the screen at every
    /// single login.
    func testOnlyTheMenuBarModeKeepsTheBoardShutAtLaunch() {
        XCTAssertTrue(AppPresence.dock.opensBoardAtLaunch)
        XCTAssertTrue(AppPresence.both.opensBoardAtLaunch)
        XCTAssertFalse(AppPresence.menuBar.opensBoardAtLaunch)
    }

    func testTheActivationPolicyFollowsTheDockIcon() {
        XCTAssertEqual(AppPresence.dock.activationPolicy, .regular)
        XCTAssertEqual(AppPresence.both.activationPolicy, .regular)
        XCTAssertEqual(AppPresence.menuBar.activationPolicy, .accessory)
    }

    /// Closing the board is closing the app only when there is no item left
    /// in the menu bar to open it again from.
    func testOnlyTheDockOnlyModeQuitsWithItsLastWindow() {
        XCTAssertTrue(AppPresence.dock.quitsWithLastWindow)
        XCTAssertFalse(AppPresence.menuBar.quitsWithLastWindow)
        XCTAssertFalse(AppPresence.both.quitsWithLastWindow)
    }

    /// ⌘-dragging the item out of the menu bar is a gesture macOS offers on
    /// every status item, and in the menu bar mode it would otherwise leave
    /// an app with no Dock icon and no menu bar item — running, and
    /// unreachable by any means the user has.
    func testRemovingTheMenuBarItemAlwaysLeavesAWayBackIn() {
        for presence in AppPresence.allCases {
            XCTAssertEqual(presence.afterMenuBarItemRemoved, .dock)
            XCTAssertTrue(presence.afterMenuBarItemRemoved.showsDockIcon)
        }
    }
}
