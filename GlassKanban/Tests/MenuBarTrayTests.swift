import XCTest
import AppKit

/// The rules the menu bar tray draws by.
final class MenuBarTrayTests: XCTestCase {

    /// Pinned: the cap is what keeps the tray from growing off the bottom of
    /// the screen when a section holds twenty rows.
    func testTheRowCapIsPinned() {
        XCTAssertEqual(MenuBarTray.rowCap, 6)
        XCTAssertEqual(MenuBarTray.doneRowCap, 3)
    }

    /// The working sections take the full cap; Erledigt is a confirmation,
    /// not a list, and stops at three.
    func testErledigtShowsFewerRowsThanTheWorkingSections() {
        XCTAssertEqual(MenuBarTray.rowCap(for: .next), MenuBarTray.rowCap)
        XCTAssertEqual(MenuBarTray.rowCap(for: .inProgress), MenuBarTray.rowCap)
        XCTAssertEqual(MenuBarTray.rowCap(for: .done), MenuBarTray.doneRowCap)
    }

    /// The Backlog rests at eight — the board's fifteen would be half the
    /// screen in a panel — and shows the rest behind the board's own line.
    func testTheBacklogRestsAtItsOwnCap() {
        XCTAssertEqual(MenuBarTray.rowCap(for: .backlog), MenuBarTray.backlogRowCap)
        XCTAssertEqual(MenuBarTray.backlogRowCap, 8)
    }

    // MARK: - What rests, what folds

    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 12))! }

    private func card(_ title: String, due: Date? = nil, recurring: Bool = false,
                      status: KanbanStatus = .backlog) -> KanbanCard {
        KanbanCard(
            id: title, title: title, notesPreview: "", notesExcerpt: "", dueDate: due,
            priority: 0, status: status, listID: "l", listName: "L", listColor: .accentColor,
            completionDate: nil, isRecurring: recurring, lastModifiedDate: nil, creationDate: nil)
    }

    /// The Backlog folds exactly as the board does: a recurring card whose
    /// turn has not come rests behind the line, here as there.
    func testTheBacklogFoldsNotYetDueCardsLikeTheBoard() {
        let later = calendar.date(byAdding: .day, value: 10, to: now)!
        let cards = [card("ripe"), card("chore", due: later, recurring: true)]
        let resting = MenuBarTray.restingRows(
            cards, in: .backlog, foldsNotYetDue: true, calendar: calendar, now: now)
        XCTAssertEqual(resting.map(\.title), ["ripe"])
        // The same preference as the board's switches the cut off.
        let all = MenuBarTray.restingRows(
            cards, in: .backlog, foldsNotYetDue: false, calendar: calendar, now: now)
        XCTAssertEqual(all.count, 2)
    }

    /// Past the cap the pile folds regardless of ripeness.
    func testTheBacklogCapFoldsARipePile() {
        let cards = (0..<12).map { card("c\($0)") }
        let resting = MenuBarTray.restingRows(
            cards, in: .backlog, foldsNotYetDue: true, calendar: calendar, now: now)
        XCTAssertEqual(resting.count, MenuBarTray.backlogRowCap)
    }

    /// The other sections rest at their first rows, nothing more subtle.
    func testTheOtherSectionsRestAtTheirFirstRows() {
        let cards = (0..<10).map { card("c\($0)", status: .next) }
        XCTAssertEqual(
            MenuBarTray.restingRows(cards, in: .next, foldsNotYetDue: true).count, MenuBarTray.rowCap)
        XCTAssertEqual(
            MenuBarTray.restingRows(cards, in: .done, foldsNotYetDue: true).count, MenuBarTray.doneRowCap)
        XCTAssertEqual(
            MenuBarTray.restingRows(Array(cards.prefix(2)), in: .inProgress, foldsNotYetDue: true).count, 2)
    }

    // MARK: - The stage symbols

    /// Pinned, all four. A symbol in front of a head is a contract with the
    /// eye: it is learned once and then read instead of the word. Renaming
    /// one silently is the same as moving a button.
    func testTheStageSymbolsArePinned() {
        XCTAssertEqual(KanbanStatus.backlog.traySymbolName, "tray")
        XCTAssertEqual(KanbanStatus.next.traySymbolName, "circle")
        XCTAssertEqual(KanbanStatus.inProgress.traySymbolName, "circle.lefthalf.filled")
        XCTAssertEqual(KanbanStatus.done.traySymbolName, "checkmark.circle")
    }

    /// Four stages, four different glyphs — two lanes sharing one would make
    /// the symbol worse than no symbol.
    func testEveryStageHasASymbolOfItsOwn() {
        let names = Set(KanbanStatus.allCases.map(\.traySymbolName))
        XCTAssertEqual(names.count, KanbanStatus.allCases.count)
    }

    /// Every name actually resolves to a system symbol. A typo here draws
    /// nothing at all, and an empty field in front of a head reads as a
    /// layout bug rather than as a missing image.
    func testEveryStageSymbolExistsInTheSystem() {
        for status in KanbanStatus.allCases {
            XCTAssertNotNil(
                NSImage(systemSymbolName: status.traySymbolName, accessibilityDescription: nil),
                "no system symbol named \(status.traySymbolName)")
        }
    }

    // MARK: - The dwell time

    /// Only the lane where sitting still is a question. In the Backlog it is
    /// the normal state, and a finished card's age says nothing at all.
    func testOnlyInProgressReportsItsDwellTime() {
        let old = KanbanCard.agingThresholdDays + 4
        XCTAssertTrue(MenuBarTray.showsDwellTime(status: .inProgress, days: old))
        XCTAssertFalse(MenuBarTray.showsDwellTime(status: .backlog, days: old))
        XCTAssertFalse(MenuBarTray.showsDwellTime(status: .next, days: old))
        XCTAssertFalse(MenuBarTray.showsDwellTime(status: .done, days: old))
    }

    /// The board's threshold, not a second one: a card that says "3 Tage" on
    /// the board must not stay silent in the panel.
    func testTheDwellTimeStartsAtTheBoardsThreshold() {
        XCTAssertFalse(MenuBarTray.showsDwellTime(
            status: .inProgress, days: KanbanCard.agingThresholdDays - 1))
        XCTAssertTrue(MenuBarTray.showsDwellTime(
            status: .inProgress, days: KanbanCard.agingThresholdDays))
    }

    /// A card the board never moved and Reminders never dated has no age to
    /// report — and an unknown age must not read as "today".
    func testAnUnknownDwellTimeSaysNothing() {
        XCTAssertFalse(MenuBarTray.showsDwellTime(status: .inProgress, days: nil))
    }

    /// Quit belongs in the tray only when the tray is the only way to reach
    /// the app — with a Dock icon there is already one, and a second would be
    /// chrome that says what the Dock already says.
    func testQuitIsOfferedOnlyWithoutADockIcon() {
        XCTAssertTrue(MenuBarTray.offersQuit(.menuBar))
        XCTAssertFalse(MenuBarTray.offersQuit(.dock))
        XCTAssertFalse(MenuBarTray.offersQuit(.both))
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

    /// Every row moves, Erledigt included. The bar on finished cards existed
    /// only because the refusal a recurring series can raise had nowhere to
    /// appear in the panel; it appears there now, so the rule that made the
    /// panel disagree with the board is gone.
    func testEveryRowMayMoveIncludingFinishedOnes() {
        for status in KanbanStatus.allCases {
            XCTAssertTrue(MenuBarTray.allowsMoving(from: status))
        }
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
