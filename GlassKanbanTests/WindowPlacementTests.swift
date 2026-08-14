import XCTest

/// The rule that puts the board back on its own display. Every case here is a
/// monitor being unplugged and plugged back in, written down instead of
/// performed.
final class WindowPlacementTests: XCTestCase {

    /// Built-in display at the origin, external one to its right — the usual
    /// desk, and the arrangement every test starts from.
    private let builtIn = WindowPlacement.Screen(
        id: "built-in", frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
    private let external = WindowPlacement.Screen(
        id: "external", frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440))

    private var docked: [WindowPlacement.Screen] { [builtIn, external] }
    private var undocked: [WindowPlacement.Screen] { [builtIn] }

    /// The board as it usually sits: on the external display, offset 200/100
    /// into it.
    private let onExternal = CGRect(x: 1712, y: 100, width: 1280, height: 760)

    // MARK: - Which screen a window is on

    func testWindowBelongsToTheScreenItOverlapsMost() {
        let straddling = CGRect(x: 1412, y: 100, width: 1280, height: 760)
        XCTAssertEqual(
            WindowPlacement.screen(for: straddling, among: docked)?.id, "external")
    }

    func testWindowOnNoKnownScreenHasNone() {
        let offscreen = CGRect(x: 9000, y: 9000, width: 400, height: 300)
        XCTAssertNil(WindowPlacement.screen(for: offscreen, among: docked))
    }

    // MARK: - Remembering

    func testRememberStoresThePositionRelativeToItsOwnScreen() {
        let memory = WindowPlacement.remember(window: onExternal, screens: docked)
        XCTAssertEqual(memory?.screenID, "external")
        // 1712 - 1512 = 200: the offset into the screen, not the desktop.
        XCTAssertEqual(memory?.frame, CGRect(x: 200, y: 100, width: 1280, height: 760))
    }

    /// Rearranging the displays in System Settings moves every origin. The
    /// stored position has to survive that untouched, which is the whole
    /// reason it is relative.
    func testStoredPositionSurvivesTheDisplaysBeingRearranged() {
        let memory = WindowPlacement.remember(window: onExternal, screens: docked)!
        let mirrored = [
            WindowPlacement.Screen(id: "external", frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)),
            WindowPlacement.Screen(id: "built-in", frame: CGRect(x: 2560, y: 0, width: 1512, height: 982)),
        ]
        let window = CGRect(x: 2700, y: 40, width: 1280, height: 760)
        XCTAssertEqual(
            WindowPlacement.restore(memory, window: window, screens: mirrored),
            CGRect(x: 200, y: 100, width: 1280, height: 760))
    }

    // MARK: - Restoring

    func testWindowGoesBackWhenItsScreenReturns() {
        let memory = WindowPlacement.remember(window: onExternal, screens: docked)!
        // Undocked: macOS has herded the window onto the built-in display.
        let herded = CGRect(x: 100, y: 100, width: 1280, height: 760)
        XCTAssertEqual(
            WindowPlacement.restore(memory, window: herded, screens: docked), onExternal)
    }

    func testWindowStaysPutWhileItsScreenIsAway() {
        let memory = WindowPlacement.remember(window: onExternal, screens: docked)!
        let herded = CGRect(x: 100, y: 100, width: 1280, height: 760)
        XCTAssertNil(WindowPlacement.restore(memory, window: herded, screens: undocked))
    }

    func testWindowAlreadyHomeIsLeftAlone() {
        let memory = WindowPlacement.remember(window: onExternal, screens: docked)!
        let movedWithinItsScreen = CGRect(x: 1800, y: 300, width: 1280, height: 760)
        XCTAssertNil(
            WindowPlacement.restore(memory, window: movedWithinItsScreen, screens: docked))
    }

    /// A window is never restored onto a display that cannot hold it — the
    /// same monitor can come back at a smaller scaled resolution.
    func testRestoredFrameIsKeptOnTheScreenItGoesTo() {
        let memory = WindowPlacement.remember(window: onExternal, screens: docked)!
        let shrunk = WindowPlacement.Screen(
            id: "external", frame: CGRect(x: 1512, y: 0, width: 1280, height: 720))
        let herded = CGRect(x: 100, y: 100, width: 1280, height: 760)
        let restored = WindowPlacement.restore(
            memory, window: herded, screens: [builtIn, shrunk])
        XCTAssertEqual(restored, CGRect(x: 1512, y: 0, width: 1280, height: 720))
    }

    /// Moving the window to the built-in display on purpose replaces the
    /// memory: the rule follows the user, it does not drag them back.
    func testDeliberateMoveBecomesTheNewHome() {
        let onBuiltIn = CGRect(x: 100, y: 100, width: 1280, height: 760)
        let memory = WindowPlacement.remember(window: onBuiltIn, screens: docked)
        XCTAssertEqual(memory?.screenID, "built-in")
        XCTAssertNil(WindowPlacement.restore(memory!, window: onBuiltIn, screens: docked))
    }
}
