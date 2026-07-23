import XCTest
import SwiftUI

final class WrappedStatsTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func record(_ date: Date, list: String = "Arbeit", color: Color = .blue) -> CompletionRecord {
        CompletionRecord(date: date, listName: list, listColor: color)
    }

    /// `count` completions spread one per day, ending `endingDaysAgo` before
    /// `now` — enough history to clear the minimum-sample guards.
    private func dailyRecords(count: Int, endingDaysAgo: Int = 0, now: Date, list: String = "Arbeit") -> [CompletionRecord] {
        (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: -(offset + endingDaysAgo), to: now).map { record($0, list: list) }
        }
    }

    private let now = Date(timeIntervalSince1970: 0)

    // MARK: - Empty

    func testEmptyRecordsReturnsDefaults() {
        let stats = WrappedStats.stats(records: [], calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.yearCount, 0)
        XCTAssertEqual(stats.totalCompleted, 0)
        XCTAssertNil(stats.historyStart)
        XCTAssertNil(stats.mostActiveWeekday)
        XCTAssertNil(stats.bestDay)
        XCTAssertNil(stats.mostUsedList)
        XCTAssertNil(stats.milestone)
        XCTAssertTrue(stats.last30.isEmpty)
    }

    // MARK: - Year boundary

    func testYearCountExcludesLastYear() {
        let records = [
            record(date(2025, 12, 31)),
            record(date(2026, 1, 1)),
            record(date(2026, 7, 17)),
        ]
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.yearCount, 2)
        XCTAssertEqual(stats.totalCompleted, 3)
    }

    func testHistoryStartIsEarliestCompletion() {
        let records = [record(date(2026, 3, 4)), record(date(2025, 9, 9)), record(date(2026, 7, 1))]
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.historyStart, date(2025, 9, 9))
    }

    // MARK: - Trend window

    func testLast30IsThirtyDaysOldestFirst() {
        let stats = WrappedStats.stats(records: [record(date(2026, 7, 17))],
                                       calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.last30.count, 30)
        XCTAssertEqual(stats.last30.first?.date, calendar.startOfDay(for: date(2026, 6, 18)))
        XCTAssertEqual(stats.last30.last?.date, calendar.startOfDay(for: date(2026, 7, 17)))
        XCTAssertTrue(stats.last30.last!.didComplete)
    }

    func testThroughputCountsOnlyTheTrendWindow() {
        // 15 completions inside the window, 5 well outside it.
        let inside = (0..<15).map { record(date(2026, 7, 17, hour: 12 - $0 % 12)) }
        let old = (0..<5).map { record(date(2026, 1, 10, hour: $0 + 1)) }
        let stats = WrappedStats.stats(records: inside + old, calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.throughputSampleCount, 15)
        XCTAssertEqual(stats.throughputPerDay, 0.5, accuracy: 0.0001)
    }

    func testConsistencyCountsActiveDaysOutOfThirty() {
        let now = date(2026, 7, 17)
        let stats = WrappedStats.stats(records: dailyRecords(count: 6, now: now), calendar: calendar, now: now)
        XCTAssertEqual(stats.consistencyActiveDays, 6)
        XCTAssertEqual(stats.consistencyRatio, 0.2, accuracy: 0.0001)
    }

    // MARK: - Rankings

    func testRankingsHiddenBelowMinimumSample() {
        let now = date(2026, 7, 17)
        let stats = WrappedStats.stats(records: dailyRecords(count: 4, now: now), calendar: calendar, now: now)
        XCTAssertEqual(stats.totalCompleted, 4)
        XCTAssertNil(stats.mostActiveWeekday)
        XCTAssertNil(stats.bestDay)
        XCTAssertNil(stats.mostUsedList)
    }

    func testMostActiveWeekdayPicksTheMode() {
        // 2026-07-16 is a Thursday (weekday 5); three completions there,
        // one each on two other days.
        let records = [
            record(date(2026, 7, 16, hour: 9)),
            record(date(2026, 7, 9, hour: 9)),
            record(date(2026, 7, 2, hour: 9)),
            record(date(2026, 7, 14)),
            record(date(2026, 7, 15)),
        ]
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.mostActiveWeekday?.weekday, 5)
        XCTAssertEqual(stats.mostActiveWeekday?.count, 3)
    }

    func testMostActiveWeekdayTieResolvesToLowerWeekdayNumber() {
        // 2026-07-13 is a Monday (weekday 2), 2026-07-14 a Tuesday (3).
        // Two completions each — Monday must win, every time.
        let records = [
            record(date(2026, 7, 13, hour: 9)), record(date(2026, 7, 13, hour: 10)),
            record(date(2026, 7, 14, hour: 9)), record(date(2026, 7, 14, hour: 10)),
            record(date(2026, 7, 15)),
        ]
        for _ in 0..<20 {
            let stats = WrappedStats.stats(records: records.shuffled(), calendar: calendar, now: date(2026, 7, 17))
            XCTAssertEqual(stats.mostActiveWeekday?.weekday, 2)
        }
    }

    func testBestDayPicksHighestSingleDayCount() {
        let records = [
            record(date(2026, 7, 15, hour: 8)), record(date(2026, 7, 15, hour: 9)),
            record(date(2026, 7, 15, hour: 10)),
            record(date(2026, 7, 16)), record(date(2026, 7, 17)),
        ]
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: date(2026, 7, 17))
        XCTAssertEqual(stats.bestDay?.count, 3)
        XCTAssertEqual(stats.bestDay?.date, calendar.startOfDay(for: date(2026, 7, 15)))
    }

    func testBestDayTieResolvesToEarliestDate() {
        let records = [
            record(date(2026, 7, 15, hour: 8)), record(date(2026, 7, 15, hour: 9)),
            record(date(2026, 7, 16, hour: 8)), record(date(2026, 7, 16, hour: 9)),
            record(date(2026, 7, 17)),
        ]
        for _ in 0..<20 {
            let stats = WrappedStats.stats(records: records.shuffled(), calendar: calendar, now: date(2026, 7, 17))
            XCTAssertEqual(stats.bestDay?.date, calendar.startOfDay(for: date(2026, 7, 15)))
        }
    }

    func testMostUsedListPicksHighestCount() {
        let now = date(2026, 7, 17)
        let records = dailyRecords(count: 4, now: now, list: "Arbeit")
            + dailyRecords(count: 2, endingDaysAgo: 10, now: now, list: "Privat")
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: now)
        XCTAssertEqual(stats.mostUsedList?.name, "Arbeit")
        XCTAssertEqual(stats.mostUsedList?.count, 4)
    }

    func testMostUsedListTieResolvesAlphabetically() {
        let now = date(2026, 7, 17)
        let records = dailyRecords(count: 3, now: now, list: "Privat")
            + dailyRecords(count: 3, endingDaysAgo: 10, now: now, list: "Arbeit")
        for _ in 0..<20 {
            let stats = WrappedStats.stats(records: records.shuffled(), calendar: calendar, now: now)
            XCTAssertEqual(stats.mostUsedList?.name, "Arbeit")
        }
    }

    // MARK: - Milestone

    func testMilestoneFiresWhenThresholdCrossedThisWeek() {
        let now = date(2026, 7, 17)
        // 48 completions well before the recent window, 4 within it → the
        // 50th landed in the last few days.
        let records = dailyRecords(count: 48, endingDaysAgo: 20, now: now)
            + dailyRecords(count: 4, now: now)
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: now)
        XCTAssertEqual(stats.yearCount, 52)
        XCTAssertEqual(stats.milestone, 50)
    }

    func testMilestoneSilentWhenThresholdCrossedLongAgo() {
        let now = date(2026, 7, 17)
        // All 60 finished more than a week ago: the 50th is old news.
        let records = dailyRecords(count: 60, endingDaysAgo: 20, now: now)
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: now)
        XCTAssertGreaterThan(stats.yearCount, 50)
        XCTAssertNil(stats.milestone)
    }

    func testMilestoneSilentBelowFirstThreshold() {
        let now = date(2026, 7, 17)
        let stats = WrappedStats.stats(records: dailyRecords(count: 20, now: now), calendar: calendar, now: now)
        XCTAssertNil(stats.milestone)
    }

    func testMilestoneFiresExactlyOnTheThreshold() {
        let now = date(2026, 7, 17)
        let records = dailyRecords(count: 49, endingDaysAgo: 20, now: now)
            + dailyRecords(count: 1, now: now)
        let stats = WrappedStats.stats(records: records, calendar: calendar, now: now)
        XCTAssertEqual(stats.yearCount, 50)
        XCTAssertEqual(stats.milestone, 50)
    }

    // MARK: - Forecast (Little's Law)

    func testForecastNilWithoutWork() {
        XCTAssertNil(WrappedStats.forecastDaysToDone(wip: 0, throughputPerDay: 0.5, throughputSampleCount: 15))
    }

    func testForecastNilWithoutThroughput() {
        XCTAssertNil(WrappedStats.forecastDaysToDone(wip: 3, throughputPerDay: 0, throughputSampleCount: 0))
    }

    func testForecastNilBelowMinimumSample() {
        XCTAssertNil(WrappedStats.forecastDaysToDone(wip: 3, throughputPerDay: 0.1, throughputSampleCount: 3))
    }

    func testForecastIsWIPOverThroughput() {
        let days = WrappedStats.forecastDaysToDone(wip: 3, throughputPerDay: 0.5, throughputSampleCount: 15)
        XCTAssertEqual(days ?? 0, 6.0, accuracy: 0.0001)
    }
}
