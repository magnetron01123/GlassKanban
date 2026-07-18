import XCTest
import SwiftUI

/// Sorting for the open lanes: priority first, then due date, then title.
final class CardSortingTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Fixed "today" for every case below.
    private var now: Date { date(2026, 7, 18) }

    private func card(
        _ title: String,
        priority: Int = 0,
        due: Date? = nil,
        modified: Date? = nil
    ) -> KanbanCard {
        KanbanCard(
            id: title,
            title: title,
            notesPreview: "",
            notesExcerpt: "",
            dueDate: due,
            priority: priority,
            status: .backlog,
            listName: "Test",
            listColor: .accentColor,
            completionDate: nil,
            isRecurring: false,
            lastModifiedDate: modified)
    }

    private func sortedTitles(_ cards: [KanbanCard]) -> [String] {
        cards
            .sorted(by: KanbanCard.openLaneOrder(calendar: calendar, now: now))
            .map(\.title)
    }

    // MARK: - Priority rank

    func testPriorityRankOrdersHighToNone() {
        XCTAssertEqual(card("a", priority: 1).priorityRank, 0)
        XCTAssertEqual(card("a", priority: 4).priorityRank, 0)
        XCTAssertEqual(card("a", priority: 5).priorityRank, 1)
        XCTAssertEqual(card("a", priority: 9).priorityRank, 2)
        // "No priority" (0) must sort last despite its low number.
        XCTAssertEqual(card("a", priority: 0).priorityRank, 3)
    }

    // MARK: - Sorting

    func testPriorityBeatsDueDateAmongNonUrgentCards() {
        let cards = [
            card("undated low", priority: 9),
            card("high next year", priority: 1, due: date(2027, 1, 1)),
            card("none tomorrow", priority: 0, due: date(2026, 7, 19)),
            card("medium later", priority: 5, due: date(2026, 12, 1)),
        ]
        XCTAssertEqual(
            sortedTitles(cards),
            ["high next year", "medium later", "undated low", "none tomorrow"])
    }

    // MARK: - Urgency outranks priority

    func testDueTodayFloatsAbovePriorityWork() {
        let cards = [
            card("high in september", priority: 1, due: date(2026, 9, 1)),
            card("unprioritized today", priority: 0, due: now),
        ]
        XCTAssertEqual(sortedTitles(cards), ["unprioritized today", "high in september"])
    }

    func testOverdueFloatsAbovePriorityWork() {
        let cards = [
            card("high in september", priority: 1, due: date(2026, 9, 1)),
            card("unprioritized overdue", priority: 0, due: date(2026, 7, 10)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["unprioritized overdue", "high in september"])
    }

    func testPriorityStillOrdersWithinTheUrgentGroup() {
        let cards = [
            card("today no priority", priority: 0, due: now),
            card("overdue high", priority: 1, due: date(2026, 7, 10)),
            card("today medium", priority: 5, due: now),
        ]
        XCTAssertEqual(
            sortedTitles(cards),
            ["overdue high", "today medium", "today no priority"])
    }

    // MARK: - Days in column (dwell time)

    func testDaysInColumnCountsWholeDays() {
        XCTAssertEqual(
            card("t", modified: date(2026, 7, 16)).daysInColumn(calendar: calendar, now: now), 2)
        XCTAssertEqual(
            card("t", modified: date(2026, 7, 18)).daysInColumn(calendar: calendar, now: now), 0)
        XCTAssertNil(card("t").daysInColumn(calendar: calendar, now: now))
    }

    func testDaysInColumnIgnoresTimeOfDay() {
        let lateEvening = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 16, hour: 23, minute: 50))!
        XCTAssertEqual(
            card("t", modified: lateEvening).daysInColumn(calendar: calendar, now: now), 2)
    }

    func testTomorrowIsNotUrgent() {
        XCTAssertFalse(
            card("t", due: date(2026, 7, 19)).isUrgent(calendar: calendar, now: now))
        XCTAssertTrue(
            card("t", due: now).isUrgent(calendar: calendar, now: now))
        XCTAssertFalse(card("t").isUrgent(calendar: calendar, now: now))
    }

    func testDueDateOrdersWithinSamePriority() {
        let cards = [
            card("later", priority: 5, due: date(2026, 9, 1)),
            card("soon", priority: 5, due: date(2026, 7, 20)),
            card("mid", priority: 5, due: date(2026, 8, 5)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["soon", "mid", "later"])
    }

    func testUndatedCardsSortAfterDatedOnesOfSamePriority() {
        let cards = [
            card("no date", priority: 5),
            card("has date", priority: 5, due: date(2027, 1, 1)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["has date", "no date"])
    }

    func testTitleBreaksTiesSoOrderNeverJitters() {
        let due = date(2026, 8, 1)
        let cards = [
            card("Zebra", priority: 5, due: due),
            card("apple", priority: 5, due: due),
            card("Mango", priority: 5, due: due),
        ]
        XCTAssertEqual(sortedTitles(cards), ["apple", "Mango", "Zebra"])
    }
}
