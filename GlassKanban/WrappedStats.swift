import SwiftUI

/// One completed reminder, reduced to what the stats view reads: when it was
/// finished and which Reminders list it came from. Captured in
/// `RemindersStore.refresh()` from the completed-reminders fetch that already
/// happens for the streak — no second EventKit query exists for statistics.
struct CompletionRecord: Equatable {
    let date: Date
    let listName: String
    let listColor: Color
}

/// Everything the stats popover shows beyond the streak itself, derived
/// entirely from the completion history the app already reads every refresh.
/// Like `StreakStats`: no stored state, no new persistence, nothing recorded
/// about the user beyond counting reminders they finished.
struct WrappedStats: Equatable {

    /// The weekday most work lands on. `weekday` is `Calendar`'s numbering
    /// (1 = Sunday), matching `Calendar.weekdaySymbols`.
    struct WeekdayRank: Equatable {
        let weekday: Int
        let count: Int
    }

    struct DayRecord: Equatable {
        let date: Date
        let count: Int
    }

    struct ListRank: Equatable {
        let name: String
        let count: Int
        let color: Color
    }

    /// Completions since 1 January. The number the view shows, because a
    /// calendar year needs no explanation — unlike the rolling fetch window.
    var yearCount: Int = 0
    /// Everything in the fetch window. Not displayed; it decides whether the
    /// toolbar pill appears at all (see `BoardView.showsStreakPill`).
    var totalCompleted: Int = 0
    /// The earliest completion on record, so the retrospective can name the
    /// period it actually covers instead of implying "all time".
    var historyStart: Date?

    /// Completions per day over the trend window — the pace behind the
    /// forecast, not a lifetime average a long quiet stretch would flatten.
    var throughputPerDay: Double = 0
    /// Sample size behind `throughputPerDay`, and the forecast's data guard.
    var throughputSampleCount: Int = 0
    /// Days in the trend window with at least one completion.
    var consistencyActiveDays: Int = 0
    /// Daily counts, oldest first, for the trend row.
    var last30: [DayCompletion] = []

    /// The three retrospective rankings. Nil below `minSampleForRankings` —
    /// naming a "most" from four completions would be a claim the data
    /// cannot carry.
    var mostActiveWeekday: WeekdayRank?
    var bestDay: DayRecord?
    var mostUsedList: ListRank?

    /// A round number crossed within the last week, or nil. Deliberately
    /// *recent* rather than "highest ever reached": a badge that shows on
    /// every open for months stops being a moment and becomes furniture.
    /// Derived each time from the same history — nothing is stored to
    /// remember whether it has been shown.
    var milestone: Int?

    /// Share of the trend window with at least one completion, 0...1.
    var consistencyRatio: Double {
        Double(consistencyActiveDays) / Double(Self.trendWindowDays)
    }

    static let trendWindowDays = 30
    /// How far back a milestone still counts as just reached.
    static let milestoneRecentDays = 7
    /// Below this many completions the rankings stay hidden.
    static let minSampleForRankings = 5
    /// Below this many completions in the trend window the forecast hides:
    /// a fortnight with two lucky days would produce a wild estimate.
    static let minSampleForForecast = 5

    /// Round numbers worth a nod. They start at 50 because the first weeks of
    /// a year should not fire one every other day.
    static let milestoneThresholds = [50, 100, 250, 500, 1000, 2500, 5000]

    static func stats(
        records: [CompletionRecord],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> WrappedStats {
        guard !records.isEmpty else { return WrappedStats() }

        let today = calendar.startOfDay(for: now)
        let dates = records.map(\.date)
        let perDay = StreakCalculator.perDayCounts(dates, calendar: calendar)

        // MARK: Trend window

        var last30: [DayCompletion] = []
        for offset in stride(from: trendWindowDays - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            last30.append(DayCompletion(date: day, count: perDay[day] ?? 0))
        }
        let sampleCount = last30.reduce(0) { $0 + $1.count }

        // MARK: This year

        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? today
        let yearCount = dates.filter { $0 >= yearStart }.count

        // MARK: Rankings

        var byWeekday: [Int: Int] = [:]
        for date in dates {
            byWeekday[calendar.component(.weekday, from: date), default: 0] += 1
        }
        // Every tie below resolves deterministically. Dictionary iteration
        // order is unspecified, so a plain `max` would let the "most active"
        // weekday flip between two equal ones on consecutive refreshes.
        let topWeekday = byWeekday.max {
            $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key
        }
        let topDay = perDay.max {
            $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key
        }

        var byList: [String: (count: Int, color: Color)] = [:]
        for record in records {
            byList[record.listName, default: (0, record.listColor)].count += 1
        }
        let topList = byList.min {
            $0.value.count != $1.value.count
                ? $0.value.count > $1.value.count
                : $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }

        let ranked = records.count >= minSampleForRankings

        return WrappedStats(
            yearCount: yearCount,
            totalCompleted: records.count,
            historyStart: dates.min(),
            throughputPerDay: Double(sampleCount) / Double(trendWindowDays),
            throughputSampleCount: sampleCount,
            consistencyActiveDays: last30.filter(\.didComplete).count,
            last30: last30,
            mostActiveWeekday: ranked ? topWeekday.map { WeekdayRank(weekday: $0.key, count: $0.value) } : nil,
            bestDay: ranked ? topDay.map { DayRecord(date: $0.key, count: $0.value) } : nil,
            mostUsedList: ranked ? topList.map { ListRank(name: $0.key, count: $0.value.count, color: $0.value.color) } : nil,
            milestone: recentMilestone(dates: dates, yearStart: yearStart, calendar: calendar, now: now))
    }

    /// The highest round number the year's total crossed within the last week.
    /// Found by comparing the count now against the count a week ago — both
    /// derived from the same dates, so nothing has to be remembered between
    /// launches.
    private static func recentMilestone(
        dates: [Date],
        yearStart: Date,
        calendar: Calendar,
        now: Date
    ) -> Int? {
        let today = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(milestoneRecentDays - 1), to: today) else {
            return nil
        }
        let yearDates = dates.filter { $0 >= yearStart }
        let countNow = yearDates.count
        let countBefore = yearDates.filter { $0 < cutoff }.count
        return milestoneThresholds.last { $0 > countBefore && $0 <= countNow }
    }

    /// Little's Law: cycle time ≈ WIP ÷ throughput. A forecast, not a
    /// measurement — it rises the moment another card is pulled into
    /// progress, which is precisely the point a WIP limit makes. Nil when
    /// nothing is in progress, nothing has been finished lately, or the
    /// recent sample is too thin to divide by.
    static func forecastDaysToDone(
        wip: Int,
        throughputPerDay: Double,
        throughputSampleCount: Int,
        minSampleCount: Int = minSampleForForecast
    ) -> Double? {
        guard wip > 0, throughputPerDay > 0, throughputSampleCount >= minSampleCount else { return nil }
        return Double(wip) / throughputPerDay
    }
}
