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

    // MARK: - Telling a drag apart from a rearrangement
    //
    // The hardest rule here, and the only one whose failure is invisible:
    // AppKit reports "the user dragged the window" and "macOS herded it off a
    // vanishing display" identically. Writing down the second overwrites the
    // memory needed to undo it — the board would learn "I live on the
    // built-in screen now" exactly while being pushed there. Time is the only
    // discriminator available, so these tests pin where the line sits.
    //
    // Lived in the AppKit controller as an `isRearranging` flag until
    // 14.08.2026 and was therefore untestable.

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// Nothing has happened to the screens, so every move is the user's.
    func testAMoveWithNoScreenChangeCounts() {
        XCTAssertTrue(WindowPlacement.countsAsDeliberateMove(at: t0, lastScreenChange: nil))
    }

    func testAMoveRightAfterAScreenChangeDoesNotCount() {
        XCTAssertFalse(WindowPlacement.countsAsDeliberateMove(
            at: t0.addingTimeInterval(0.2), lastScreenChange: t0))
    }

    func testAMoveOnceTheScreensHaveSettledCountsAgain() {
        XCTAssertTrue(WindowPlacement.countsAsDeliberateMove(
            at: t0.addingTimeInterval(WindowPlacement.settleDelay), lastScreenChange: t0))
        XCTAssertTrue(WindowPlacement.countsAsDeliberateMove(
            at: t0.addingTimeInterval(5), lastScreenChange: t0))
    }

    /// The board's own restoring move renews the timestamp, so the `didMove`
    /// it triggers lands inside a fresh settle window. Without this the board
    /// would record the position it had just restored *as if the user had
    /// chosen it* — harmless while it matches, wrong as soon as the frame was
    /// clamped onto a smaller screen.
    func testTheBoardsOwnRestoringMoveDoesNotCount() {
        let restoredAt = t0.addingTimeInterval(WindowPlacement.settleDelay)
        XCTAssertFalse(WindowPlacement.countsAsDeliberateMove(
            at: restoredAt.addingTimeInterval(0.01), lastScreenChange: restoredAt))
    }

    /// A clock that runs backwards (NTP correction, sleep) must not turn the
    /// settle window into a permanent block.
    func testAMoveTimestampedBeforeTheScreenChangeDoesNotCount() {
        XCTAssertFalse(WindowPlacement.countsAsDeliberateMove(
            at: t0.addingTimeInterval(-5), lastScreenChange: t0))
    }
}
