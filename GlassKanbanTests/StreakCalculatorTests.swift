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

    // MARK: - stats

    func testStatsTodayAndWeekCounts() {
        // Three today, one earlier this week (Berlin week starts Monday;
        // 2026-07-17 is a Friday, so 2026-07-13 Monday is the same week).
        let dates = [
            date(2026, 7, 17, hour: 8), date(2026, 7, 17, hour: 12), date(2026, 7, 17, hour: 20),
            date(2026, 7, 13),
        ]
        let stats = StreakCalculator.stats(completionDates: dates, calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.todayCount, 3)
        XCTAssertEqual(stats.weekCount, 4)
        XCTAssertEqual(stats.current, 1)
    }

    func testStatsBestRunFindsLongestPastStreak() {
        // A dead 4-day run in the past, plus a live 1-day run today.
        let past = [date(2026, 6, 1), date(2026, 6, 2), date(2026, 6, 3), date(2026, 6, 4)]
        let stats = StreakCalculator.stats(completionDates: past + [date(2026, 7, 17)],
                                           calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.best, 4)
        XCTAssertEqual(stats.current, 1)
    }

    func testStatsLast7DaysMarksActiveDays() {
        let dates = [date(2026, 7, 17), date(2026, 7, 14), date(2026, 7, 11)]
        let stats = StreakCalculator.stats(completionDates: dates, calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.last7.count, 7)
        // 2026-07-11 is 6 days ago (oldest), 2026-07-14 is 3 days ago, today is last.
        XCTAssertTrue(stats.last7.first!.didComplete)   // 07-11
        XCTAssertTrue(stats.last7.last!.didComplete)    // 07-17
        XCTAssertFalse(stats.last7[1].didComplete)      // 07-12
    }

    func testStatsFlameLevelReachesFullAtDailyTarget() {
        // Two active days before today averaging 2 completions → target 2.
        let history = [
            date(2026, 7, 15, hour: 9), date(2026, 7, 15, hour: 10),
            date(2026, 7, 16, hour: 9), date(2026, 7, 16, hour: 10),
        ]
        let oneToday = StreakCalculator.stats(completionDates: history + [date(2026, 7, 17)],
                                              calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(oneToday.dailyTarget, 2)
        XCTAssertEqual(oneToday.flameLevel, 1)   // started but below target

        let twoToday = StreakCalculator.stats(
            completionDates: history + [date(2026, 7, 17, hour: 8), date(2026, 7, 17, hour: 9)],
            calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(twoToday.flameLevel, 2)   // target reached
    }

    func testStatsFlameLevelZeroWhenNothingToday() {
        let stats = StreakCalculator.stats(completionDates: [date(2026, 7, 16)],
                                           calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.flameLevel, 0)
    }
}
