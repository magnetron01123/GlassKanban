import Foundation

/// One day in the popover's trend strip (30 days — see
/// `WrappedStats.trendWindowDays`).
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
    /// Typical completions on an active day; the threshold for a "full" flame.
    var dailyTarget: Int = 1

    /// 0 = nothing done today (grey flame — the streak is at risk),
    /// 1 = started, 2 = reached the personal daily target (full flame).
    /// Goal-gradient: the flame visibly fills as the day progresses.
    var flameLevel: Int {
        guard todayCount > 0 else { return 0 }
        return todayCount >= max(1, dailyTarget) ? 2 : 1
    }
}

extension StreakStats {
    /// The one line the statistics window may put under the streak figure.
    enum RecordNote: Equatable {
        /// The running streak is the longest there has been.
        case longestYet
        /// The record is this many days away, and within reach.
        case daysToRecord(Int)
    }

    /// Below this, "longest streak" describes an accident rather than an
    /// achievement — every first day is a personal best.
    static let minStreakWorthNaming = 3
    /// Goal-gradient (Hull): closeness to the goal is what accelerates
    /// effort, so the distance is named only once the record is in reach.
    /// "38 days to go" is not a pull, it is a wall.
    static let recordInReachDays = 5

    /// A reward, or nothing — never a prompt. Only once something is done
    /// today: an empty day gets no line (02.10.2026; the appeal that stood
    /// there was standing text, see `StatsPopover.heroNote`).
    ///
    /// "Longest yet" only while the record is actually being set, and only
    /// once there is a record worth the word: after the very first task the
    /// line stood there truthfully and meaninglessly, and on a long streak
    /// it then stayed for weeks. A streak that equals a record too small to
    /// name gets nothing at all — it used to fall through to the distance
    /// and report "0 days to the record".
    var recordNote: RecordNote? {
        guard todayCount > 0, current > 0, best > 0 else { return nil }
        if current >= best {
            return best >= Self.minStreakWorthNaming ? .longestYet : nil
        }
        let gap = best - current
        return gap <= Self.recordInReachDays ? .daysToRecord(gap) : nil
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

    /// Buckets completion dates into per-day counts. Shared with `WrappedStats`
    /// so both read the same history through one implementation — the two are
    /// separate types on purpose (one is the flame, the other the stats view),
    /// but they must never disagree about what happened on a given day.
    static func perDayCounts(_ dates: [Date], calendar: Calendar) -> [Date: Int] {
        var perDay: [Date: Int] = [:]
        for date in dates {
            perDay[calendar.startOfDay(for: date), default: 0] += 1
        }
        return perDay
    }

    /// Full statistics for the streak popover and the filling flame.
    static func stats(completionDates: [Date], calendar: Calendar = .current, now: Date = .now) -> StreakStats {
        let today = calendar.startOfDay(for: now)

        let perDay = perDayCounts(completionDates, calendar: calendar)

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

        return StreakStats(
            current: streak(completionDates: completionDates, calendar: calendar, now: now),
            best: bestRun(days: Set(perDay.keys), calendar: calendar),
            todayCount: perDay[today] ?? 0,
            dailyTarget: dailyTarget)
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
