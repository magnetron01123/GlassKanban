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

    // MARK: - The record line

    private func stats(current: Int, best: Int, today: Int) -> StreakStats {
        StreakStats(current: current, best: best, todayCount: today)
    }

    /// An empty day gets no line — neither a prompt nor a distance.
    func testNoRecordNoteWhileTodayIsEmpty() {
        XCTAssertNil(stats(current: 4, best: 6, today: 0).recordNote)
        XCTAssertNil(stats(current: 0, best: 6, today: 0).recordNote)
    }

    /// The measured fault: day one or two of a first streak is its own
    /// record, and the distance came out as "0 days to the record".
    func testAShortStreakThatIsItsOwnRecordSaysNothing() {
        XCTAssertNil(stats(current: 1, best: 1, today: 1).recordNote)
        XCTAssertNil(stats(current: 2, best: 2, today: 3).recordNote)
    }

    func testLongestYetOnceTheRecordIsWorthNaming() {
        XCTAssertEqual(stats(current: 3, best: 3, today: 1).recordNote, .longestYet)
        XCTAssertEqual(stats(current: 9, best: 9, today: 2).recordNote, .longestYet)
    }

    func testTheDistanceIsNamedOnlyWithinReach() {
        XCTAssertEqual(stats(current: 5, best: 6, today: 1).recordNote, .daysToRecord(1))
        XCTAssertEqual(stats(current: 1, best: 6, today: 1).recordNote, .daysToRecord(5))
        XCTAssertNil(stats(current: 1, best: 7, today: 1).recordNote)
    }

    /// Whatever the numbers, a named distance is never zero or less.
    func testTheDistanceIsNeverZero() {
        for best in 1...12 {
            for current in 1...best {
                if case .daysToRecord(let gap) = stats(current: current, best: best, today: 1).recordNote {
                    XCTAssertGreaterThanOrEqual(gap, 1)
                }
            }
        }
    }
}
