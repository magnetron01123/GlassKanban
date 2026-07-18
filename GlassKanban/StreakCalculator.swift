import Foundation

/// One day in the 7-day strip shown in the streak popover.
struct DayCompletion: Equatable, Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
    var didComplete: Bool { count > 0 }
}

/// Everything the streak UI needs, all derived from completion dates — no
/// stored state, no analysis of behavior beyond counting completed reminders.
struct StreakStats: Equatable {
    var current: Int = 0
    var best: Int = 0
    var todayCount: Int = 0
    var weekCount: Int = 0
    /// Typical completions on an active day; the threshold for a "full" flame.
    var dailyTarget: Int = 1
    /// Last 7 days including today, oldest first.
    var last7: [DayCompletion] = []

    /// 0 = nothing done today (grey flame — the streak is at risk),
    /// 1 = started, 2 = reached the personal daily target (full flame).
    /// Goal-gradient: the flame visibly fills as the day progresses.
    var flameLevel: Int {
        guard todayCount > 0 else { return 0 }
        return todayCount >= max(1, dailyTarget) ? 2 : 1
    }
}

/// Computes the completion streak: the number of consecutive days (ending
/// today, or yesterday if today has no completion yet) on which at least one
/// reminder was completed. Purely derived from completion dates — no state.
enum StreakCalculator {

    static func streak(completionDates: [Date], calendar: Calendar = .current, now: Date = .now) -> Int {
        let days = Set(completionDates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            // The streak is still alive if yesterday had a completion.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Full statistics for the streak popover and the filling flame.
    static func stats(completionDates: [Date], calendar: Calendar = .current, now: Date = .now) -> StreakStats {
        let today = calendar.startOfDay(for: now)

        var perDay: [Date: Int] = [:]
        for date in completionDates {
            perDay[calendar.startOfDay(for: date), default: 0] += 1
        }

        let weekCount = completionDates.filter {
            calendar.isDate($0, equalTo: now, toGranularity: .weekOfYear)
        }.count

        // Daily target = average completions on active days before today,
        // rounded, at least 1. Reaching it fills the flame.
        let activeBeforeToday = perDay.filter { $0.key < today }
        let dailyTarget: Int
        if activeBeforeToday.isEmpty {
            dailyTarget = 1
        } else {
            let total = activeBeforeToday.values.reduce(0, +)
            dailyTarget = max(1, Int((Double(total) / Double(activeBeforeToday.count)).rounded()))
        }

        var last7: [DayCompletion] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            last7.append(DayCompletion(date: day, count: perDay[day] ?? 0))
        }

        return StreakStats(
            current: streak(completionDates: completionDates, calendar: calendar, now: now),
            best: bestRun(days: Set(perDay.keys), calendar: calendar),
            todayCount: perDay[today] ?? 0,
            weekCount: weekCount,
            dailyTarget: dailyTarget,
            last7: last7)
    }

    /// Longest run of consecutive completed days anywhere in the window.
    private static func bestRun(days: Set<Date>, calendar: Calendar) -> Int {
        var best = 0
        for day in days {
            // Only start counting from the first day of a run.
            if let previous = calendar.date(byAdding: .day, value: -1, to: day), days.contains(previous) {
                continue
            }
            var length = 0
            var cursor = day
            while days.contains(cursor) {
                length += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            best = max(best, length)
        }
        return best
    }
}
