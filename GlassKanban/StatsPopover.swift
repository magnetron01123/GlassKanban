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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar
            switch tab {
            case .now: nowTab
            case .past: pastTab
            }
        }
        .padding(18)
        // 360, not 340: at the narrower width a real Reminders list name
        // ("Gemeinsame Aufgaben") truncated in the retrospective's grid.
        .frame(width: 360, alignment: .leading)
        // The two tabs are different heights; without this the popover would
        // adopt whatever SwiftUI proposes rather than its content's own size.
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tabs

    /// Plain text labels, not a segmented control. A segmented control is a
    /// filled slab of chrome inside a window whose entire point is that the
    /// numbers are the only thing in it.
    private var tabBar: some View {
        HStack(spacing: 14) {
            ForEach(Tab.allCases) { candidate in
                Button {
                    tab = candidate
                } label: {
                    Text(candidate.title)
                        .font(BoardText.header)
                        .foregroundStyle(tab == candidate ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == candidate ? [.isSelected] : [])
            }
        }
        .padding(.bottom, 18)
    }

    // MARK: - Jetzt

    private var nowTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            hero
            nowGrid
            if let milestone = wrapped.milestone {
                milestoneChip(milestone)
            }
            trendRow
        }
    }

    /// The streak at the size it deserves — it is the reason the flame is in
    /// the toolbar at all. "Heute" sits directly underneath because it is the
    /// only number in this window that can still be changed today.
    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
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
                Text(todayLine)
                    .font(BoardText.body)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        streak.todayCount == 0
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(Color.orange))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.days(streak.current)) in Folge. \(todayLine).")
    }

    /// At zero this invites instead of reporting. A bare "Heute 0 erledigt"
    /// is the one line here that could read as an accusation, and the board's
    /// rule is to reward, never to punish.
    private var todayLine: String {
        streak.todayCount == 0
            ? "Eine Aufgabe hält die Folge"
            : "Heute \(Self.tasks(streak.todayCount))"
    }

    private var nowGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 20) {
            GridRow {
                tile(value: "\(wrapped.yearCount)", label: "Dieses Jahr")
                tile(
                    value: "\(Int((wrapped.consistencyRatio * 100).rounded()))%",
                    label: "Konstanz",
                    help: "An \(wrapped.consistencyActiveDays) von \(WrappedStats.trendWindowDays) Tagen hast du mindestens eine Aufgabe erledigt.")
            }
            GridRow {
                wipTile
                forecastTile
            }
        }
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
        VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 20) {
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
                    .foregroundStyle(.tertiary)
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

    /// The one place the board's no-badges rule is relaxed — and only for a
    /// round number crossed within the last week, so it is a moment rather
    /// than a permanent fixture (see `WrappedStats.milestone`).
    private func milestoneChip(_ threshold: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "flag.fill")
                .font(BoardText.glyph)
            Text("\(threshold) erledigt dieses Jahr")
                .font(BoardText.chip)
        }
        // Same treatment as the board's badges: the capsule carries the
        // colour and the label keeps a system text colour, because orange
        // text on an orange wash measures far below the contrast floor.
        .foregroundStyle(.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(Board.badgeTintFill), in: Board.chipShape)
    }

    private func tile(
        value: String,
        unit: String? = nil,
        label: String,
        help: String? = nil,
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
        // The tooltip is the whole explanation behind a bare number, so it has
        // to reach VoiceOver too — there is nowhere else in this window to put
        // it without adding the prose the design is built to avoid.
        .accessibilityElement(children: .combine)
        .accessibilityHint(help ?? "")
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

/// `.help()` takes a non-optional string, and an empty one still attaches a
/// tooltip that flashes an empty box on hover.
private struct OptionalHelp: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.help(text)
        } else {
            content
        }
    }
}
