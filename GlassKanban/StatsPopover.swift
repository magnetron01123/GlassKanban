import SwiftUI

/// The streak flame. It fills as the day's work progresses:
/// grey outline (nothing done yet) → half orange → full orange gradient once
/// the personal daily target is reached (goal-gradient effect).
struct FlameIcon: View {
    let level: Int
    /// Sized by its context rather than fixed: this sits beside 12pt text in
    /// the toolbar and beside a 52pt number in the popover, and a glyph that
    /// ignores its companion text reads as misaligned in one of the two.
    var size: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: level == 0 ? "flame" : "flame.fill")
            .font(.system(size: size))
            .foregroundStyle(style)
            // Reaching the day's target is the reward moment the concept asks
            // for; without this it is a one-frame glyph swap. The crossfade
            // stays under Reduce Motion — it is a dissolve, not travel — but
            // the bounce is motion and has to go. Feeding it a value that
            // never changes is how it is switched off without a second code
            // path drifting out of sync with this one.
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: reduceMotion ? 0 : level)
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

/// Everything behind the toolbar flame, in one window.
///
/// **One headline, one list.** These numbers were a 2×2 grid of tiles for
/// several passes and never stopped reading as clutter, because a grid claims
/// its cells are peers and these are not: today's count, current load, a
/// forecast and a year total have nothing in common but the window they sit
/// in. Reading them meant finding four small labels under four large numbers
/// and working out which belonged to which. A label-left/value-right list is
/// what the system itself uses wherever unlike figures are shown together —
/// Battery, Screen Time, Settings — and it removes the guesswork: the label
/// is always beside its number. It also lets an unavailable figure simply not
/// appear, where a grid needed a placeholder to avoid looking broken.
///
/// One number is set large, and it is the streak: the reason the flame is in
/// the toolbar. Everything else stays at reading size, so nothing competes.
///
/// Two tabs rather than two windows: "Jetzt" answers *how is it going right
/// now*, "Rückblick" answers *what am I like*.
///
/// The content carries no glass of its own — the popover already *is* the
/// app's chrome glass, and glass inside glass renders as a boxed artifact
/// (the same rule every toolbar item follows). The wells are the lanes'
/// recessed fill at panel scale, which is depth without a second blur.
///
/// Tooltips here use `.help()` rather than the board's own `boardTooltip`:
/// `TooltipHost` lives at the board's root and a popover is a separate window
/// outside that hierarchy — the same reason the toolbar keeps `.help`.
struct StatsPopover: View {
    let streak: StreakStats
    let wrapped: WrappedStats
    /// Live board state, not history — so it is passed in rather than folded
    /// into `WrappedStats`, which is a pure function of completion dates.
    let wip: Int
    let wipLimit: Int?

    private enum Tab: String, CaseIterable, Identifiable {
        case now, past
        var id: String { rawValue }
        var title: String {
            switch self {
            case .now: "Jetzt"
            case .past: "Rückblick"
            }
        }
    }

