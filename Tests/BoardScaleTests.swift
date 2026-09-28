import XCTest

/// The display size. What can break is the stored value — a spelling that
/// changes silently resets the board to standard — and the fit on a screen
/// too small for four scaled lanes.
final class BoardScaleTests: XCTestCase {

    private var savedValue: Any?
    private var savedSelection: BoardScale?

    override func setUp() {
        super.setUp()
        savedValue = UserDefaults.standard.object(forKey: BoardScale.storageKey)
        savedSelection = BoardScaleController.shared.selection
    }

    /// Writes through the shared controller into the real defaults, like
    /// `AppAppearanceTests` — so the developer's own choice is put back.
    override func tearDown() {
        if let savedSelection {
            BoardScaleController.shared.selection = savedSelection
        }
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: BoardScale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: BoardScale.storageKey)
        }
        super.tearDown()
    }

    /// A persisted contract, like `StoredSetting`'s keys.
    func testRawValuesArePinned() {
        XCTAssertEqual(BoardScale.allCases.map(\.rawValue), ["standard", "large", "extraLarge"])
    }

    /// Standard is exactly the board as it was: 1, not "about 1".
    func testFactorsGrowFromTheUnscaledBoard() {
        XCTAssertEqual(BoardScale.standard.factor, 1)
        XCTAssertEqual(BoardScale.large.factor, 1.2)
        XCTAssertEqual(BoardScale.extraLarge.factor, 1.4)
    }

    func testSelectionPersists() {
        BoardScaleController.shared.selection = .extraLarge
        XCTAssertEqual(BoardScale.stored, .extraLarge)
        BoardScaleController.shared.selection = .standard
        XCTAssertEqual(BoardScale.stored, .standard)
    }

    /// A value from a later version, or a typo, must fall back to the
    /// unscaled board rather than to nothing.
    func testUnknownStoredValueFallsBackToStandard() {
        UserDefaults.standard.set("gigantic", forKey: BoardScale.storageKey)
        XCTAssertEqual(BoardScale.stored, .standard)
        UserDefaults.standard.removeObject(forKey: BoardScale.storageKey)
        XCTAssertEqual(BoardScale.stored, .standard)
    }

    /// The lanes give way before the window hangs off the screen.
    func testMinimumWidthNeverExceedsTheScreen() {
        XCTAssertEqual(BoardScale.fittedMinWidth(natural: 1708, available: 1470), 1470)
        XCTAssertEqual(BoardScale.fittedMinWidth(natural: 1220, available: 2560), 1220)
    }

    /// No screen known yet (the window is not on one): the natural width.
    func testMinimumWidthWithoutAScreen() {
        XCTAssertEqual(BoardScale.fittedMinWidth(natural: 1220, available: nil), 1220)
        XCTAssertEqual(BoardScale.fittedMinWidth(natural: 1220, available: 0), 1220)
    }
}
