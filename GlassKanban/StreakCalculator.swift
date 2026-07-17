import Foundation

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
}
