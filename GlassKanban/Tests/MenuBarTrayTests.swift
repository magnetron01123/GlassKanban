import XCTest

/// The rules the menu bar tray draws by.
final class MenuBarTrayTests: XCTestCase {

    /// Pinned: the cap is what keeps the tray from growing off the bottom of
    /// the screen when a lane holds twenty cards.
    func testTheRowCapIsPinned() {
        XCTAssertEqual(MenuBarTray.rowCap, 6)
        XCTAssertEqual(MenuBarTray.minimumRows, 3)
    }

    /// Quit belongs in the tray only when the tray is the only way to reach
    /// the app — with a Dock icon there is already one, and a second would be
    /// chrome that says what the Dock already says.
    func testQuitIsOfferedOnlyWithoutADockIcon() {
        XCTAssertTrue(MenuBarTray.offersQuit(.menuBar))
        XCTAssertFalse(MenuBarTray.offersQuit(.dock))
        XCTAssertFalse(MenuBarTray.offersQuit(.both))
    }

    /// Three empty lanes still have to look like lanes.
    func testAnEmptyTrayStillShowsThreeRows() {
        XCTAssertEqual(MenuBarTray.laneRows(next: 0, inProgress: 0, done: 0), 3)
    }

    /// The fullest lane sets the height, and all three follow it.
    func testTheFullestLaneSetsTheHeight() {
        XCTAssertEqual(MenuBarTray.laneRows(next: 5, inProgress: 1, done: 2), 5)
        XCTAssertEqual(MenuBarTray.laneRows(next: 1, inProgress: 2, done: 4), 4)
        XCTAssertEqual(MenuBarTray.laneRows(next: 1, inProgress: 1, done: 1), 3)
    }

    func testTheCapHoldsAgainstAHugeLane() {
        XCTAssertEqual(MenuBarTray.laneRows(next: 20, inProgress: 0, done: 0), MenuBarTray.rowCap)
        XCTAssertEqual(MenuBarTray.laneRows(next: 0, inProgress: 0, done: 99), MenuBarTray.rowCap)
    }

    /// A question that is still standing holds the tray. Nothing else may
    /// move until it is answered — a second drag would overwrite it, which
    /// is answering it silently.
    func testAnOpenTrayQuestionStopsEveryMove() {
        XCTAssertFalse(MenuBarTray.allowsMoves(pendingSource: .tray))
    }

    /// The board's own question does not: it belongs to the board's alert,
    /// and the tray has no business freezing over it.
    func testTheBoardsQuestionLeavesTheTrayAlone() {
        XCTAssertTrue(MenuBarTray.allowsMoves(pendingSource: nil))
        XCTAssertTrue(MenuBarTray.allowsMoves(pendingSource: .board))
    }

    /// The way back out of Erledigt can fail on a recurring series, and only
    /// the board can say so. In the tray it would fail silently.
    func testFinishedCardsCannotBeMovedFromTheTray() {
        XCTAssertFalse(MenuBarTray.allowsMoving(from: .done))
        XCTAssertTrue(MenuBarTray.allowsMoving(from: .next))
        XCTAssertTrue(MenuBarTray.allowsMoving(from: .inProgress))
    }
}

/// The board's rule for when an empty lane speaks — shared with the tray, so
/// the two cannot say different things about the same empty lane.
final class EmptyLaneInvitationTests: XCTestCase {

    /// "In Bearbeitung" invites a pull only when there is something to pull.
    func testInProgressNeedsSomethingUpstream() {
        XCTAssertTrue(KanbanStatus.inProgress.invitesWhenEmpty(nextIsEmpty: false, backlogIsEmpty: true))
        XCTAssertTrue(KanbanStatus.inProgress.invitesWhenEmpty(nextIsEmpty: true, backlogIsEmpty: false))
        XCTAssertFalse(KanbanStatus.inProgress.invitesWhenEmpty(nextIsEmpty: true, backlogIsEmpty: true))
    }

    /// "Als Nächstes" is chosen out of the Backlog; with nothing to choose
    /// from, "Wählen statt sammeln" asks for something impossible.
    func testNextUpNeedsABacklog() {
        XCTAssertTrue(KanbanStatus.next.invitesWhenEmpty(nextIsEmpty: true, backlogIsEmpty: false))
        XCTAssertFalse(KanbanStatus.next.invitesWhenEmpty(nextIsEmpty: true, backlogIsEmpty: true))
    }

    /// Neither is pull-fed: one fills from the "+" and from Reminders, the
    /// other by finishing work. Empty is reason enough.
    func testTheStorageLanesSpeakWheneverTheyAreEmpty() {
        for backlogIsEmpty in [true, false] {
            XCTAssertTrue(KanbanStatus.backlog.invitesWhenEmpty(nextIsEmpty: true, backlogIsEmpty: backlogIsEmpty))
            XCTAssertTrue(KanbanStatus.done.invitesWhenEmpty(nextIsEmpty: true, backlogIsEmpty: backlogIsEmpty))
        }
    }
}