    @State private var tab: Tab = .now
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar
            switch tab {
            case .now: nowTab
            case .past: pastTab
            }
        }
        // 16 all round: the standard macOS popover inset, and the value the
        // rest of the spacing here is a multiple of.
        .padding(16)
        // 330: the width at which a real Reminders list name ("Gemeinsame
        // Aufgaben") still sets at the same size as every other value. Below
        // it the row shrank its text, and one value a size smaller than the
        // rest is the sort of thing you notice without being able to name.
        .frame(width: 330, alignment: .leading)
        // The two tabs are different heights; without this the popover would
        // adopt whatever SwiftUI proposes rather than its content's own size.
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Structure

    /// The platform's own control for switching between peer views.
    ///
    /// This was two plain text labels, on the argument that a segmented
    /// control is a slab of chrome in a window meant to be only numbers. That
    /// argument loses: the inactive label read as disabled text rather than
    /// as something to click, which is a discoverability defect no amount of
    /// restraint pays for. The standard control also announces itself
    /// correctly to VoiceOver for free, and on macOS 26 it is *itself* Liquid
    /// Glass. Reaching for the system control is how the effect gets rendered
    /// properly rather than imitated.
    private var tabBar: some View {
        Picker("Ansicht", selection: $tab) {
            ForEach(Tab.allCases) { candidate in
                Text(candidate.title).tag(candidate)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // Full width, like every segmented switcher the system puts at the
        // top of a panel. Hugging its labels left it floating in the corner
        // as one more loose element on the pile.
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    /// The recessed group that holds a section — the lanes' own treatment at
    /// panel scale, and the shape the system gives an inset group in
    /// Settings. Fill only, no border: depth on this board comes from a
    /// recess, and an outline would make it a box drawn on glass.
    private func well(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Board.wellShape.fill(Board.columnFill(scheme)))
            .overlay {
                // A 6% wash is exactly the kind of boundary Increase Contrast
                // exists to harden.
                if contrast == .increased {
                    Board.wellShape.strokeBorder(Board.columnBorder(contrast), lineWidth: 1)
                }
            }
    }

    // MARK: - Jetzt

    private var nowTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            hero
            well {
                rows {
                    row("Heute",
                        Self.tasks(streak.todayCount),
                        // Clearing the personal daily average is the reward,
                        // and it is carried by a glyph rather than a coloured
                        // label: the board's badge rule is measured, and
                        // orange at reading size on a light surface lands
                        // under the contrast floor.
                        mark: streak.todayCount >= max(1, streak.dailyTarget) ? "flame.fill" : nil,
                        help: "Dein Schnitt an aktiven Tagen: \(Self.tasks(max(1, streak.dailyTarget))).")

                    row("In Bearbeitung", wipValue, help: wipHelp)

                    if let days = forecastDays {
                        row("Bis fertig",
                            "\(days.formatted(.number.precision(.fractionLength(days < 10 ? 1 : 0)))) \(days == 1 ? "Tag" : "Tage")",
                            help: "Schätzung: Aufgaben in Bearbeitung geteilt durch dein Tempo der letzten \(WrappedStats.trendWindowDays) Tage.")
                    }

                    row("Dieses Jahr",
                        "\(wrapped.yearCount)",
                        mark: wrapped.milestone != nil ? "flag.fill" : nil,
                        help: wrapped.milestone.map {
                            "Meilenstein erreicht: \($0) erledigte Aufgaben in diesem Jahr."
                        })
                }
            }
            well { trendSection }
        }
    }

    /// The streak, alone on the glass above the wells. It is the only figure
    /// here set large, and the only one that needs no label to be understood
    /// at a glance.
    private var hero: some View {
        // Baseline-aligned, not centred. Centring put the flame beside the
        // middle of the whole text stack, which is level with the number's
        // lower half — the glyph has to sit on the same line the number
        // stands on, the way a currency symbol does.
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            FlameIcon(level: streak.flameLevel, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(streak.current)")
                    .font(BoardText.heroValue)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(
                        streak.current == 0
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(Color.orange.gradient))
                Text(streak.current == 1 ? "Tag in Folge" : "Tage in Folge")
                    .font(BoardText.body)
                    .foregroundStyle(.secondary)
                if let note = heroNote {
                    // Ranked by weight and system text colour, never by an
                    // orange label — see the badge rule above. The reward is
                    // the only primary-coloured line under the number; the
                    // invitation steps back to secondary.
                    Text(note.text)
                        .font(BoardText.body)
                        .fontWeight(note.isReward ? .semibold : .regular)
                        .foregroundStyle(note.isReward ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Self.days(streak.current)) in Folge." + (heroNote.map { " \($0.text)." } ?? ""))
    }

    /// One line, three jobs, in strict priority — an invitation while today is
    /// still empty, otherwise the goal gradient toward the personal record,
    /// otherwise nothing.
    ///
    /// It never reports a shortfall. "Heute 0 erledigt" would be the one line
    /// in this window that reads as an accusation, and a board whose rule is
    /// to reward and never punish does not get to say that.
    private var heroNote: (text: String, isReward: Bool)? {
        guard streak.todayCount > 0 else {
            return (streak.current == 0
                        ? "Eine Aufgabe startet eine neue Folge"
                        : "Eine Aufgabe hält die Folge",
                    false)
        }
        guard streak.current > 0, streak.best > 0 else { return nil }
        if streak.current >= streak.best {
            return ("Dein längster Lauf bisher", true)
        }
        // Goal-gradient (Hull): closeness to the goal is what accelerates
        // effort — so this only appears once the record is actually in reach.
        // "Noch 38 Tage" is not a pull, it is a wall.
        let gap = streak.best - streak.current
        guard gap <= Self.recordInReachDays else { return nil }
        return (gap == 1 ? "Noch 1 Tag bis zum Rekord" : "Noch \(gap) Tage bis zum Rekord", true)
    }

    private static let recordInReachDays = 5

    private var forecastDays: Double? {
        WrappedStats.forecastDaysToDone(
            wip: wip,
            throughputPerDay: wrapped.throughputPerDay,
            throughputSampleCount: wrapped.throughputSampleCount)
    }

    /// "3 von 3" rather than a row of dots. The dots were the only element in
    /// the window with their own visual language, and spelling the limit out
    /// says the same thing without one.
    private var wipValue: String {
        guard let wipLimit else { return "\(wip)" }
        return "\(wip) von \(wipLimit)"
    }

    private var wipHelp: String {
        guard wipLimit != nil else { return "Aufgaben, die gerade in Bearbeitung sind." }
        return "Dein selbst gesetztes Limit für „In Bearbeitung“."
    }

    // MARK: - Rückblick

    private var pastTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            well {
                rows {
                    row("Längste Folge", Self.days(streak.best))

                    if let best = wrapped.bestDay {
                        row("Bester Tag",
                            Self.tasks(best.count),
                            help: best.date.formatted(date: .long, time: .omitted))
                    }
                    if let rank = wrapped.mostActiveWeekday {
                        row("Stärkster Wochentag",
                            Calendar.current.weekdaySymbols[rank.weekday - 1],
                            help: "\(Self.tasks(rank.count)) — mehr als an jedem anderen Wochentag.")
                    }
                    if let rank = wrapped.mostUsedList {
                        row("Häufigste Liste",
                            rank.name,
                            dot: rank.color,
                            help: Self.tasks(rank.count))
                    }
                }
            }
            // A footnote about the group, below it and indented to its
            // content edge — the system's own group-footer position, where a
            // note about the numbers never reads as one of them. A real month
            // rather than a vague "letzte 13 Monate", which is the kind of
            // range nobody can check.
            if let since = historySince {
                Text(since)
                    .font(BoardText.meta)
                    // Tertiary on glass is already near the contrast floor;
                    // under Increase Contrast it has to step up, or the one
                    // line that says which period these numbers cover is the
                    // first thing to disappear for the people who asked for
                    // more contrast.
                    .foregroundStyle(contrast == .increased
                        ? AnyShapeStyle(.secondary)
                        : AnyShapeStyle(.tertiary))
                    .padding(.leading, 12)
            }
        }
    }

    private var historySince: String? {
        guard let start = wrapped.historyStart else { return nil }
        return "Seit \(start.formatted(.dateTime.month(.wide).year()))"
    }

    // MARK: - Trend

    /// The last 30 days as a shape, under a label that says so. The bars once
    /// stood alone at the foot of the window, and an unlabelled chart is the
    /// difference between minimal and unfinished — quiet is allowed,
    /// unexplained is not. Per-day figures stay in each bar's tooltip.
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte 30 Tage")
                .font(BoardText.body)
                .foregroundStyle(.secondary)
            trendRow
        }
    }

    private var trendRow: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(wrapped.last30) { day in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(day.didComplete ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(.quaternary))
                    .frame(height: barHeight(day))
                    .help(trendHelp(day))
            }
        }
        .frame(height: 24, alignment: .bottom)
        // Otherwise this is 30 VoiceOver stops that each say nothing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Letzte \(WrappedStats.trendWindowDays) Tage: an \(wrapped.consistencyActiveDays) Tagen etwas erledigt.")
    }

    private func barHeight(_ day: DayCompletion) -> CGFloat {
        guard day.count > 0 else { return 3 }
        let peak = max(1, wrapped.last30.map(\.count).max() ?? 1)
        return 7 + CGFloat(day.count) / CGFloat(peak) * 17
    }

    private func trendHelp(_ day: DayCompletion) -> String {
        let calendar = Calendar.current
        let when: String
        if calendar.isDateInToday(day.date) {
            when = "Heute"
        } else if calendar.isDateInYesterday(day.date) {
            when = "Gestern"
        } else {
            when = day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        return "\(when): \(Self.tasks(day.count))"
    }

    // MARK: - Rows

    private func rows(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 9) { content() }
    }

    /// Label left, value right — the shape the system gives any list of
    /// unlike figures. The label is never further from its value than the
    /// width of one well.
    private func row(
        _ label: String,
        _ value: String,
        dot: Color? = nil,
        mark: String? = nil,
        help: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(BoardText.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
            if let mark {
                Image(systemName: mark)
                    .font(BoardText.glyph)
                    .foregroundStyle(Color.orange)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(BoardText.value)
                .monospacedDigit()
                .contentTransition(.numericText())
                // A list name is user-chosen and can be arbitrarily long;
                // shrinking beats an ellipsis that hides which list it was.
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .modifier(OptionalHelp(text: help))
    }

    /// German plurals — "1 Tag" but "2 Tage", "1 Aufgabe" but "2 Aufgaben".
    private static func days(_ count: Int) -> String {
        count == 1 ? "1 Tag" : "\(count) Tage"
    }

    private static func tasks(_ count: Int) -> String {
        count == 1 ? "1 Aufgabe" : "\(count) Aufgaben"
    }
}

/// Attaches a row's explanation to both the pointer and VoiceOver.
///
/// `.help()` takes a non-optional string, and an empty one still attaches a
/// tooltip that flashes an empty box on hover — hence the optional.
///
/// The same words go to `accessibilityValue`, not `accessibilityHint`: a hint
/// tells you what an action *will do*, and none of these are actions.
private struct OptionalHelp: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content
                .help(text)
                .accessibilityValue(text)
        } else {
            content
        }
    }
}
