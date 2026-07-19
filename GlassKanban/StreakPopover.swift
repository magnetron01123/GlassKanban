import SwiftUI

/// The streak flame. It fills as the day's work progresses:
/// grey outline (nothing done yet) → half orange → full orange gradient once
/// the personal daily target is reached (goal-gradient effect).
struct FlameIcon: View {
    let level: Int
    /// Sized by its context rather than fixed: this sits beside 12pt text in
    /// the toolbar and beside the 14pt title in the popover, and a glyph that
    /// ignores its companion text reads as misaligned in one of the two.
    var size: CGFloat = 12

    var body: some View {
        Image(systemName: level == 0 ? "flame" : "flame.fill")
            .font(.system(size: size))
            .foregroundStyle(style)
            // Reaching the day's target is the reward moment the concept asks
            // for; without these it is a one-frame glyph swap.
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: level)
            // The button around it carries the spoken label.
            .accessibilityHidden(true)
    }

    private var style: AnyShapeStyle {
        switch level {
        // Secondary, not tertiary: inside the toolbar's glass a tertiary
        // outline reads as a disabled control rather than a state.
        case 0: AnyShapeStyle(.secondary)
        case 1: AnyShapeStyle(Color.orange.opacity(0.7))
        default: AnyShapeStyle(Color.orange.gradient)
        }
    }
}

/// Details behind the streak pill: the current run and what it counts, the
/// last 7 days, today's and this week's progress (Progress Principle) and
/// the longest run — a deliberate moment instead of permanent screen noise.
struct StreakPopover: View {
    let stats: StreakStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    FlameIcon(level: stats.flameLevel, size: 14)
                    Text(title)
                        .font(BoardText.title)
                }
                // Without this the number is a mystery: it says nothing
                // about what is being counted.
                Text(subtitle)
                    .font(BoardText.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            weekStrip

            VStack(alignment: .leading, spacing: 4) {
                statLine("Heute erledigt", Self.tasks(stats.todayCount))
                statLine("Diese Woche", Self.tasks(stats.weekCount))
                statLine("Längste Folge", Self.days(stats.best))
            }
        }
        .padding(16)
    }

    private var title: String {
        stats.current == 0 ? "Keine Folge" : "\(Self.days(stats.current)) in Folge"
    }

    private var subtitle: String {
        stats.current == 0
            ? "Erledige heute eine Aufgabe, um eine Folge zu starten."
            : "So viele Tage nacheinander hast du mindestens eine Aufgabe erledigt."
    }

    /// German plurals — "1 Tag" but "2 Tage", "1 Aufgabe" but "2 Aufgaben".
    private static func days(_ count: Int) -> String {
        count == 1 ? "1 Tag" : "\(count) Tage"
    }

    private static func tasks(_ count: Int) -> String {
        count == 1 ? "1 Aufgabe" : "\(count) Aufgaben"
    }

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(stats.last7) { day in
                VStack(spacing: 3) {
                    Text(weekdayLetter(day.date))
                        .font(BoardText.meta)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(day.didComplete ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(.quaternary))
                        .frame(width: 9, height: 9)
                }
                .frame(maxWidth: .infinity)
                // A filled-vs-grey dot under a one-letter label is two signals
                // VoiceOver cannot read: the letter is ambiguous and the fill
                // carries the entire meaning. Say both.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(dayLabel(day))
            }
        }
    }

    private func dayLabel(_ day: DayCompletion) -> String {
        let calendar = Calendar.current
        let index = calendar.component(.weekday, from: day.date) - 1
        let name = calendar.weekdaySymbols[index]
        return day.didComplete ? "\(name): erledigt" : "\(name): nichts erledigt"
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(BoardText.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(BoardText.body)
                .fontWeight(.medium)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let calendar = Calendar.current
        let index = calendar.component(.weekday, from: date) - 1
        return calendar.veryShortWeekdaySymbols[index]
    }
}
