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
/// Two tabs rather than two windows: "Jetzt" answers *how is it going right
/// now*, "Rückblick" answers *what am I like*. Both are the same question at
/// different distances, and stacking a sheet on top of a popover would make a
/// glance feel like navigation.
///
/// The content carries no glass of its own — the popover already *is* the
/// app's chrome glass, and glass inside glass renders as a boxed artifact
/// (the same rule every toolbar item follows).
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
        // 360, not 340: at the narrower width a real Reminders list name
        // ("Gemeinsame Aufgaben") truncated in the retrospective's grid.
        .frame(width: 360, alignment: .leading)
        // The two tabs are different heights; without this the popover would
        // adopt whatever SwiftUI proposes rather than its content's own size.
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tabs

    /// The platform's own control for switching between peer views.
    ///
    /// This was two plain text labels, on the argument that a segmented
    /// control is a slab of chrome in a window meant to be only numbers. That
    /// argument loses: the inactive label read as disabled text rather than
    /// as something to click, which is a discoverability defect no amount of
    /// restraint pays for. The standard control also announces itself
    /// correctly to VoiceOver for free, and on macOS 26 it is *itself* Liquid
    /// Glass — the selected segment is a floating glass capsule. Reaching for
    /// the system control is how the effect gets rendered properly rather
    /// than imitated.
    private var tabBar: some View {
        Picker("Ansicht", selection: $tab) {
            ForEach(Tab.allCases) { candidate in
                Text(candidate.title).tag(candidate)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.bottom, 20)
    }

    // MARK: - Jetzt

    private var nowTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            hero
            nowGrid
            trendRow
        }
    }

    /// The streak at the size it deserves — it is the reason the flame is in
    /// the toolbar at all. Underneath sits a single adaptive line that does
    /// three jobs and never two at once (see `heroNote`).
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
                    // Rank by weight and system text colour, never by an
                    // orange label. The board's badge rule is measured, not a
                    // preference: system colours are calibrated as fills and
                    // glyphs, and orange at 12pt on a light surface lands far
                    // under the contrast floor. The reward reads as the only
                    // primary-coloured line under the number; the invitation
                    // steps back to secondary.
                    Text(note.text)
                        .font(BoardText.body)
                        .fontWeight(note.isReward ? .semibold : .regular)
                        .foregroundStyle(note.isReward ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                }
            }
        }
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
        return (gap == 1 ? "Noch 1 Tag bis zu deinem Rekord" : "Noch \(gap) Tage bis zu deinem Rekord", true)
    }

    private static let recordInReachDays = 5

    private var nowGrid: some View {
        // Top-aligned, not centred: the WIP cell is taller than its neighbour
        // because of the capacity dots, and a centred row would push the
        // number beside it half a line down out of alignment.
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 20) {
            GridRow {
                todayTile
                wipTile
            }
            GridRow {
                // Year on the left, forecast on the right: the forecast is the
                // one tile that can be absent, and a gap at the trailing edge
                // is far less conspicuous than one in the middle of the grid.
                yearTile
                forecastTile
            }
        }
    }

    /// Today's count, praised when it clears the personal daily average —
    /// which `StreakStats` already computes for the flame. Above the average
    /// the label turns into quiet praise; below it, it says nothing at all,
    /// so there is no quota to fall short of.
    private var todayTile: some View {
        let isStrong = streak.todayCount >= max(1, streak.dailyTarget)
        // The praise is carried by a glyph rather than a coloured label, for
        // the same measured reason as the hero line above — and it makes the
        // reward and the milestone read as one family of mark.
        return tile(
            value: "\(streak.todayCount)",
            label: isStrong ? "Starker Tag" : "Heute",
            help: isStrong
                ? "Mehr als an einem durchschnittlichen Tag (\(Self.tasks(max(1, streak.dailyTarget))))."
                : "Heute erledigte Aufgaben.",
            mark: isStrong ? "flame.fill" : nil)
    }

    /// The milestone rides on this number instead of standing beside it: a
    /// separate capsule reading "100 erledigt dieses Jahr" directly under a
    /// tile reading "105 · Dieses Jahr" was two elements saying one thing.
    private var yearTile: some View {
        tile(
            value: "\(wrapped.yearCount)",
            label: "Dieses Jahr",
            help: wrapped.milestone.map { "Meilenstein erreicht: \($0) erledigte Aufgaben in diesem Jahr." },
            mark: wrapped.milestone != nil ? "flag.fill" : nil)
    }

    private var wipTile: some View {
        tile(value: "\(wip)", label: "In Bearbeitung", help: wipHelp) {
            // The limit as dots rather than "3 von 3": capacity is a shape you
            // can read at a glance, and dots never turn a full lane into a
            // warning the way a red fraction would. Being at the limit is
            // working as intended, not a problem to flag.
            if let wipLimit {
                HStack(spacing: 4) {
                    ForEach(0..<max(wipLimit, wip), id: \.self) { index in
                        Circle()
                            .fill(index < wip ? AnyShapeStyle(Board.wipLimitTint) : AnyShapeStyle(.quaternary))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var wipHelp: String {
        guard let wipLimit else { return "Aufgaben, die gerade in Bearbeitung sind." }
        return "Dein Limit für „In Bearbeitung“ liegt bei \(wipLimit)."
    }

    /// Little's Law. Labelled as an estimate on purpose: the value rises the
    /// moment another card is pulled in — which is exactly the point a WIP
    /// limit makes — so a label like "Ø bis fertig" would promise a
    /// measurement and then look broken.
    @ViewBuilder
    private var forecastTile: some View {
        if let days = WrappedStats.forecastDaysToDone(
            wip: wip,
            throughputPerDay: wrapped.throughputPerDay,
            throughputSampleCount: wrapped.throughputSampleCount) {
            tile(
                value: days.formatted(.number.precision(.fractionLength(days < 10 ? 1 : 0))),
                unit: days == 1 ? "Tag" : "Tage",
                label: "Bis fertig",
                help: "Schätzung: Aufgaben in Bearbeitung geteilt durch dein Tempo der letzten \(WrappedStats.trendWindowDays) Tage.")
        } else {
            // Nothing in progress, or too little recent data to divide by.
            // An empty cell holds the grid without inventing a number.
            emptyTile
        }
    }

    /// The last 30 days. No labels: the row is a shape, and the numbers behind
    /// it live in each bar's tooltip.
    private var trendRow: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(wrapped.last30) { day in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(day.didComplete ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(.quaternary))
                    .frame(height: barHeight(day))
                    .help(trendHelp(day))
            }
        }
        .frame(height: 26, alignment: .bottom)
        // Otherwise this is 30 VoiceOver stops that each say nothing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Letzte \(WrappedStats.trendWindowDays) Tage: an \(wrapped.consistencyActiveDays) Tagen etwas erledigt.")
    }

    private func barHeight(_ day: DayCompletion) -> CGFloat {
        guard day.count > 0 else { return 3 }
        let peak = max(1, wrapped.last30.map(\.count).max() ?? 1)
        return 7 + CGFloat(day.count) / CGFloat(peak) * 19
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

    // MARK: - Rückblick

    private var pastTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top-aligned, not centred: the WIP cell is taller than its neighbour
        // because of the capacity dots, and a centred row would push the
        // number beside it half a line down out of alignment.
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 20) {
                GridRow {
                    tile(
                        value: "\(streak.best)",
                        unit: streak.best == 1 ? "Tag" : "Tage",
                        label: "Längste Folge")
                    bestDayTile
                }
                GridRow {
                    weekdayTile
                    listTile
                }
            }
            // One line covering all four numbers instead of qualifying each
            // separately — and a real month rather than a vague "letzte 13
            // Monate", which is the kind of range nobody can check.
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
            }
        }
    }

    private var historySince: String? {
        guard let start = wrapped.historyStart else { return nil }
        return "Seit \(start.formatted(.dateTime.month(.wide).year()))"
    }

    @ViewBuilder
    private var bestDayTile: some View {
        if let best = wrapped.bestDay {
            // With a unit, because "5 / Bester Tag" leaves the reader to guess
            // whether five is tasks, hours or the date.
            tile(
                value: "\(best.count)",
                unit: best.count == 1 ? "Aufgabe" : "Aufgaben",
                label: "Bester Tag",
                help: best.date.formatted(date: .long, time: .omitted))
        } else {
            emptyTile
        }
    }

    @ViewBuilder
    private var weekdayTile: some View {
        if let rank = wrapped.mostActiveWeekday {
            tile(
                word: Calendar.current.weekdaySymbols[rank.weekday - 1],
                label: "Stärkster Tag",
                help: "\(Self.tasks(rank.count)) — mehr als an jedem anderen Wochentag.")
        } else {
            emptyTile
        }
    }

    @ViewBuilder
    private var listTile: some View {
        if let rank = wrapped.mostUsedList {
            tile(
                word: rank.name,
                label: "Häufigste Liste",
                help: Self.tasks(rank.count),
                dot: rank.color)
        } else {
            emptyTile
        }
    }

    /// Stands in while there is too little history to name a "most" (see
    /// `WrappedStats.minSampleForRankings`). Holds the grid's shape without
    /// claiming anything.
    private var emptyTile: some View {
        Color.clear.frame(height: 1)
    }

    // MARK: - Building blocks

    private func tile(
        value: String,
        unit: String? = nil,
        label: String,
        help: String? = nil,
        mark: String? = nil,
        @ViewBuilder accessory: () -> some View = { EmptyView() }
    ) -> some View {
        tileBody(label: label, help: help, accessory: accessory) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(BoardText.tileValue)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(BoardText.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                // The one place the board's no-badges rule is relaxed: a glyph
                // beside a number it already belongs to, only while the round
                // number is fresh (see `WrappedStats.milestone`).
                if let mark {
                    // Chip size, not glyph size: beside a 24pt numeral the
                    // board's 9pt inline glyph reads as a speck of dust
                    // rather than a mark.
                    Image(systemName: mark)
                        .font(BoardText.chip)
                        .foregroundStyle(Color.orange)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// A word instead of a number — a weekday, a list name. Set smaller than
    /// `tileValue`: a long word at a number's size wraps and breaks the grid.
    private func tile(word: String, label: String, help: String? = nil, dot: Color? = nil) -> some View {
        tileBody(label: label, help: help, accessory: { EmptyView() }) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 7, height: 7)
                }
                Text(word)
                    .font(BoardText.titleCompact)
                    // List names are user-chosen and can be arbitrarily long.
                    // Shrinking a little is a better failure than an ellipsis
                    // that hides which list it actually was.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
            }
        }
    }

    private func tileBody(
        label: String,
        help: String?,
        @ViewBuilder accessory: () -> some View,
        @ViewBuilder value: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            value()
            Text(label)
                .font(BoardText.meta)
                .foregroundStyle(.secondary)
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// Attaches a tile's explanation to both the pointer and VoiceOver.
///
/// `.help()` takes a non-optional string, and an empty one still attaches a
/// tooltip that flashes an empty box on hover — hence the optional.
///
/// The same words go to `accessibilityValue`, not `accessibilityHint`: a hint
/// tells you what an action *will do*, and none of these are actions. What
/// "27 %" means is the element's value, and reading it as a hint is how a
/// screen reader ends up announcing a number with no idea what it counts.
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
