import XCTest

final class FilterTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Priority (EventKit: 0 none, 1–4 high, 5 medium, 6–9 low)

    func testPriorityGroups() {
        XCTAssertTrue(PriorityFilter.high.matches(1))
        XCTAssertTrue(PriorityFilter.high.matches(4))
        XCTAssertFalse(PriorityFilter.high.matches(5))
        XCTAssertTrue(PriorityFilter.medium.matches(5))
        XCTAssertTrue(PriorityFilter.low.matches(6))
        XCTAssertTrue(PriorityFilter.low.matches(9))
        XCTAssertTrue(PriorityFilter.unset.matches(0))
        XCTAssertFalse(PriorityFilter.unset.matches(5))
        XCTAssertTrue(PriorityFilter.all.matches(0))
        XCTAssertTrue(PriorityFilter.all.matches(7))
    }

    // MARK: - Due date (reference "now": Friday, 2026-07-17)

    func testOverdueMatchesPastDatesOnly() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(DueFilter.overdue.matches(date(2026, 7, 16), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.overdue.matches(date(2026, 7, 17, hour: 8), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.overdue.matches(date(2026, 7, 18), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.overdue.matches(nil, calendar: calendar, now: now))
    }

    func testTodayMatchesSameDayRegardlessOfTime() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(DueFilter.today.matches(date(2026, 7, 17, hour: 23), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.today.matches(date(2026, 7, 16), calendar: calendar, now: now))
    }

    func testThisWeekMatchesMondayThroughSunday() {
        let now = date(2026, 7, 17) // Friday of week Mon 13 – Sun 19
        XCTAssertTrue(DueFilter.thisWeek.matches(date(2026, 7, 13), calendar: calendar, now: now))
        XCTAssertTrue(DueFilter.thisWeek.matches(date(2026, 7, 19), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.thisWeek.matches(date(2026, 7, 20), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.thisWeek.matches(date(2026, 7, 12), calendar: calendar, now: now))
    }

    func testNoDateMatchesOnlyNil() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(DueFilter.noDate.matches(nil, calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.noDate.matches(now, calendar: calendar, now: now))
    }
}
