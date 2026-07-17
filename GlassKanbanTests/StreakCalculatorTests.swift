import XCTest

final class StreakCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testEmptyDatesIsZero() {
        XCTAssertEqual(StreakCalculator.streak(completionDates: [], calendar: calendar, now: date(2026, 7, 17)), 0)
    }

    func testThreeConsecutiveDaysEndingToday() {
        let dates = [date(2026, 7, 17), date(2026, 7, 16), date(2026, 7, 15)]
        XCTAssertEqual(StreakCalculator.streak(completionDates: dates, calendar: calendar, now: date(2026, 7, 17)), 3)
    }

    func testGapBreaksStreak() {
        let dates = [date(2026, 7, 17), date(2026, 7, 15)]
        XCTAssertEqual(StreakCalculator.streak(completionDates: dates, calendar: calendar, now: date(2026, 7, 17)), 1)
    }

    func testStreakAliveFromYesterdayWhenTodayEmpty() {
        let dates = [date(2026, 7, 16), date(2026, 7, 15)]
        XCTAssertEqual(StreakCalculator.streak(completionDates: dates, calendar: calendar, now: date(2026, 7, 17)), 2)
    }

    func testStreakDeadWhenLastCompletionTwoDaysAgo() {
        let dates = [date(2026, 7, 15), date(2026, 7, 14)]
        XCTAssertEqual(StreakCalculator.streak(completionDates: dates, calendar: calendar, now: date(2026, 7, 17)), 0)
    }

    func testMultipleCompletionsSameDayCountOnce() {
        let dates = [date(2026, 7, 17, hour: 9), date(2026, 7, 17, hour: 18)]
        XCTAssertEqual(StreakCalculator.streak(completionDates: dates, calendar: calendar, now: date(2026, 7, 17)), 1)
    }
}
