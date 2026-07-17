import SwiftUI

/// The streak flame. It fills as the day's work progresses:
/// grey outline (nothing done yet) → half orange → full orange gradient once
/// the personal daily target is reached (goal-gradient effect).
struct FlameIcon: View {
    let level: Int

    var body: some View {
        Image(systemName: level == 0 ? "flame" : "flame.fill")
            .font(.system(size: 11))
            .foregroundStyle(style)
    }

    private var style: AnyShapeStyle {
        switch level {
        case 0: AnyShapeStyle(.tertiary)
        case 1: AnyShapeStyle(Color.orange.opacity(0.7))
        default: AnyShapeStyle(Color.orange.gradient)
        }
    }
}

/// Details behind the streak pill: current run, the last 7 days, today's and
/// this week's progress (Progress Principle), the best run, and the daily
/// motivational quote — a deliberate moment instead of permanent screen noise.
struct StreakPopover: View {
    let stats: StreakStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                FlameIcon(level: stats.flameLevel)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }

            weekStrip

            VStack(alignment: .leading, spacing: 4) {
                statLine("Heute erledigt", "\(stats.todayCount)")
                statLine("Diese Woche", "\(stats.weekCount)")
                statLine("Bester Lauf", "\(stats.best) Tage")
            }

            Divider()

            Text(Quotes.quote())
                .font(.system(size: 12))
                .fontDesign(.serif)
                .italic()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }

    private var title: String {
        stats.current == 0 ? "Noch kein Lauf heute" : "\(stats.current) Tage in Folge"
    }

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(stats.last7) { day in
                VStack(spacing: 3) {
                    Text(weekdayLetter(day.date))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Circle()
                        .fill(day.didComplete ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(.quaternary))
                        .frame(width: 9, height: 9)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let calendar = Calendar.current
        let index = calendar.component(.weekday, from: date) - 1
        return calendar.veryShortWeekdaySymbols[index]
    }
}
