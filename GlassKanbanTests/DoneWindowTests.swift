import XCTest
import SwiftUI

/// The Erledigt lane's resting window: last week visible, last month one
/// click away, everything older delegated to the Reminders app.
final class DoneWindowTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    /// Fixed "now", mid-day so the start-of-day maths is visible in tests.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 14))!
    }

    private func daysAgo(_ days: Int, hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    private func card(_ title: String, completed: Date?) -> KanbanCard {
        KanbanCard(
            id: title,
            title: title,
            notesPreview: "",
            notesExcerpt: "",
            dueDate: nil,
            priority: 0,
            status: .done,
            listName: "Test",
            listColor: .accentColor,
            completionDate: completed,
            isRecurring: false,
            lastModifiedDate: nil,
            creationDate: nil)
    }

    private func recentTitles(_ cards: [KanbanCard]) -> [String] {
        DoneWindow.recent(cards, calendar: calendar, now: now).map(\.title)
    }

    // MARK: - Cutoffs

    func testRecentCutoffIsStartOfDaySevenDaysBack() {
        XCTAssertEqual(
            DoneWindow.recentCutoff(calendar: calendar, now: now),
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 16)))
    }

    func testKeptCutoffIsStartOfDayThirtyDaysBack() {
        XCTAssertEqual(
            DoneWindow.keptCutoff(calendar: calendar, now: now),
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 23)))
    }

    // MARK: - Resting window

    func testCompletionOnTheBoundaryDayCountsAsRecent() {
        // Completed at the very start of the seventh day back — still inside.
        let boundary = card("boundary", completed: daysAgo(7, hour: 0))
        XCTAssertEqual(recentTitles([boundary]), ["boundary"])
    }

    func testCompletionJustBeforeTheBoundaryIsHidden() {
        let older = card(
            "older",
            completed: DoneWindow.recentCutoff(calendar: calendar, now: now)
                .addingTimeInterval(-1))
        XCTAssertEqual(recentTitles([older]), [])
    }

    func testTodayCountsAsRecent() {
        XCTAssertEqual(recentTitles([card("today", completed: now)]), ["today"])
    }

    func testFilterKeepsOrderAndDropsOnlyOldCards() {
        // Newest-first, the order the store hands the lane.
        let cards = [
            card("today", completed: daysAgo(0)),
            card("three days", completed: daysAgo(3)),
            card("last week", completed: daysAgo(10)),
            card("last month", completed: daysAgo(29)),
        ]
        XCTAssertEqual(recentTitles(cards), ["today", "three days"])
    }

    func testMissingCompletionDateIsNeverRecent() {
        // A done card without a date has no place in a time window.
        XCTAssertEqual(recentTitles([card("undated", completed: nil)]), [])
    }

    func testEmptyLaneStaysEmpty() {
        XCTAssertEqual(recentTitles([]), [])
    }
}
