import XCTest

/// The WIP limit rules that live on `KanbanStatus`. The store's counting is
/// exercised through the board itself; what matters here is that the policy
/// stays where the concept put it: limits on the working lanes only, the
/// interruption on "In Bearbeitung" alone.
final class WIPLimitTests: XCTestCase {

    func testOnlyWorkingLanesCarryALimit() {
        XCTAssertTrue(KanbanStatus.next.supportsWIPLimit)
        XCTAssertTrue(KanbanStatus.inProgress.supportsWIPLimit)
        // Backlog is the standing stack, Erledigt only ever grows.
        XCTAssertFalse(KanbanStatus.backlog.supportsWIPLimit)
        XCTAssertFalse(KanbanStatus.done.supportsWIPLimit)
    }

    /// Kanban limits work *in progress*, not what is merely planned — so a
    /// full queue stays silent and only the working lane asks.
    func testOnlyInProgressInterrupts() {
        XCTAssertTrue(KanbanStatus.inProgress.asksBeforeExceedingLimit)
        XCTAssertFalse(KanbanStatus.next.asksBeforeExceedingLimit)
        XCTAssertFalse(KanbanStatus.backlog.asksBeforeExceedingLimit)
        XCTAssertFalse(KanbanStatus.done.asksBeforeExceedingLimit)
    }

    func testDefaultsFollowThePersonalKanbanRuleOfThumb() {
        XCTAssertEqual(KanbanStatus.inProgress.defaultWIPLimit, 3)
        XCTAssertEqual(KanbanStatus.next.defaultWIPLimit, 5)
        XCTAssertEqual(KanbanStatus.backlog.defaultWIPLimit, 0)
        XCTAssertEqual(KanbanStatus.done.defaultWIPLimit, 0)
    }

    /// Every lane that can be limited must ship with a usable default, so the
    /// feature works without opening Settings once.
    func testEveryLimitableLaneHasANonZeroDefault() {
        for status in KanbanStatus.allCases where status.supportsWIPLimit {
            XCTAssertGreaterThan(
                status.defaultWIPLimit, 0,
                "\(status.rawValue) should start with a real limit")
        }
    }

    /// The limit is a rule about started work, not about what a filter
    /// leaves on screen: a lane that carries one counts all of it.
    func testALimitedLaneCountsTheWholeLaneUnderAFilter() {
        XCTAssertEqual(KanbanStatus.headerCount(visible: 0, total: 2, hasLimit: true), 2)
        XCTAssertEqual(KanbanStatus.headerCount(visible: 1, total: 4, hasLimit: true), 4)
    }

    /// Backlog and Erledigt carry no rule in their count and state what is
    /// on screen, as they always have.
    func testALaneWithoutALimitCountsWhatIsVisible() {
        XCTAssertEqual(KanbanStatus.headerCount(visible: 1, total: 40, hasLimit: false), 1)
    }

    /// Unfiltered, both numbers are the same and the rule changes nothing.
    func testWithoutAFilterBothCountsAgree() {
        XCTAssertEqual(KanbanStatus.headerCount(visible: 3, total: 3, hasLimit: true), 3)
        XCTAssertEqual(KanbanStatus.headerCount(visible: 3, total: 3, hasLimit: false), 3)
    }

    /// A lane that interrupts must be one that actually has a limit.
    func testInterruptingLaneAlsoSupportsALimit() {
        for status in KanbanStatus.allCases where status.asksBeforeExceedingLimit {
            XCTAssertTrue(status.supportsWIPLimit)
        }
    }
}
