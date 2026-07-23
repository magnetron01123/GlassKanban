import XCTest

/// Arrow-key movement across the four lanes.
final class BoardNavigationTests: XCTestCase {

    /// Backlog, Als Nächstes, In Bearbeitung, Erledigt — the third lane is
    /// deliberately empty, which is the normal state of a board mid-morning.
    private let lanes = [
        ["b1", "b2", "b3"],
        ["n1", "n2"],
        [],
        ["d1"],
    ]

    private func target(from card: String?, _ direction: BoardNavigation.Direction) -> String? {
        BoardNavigation.target(from: card, direction: direction, lanes: lanes)
    }

    // MARK: - Within a lane

    func testDownAndUpWalkTheLane() {
        XCTAssertEqual(target(from: "b1", .down), "b2")
        XCTAssertEqual(target(from: "b2", .up), "b1")
    }

    /// Stopping rather than wrapping: the lanes are places, and springing from
    /// the last card back to the first loses the sense of where you are.
    func testEndsOfALaneDoNotWrap() {
        XCTAssertNil(target(from: "b1", .up))
        XCTAssertNil(target(from: "b3", .down))
    }

    // MARK: - Across lanes

    func testSidewaysKeepsTheRow() {
        XCTAssertEqual(target(from: "b2", .right), "n2")
        XCTAssertEqual(target(from: "n2", .left), "b2")
    }

    /// The neighbouring lane is shorter, so the focus lands on its last card
    /// instead of falling off the board.
    func testSidewaysClampsToAShorterLane() {
        XCTAssertEqual(target(from: "b3", .right), "n2")
    }

    /// An empty lane has nothing to focus, so it is stepped over rather than
    /// swallowing the keypress.
    func testEmptyLanesAreSkipped() {
        XCTAssertEqual(target(from: "n1", .right), "d1")
        XCTAssertEqual(target(from: "d1", .left), "n1")
    }

    func testEdgesOfTheBoardStopMovement() {
        XCTAssertNil(target(from: "b1", .left))
        XCTAssertNil(target(from: "d1", .right))
    }

    // MARK: - Entering the board

    /// Without this the keyboard has no way onto the board at all.
    func testNoFocusYetLandsOnTheFirstCard() {
        XCTAssertEqual(target(from: nil, .down), "b1")
        XCTAssertEqual(target(from: nil, .right), "b1")
    }

    /// A card that has just been filtered away is no longer a position on the
    /// board, so navigation restarts rather than going nowhere.
    func testUnknownCardFallsBackToTheFirstCard() {
        XCTAssertEqual(target(from: "verschwunden", .down), "b1")
    }

    func testFirstCardSkipsLeadingEmptyLanes() {
        XCTAssertEqual(
            BoardNavigation.target(from: nil, direction: .down, lanes: [[], [], ["x"]]),
            "x")
    }

    func testEmptyBoardHasNowhereToGo() {
        XCTAssertNil(BoardNavigation.target(from: nil, direction: .down, lanes: [[], [], [], []]))
    }
}
