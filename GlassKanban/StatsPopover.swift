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
    /// Height of the values well, so the trend well beneath can match it.
    @State private var rowsWellHeight: CGFloat?
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
        // Roomy enough that no row has to negotiate: the longest label and
        // the longest value a real Reminders list can produce still sit on
        // one line at full size, with air left between them. 330 fitted them
        // exactly, which is not the same as comfortably.
        .frame(width: 400, alignment: .leading)
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
        // Sized to its labels, not to the window. Stretched across the full
        // width it became the largest shape here and wore the system accent,
        // so the eye landed on a blue bar before it found the flame this
        // window is about. A switcher is navigation; it does not get to
        // out-rank the thing it navigates.
        .fixedSize()
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
            .background(Board.wellShape.fill(Board.wellFill(scheme)))
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

                    // "Dieses Jahr" used to close this list and does not
                    // belong here: every other figure in it is about the state
                    // of things right now — what is done today, what is open,
                    // how long that will take. A year's total is a look back,
                    // and the tab next door is called exactly that.
                    if let days = forecastDays {
                        row("Bis fertig",
                            "\(days.formatted(.number.precision(.fractionLength(days < 10 ? 1 : 0)))) \(days == 1 ? "Tag" : "Tage")",
                            help: "Schätzung: Aufgaben in Bearbeitung geteilt durch dein Tempo der letzten \(WrappedStats.trendWindowDays) Tage.")
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsWellHeight = $0 }
            // Matched to the well above rather than left at its natural size.
            // Two stacked groups of nearly-but-not-quite the same height read
            // as a layout that missed, not as a pair — and the difference was
            // only ever the accident of how many rows the list happened to
            // hold. Measured rather than guessed, because that row count
            // varies: the forecast drops out whenever nothing is in progress.
            well { trendSection }
                .frame(height: rowsWellHeight)
        }
    }

    /// The streak, alone on the glass above the wells. It is the only figure
    /// here set large, and the only one that needs no label to be understood
    /// at a glance.
    private var hero: some View {
        // One left edge for the whole block. The flame used to sit *beside*
        // the stacked text, which put the glyph on one margin and all three
        // lines of text on another 46pt to its right — two competing left
        // edges in a four-line block, and the thing that made this corner
        // look unresolved. Flame and number share the headline row;
        // everything below starts where the flame starts.
        // The count reads as one phrase — "2 Tage in Folge" — and the message
        // stands apart from it.
        //
        // The unit used to sit on its own line under the number, directly
        // above the message, both at body size and two points apart. That made
        // two candidate captions for one figure, and the message read as a
        // condition attached to the count rather than as a separate thought.
        // Moving the unit up beside the number leaves exactly one line below
        // it, so there is nothing left to confuse it with — and the gap does
        // the rest.
        VStack(alignment: .leading, spacing: 14) {
            // Centred, not baseline-aligned. A symbol has no true text
            // baseline of its own — SwiftUI approximates one from the glyph's
            // bounds at *its own* font size, and that approximation only
            // lines up cleanly against text set at a similar size. Here it
            // sat beside a 40pt numeral and a 20pt phrase at once, and it
            // could not agree with both: the flame read as floating a touch
            // above the line it was meant to share. Centring the row treats
            // flame, number and words as one balanced cluster instead of
            // three baselines negotiating — the way Weather centres a
            // condition line beside its temperature rather than matching
            // either one's baseline.
            // One size, one weight, for all three — flame, count and words.
            // The row used to run a 40pt bold rounded numeral against a 20pt
            // regular phrase, a hero figure with a caption trailing it; set
            // uniform, nothing here outranks anything else, and the flame's
            // own colour is the one thing left to carry emphasis.
            HStack(alignment: .center, spacing: 8) {
                FlameIcon(level: streak.flameLevel, size: BoardText.heroUnitSize)
                Text("\(streak.current)")
                    .font(BoardText.heroUnit)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(streak.current == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                Text(streak.current == 1 ? "Tag in Folge" : "Tage in Folge")
                    .font(BoardText.heroUnit)
                    .foregroundStyle(.secondary)
            }
            if let note = heroNote {
                // Ranked by weight, size and system text colour — never by an
                // orange label, see the badge rule above.
                //
                // The two states are different kinds of line and are set as
                // such. A reward states a fact about the count and stays at
                // reading size in the primary colour. A prompt is a caption
                // on it and drops to `meta`, which is also what stops it
                // reading as a second figure standing level with the first.
                Text(note.text)
                    .font(note.isReward ? BoardText.body : BoardText.meta)
                    .fontWeight(note.isReward ? .semibold : .regular)
                    .foregroundStyle(note.isReward ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
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
                    // First, because it is the total the rest of this list
                    // details. It carries its own period in its label, which
                    // is why the footnote below can go on describing the
                    // others without contradicting it.
                    row("Dieses Jahr",
                        "\(wrapped.yearCount)",
                        mark: wrapped.milestone != nil ? "flag.fill" : nil,
                        help: wrapped.milestone.map {
                            "Meilenstein erreicht: \($0) erledigte Aufgaben in diesem Jahr."
                        })

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
        // Takes whatever the matched well height leaves after the label, so
        // the chart grows into the space rather than sitting at the bottom
        // of a half-empty box.
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var trendRow: some View {
        // The bars are sized against the height they are actually given, not
        // against a constant. Once the well matches the one above it, that
        // height depends on how many rows the list holds — a fixed 24pt row
        // would leave the difference as dead space.
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(wrapped.last30) { day in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(day.didComplete ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(.quaternary))
                        .frame(height: barHeight(day, in: proxy.size.height))
                        .help(trendHelp(day))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(minHeight: 24)
        // Otherwise this is 30 VoiceOver stops that each say nothing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Letzte \(WrappedStats.trendWindowDays) Tage: an \(wrapped.consistencyActiveDays) Tagen etwas erledigt.")
    }

    /// A day with nothing done keeps a hairline so the row still reads as a
    /// row of days; everything else scales between a visible floor and the
    /// full height available.
    private func barHeight(_ day: DayCompletion, in available: CGFloat) -> CGFloat {
        guard available > 0 else { return 0 }
        guard day.count > 0 else { return 3 }
        let peak = max(1, wrapped.last30.map(\.count).max() ?? 1)
        let floor = min(7, available)
        return floor + CGFloat(day.count) / CGFloat(peak) * (available - floor)
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
