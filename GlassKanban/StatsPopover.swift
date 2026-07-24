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
    /// A counter that ticks on every completion (today's count). Each tick
    /// nods the flame — the smallest possible acknowledgement that the board
    /// noticed, on the element whose whole job is to notice. Zero by default
    /// so contexts that only show state (Settings previews, tests) stay
    /// still.
    var beat: Int = 0

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
            //
            // `level + beat` only ever increases within a day, so every
            // completion bounces exactly once — whether or not it also
            // changed the flame's fill.
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: reduceMotion ? 0 : level + beat)
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

    /// The one caption style a well's content ever wears, wherever a group
    /// needs to say what it is — first written for "Letzte 30 Tage" over the
    /// trend chart, now shared by every section heading in this window so
    /// none of them can drift from the others one at a time.
    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(BoardText.body)
            .foregroundStyle(.secondary)
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
                    // The law is named in the tooltip, not the row: the
                    // board's rule is that chrome explains its quiet Kanban
                    // rules on hover (see CONCEPT.md, Hover-Tipps), and
                    // "Little's Law" in a row label would be jargon standing
                    // where an answer belongs.
                    if let days = forecastDays {
                        row("Bis fertig",
                            Self.daysEstimate(days),
                            help: "Little’s Law: Aufgaben in Bearbeitung geteilt durch dein Tempo der letzten \(WrappedStats.trendWindowDays) Tage — eine Schätzung, kein Versprechen.")
                    }
                }
            }
            // Deliberately taller than the rows well above, not matched to
            // it. The two were height-matched for a while, which kept them
            // from the nearly-equal trap but capped the bars at whatever
            // three rows of text happen to measure — a chart read at arm's
            // length was the shortest thing in the window. A fixed, roomier
            // height makes the trend the tab's second focal area and keeps
            // the popover from breathing when the forecast row comes and
            // goes; clearly-different heights read as intent, only near
            // misses read as accidents.
            well { trendSection }
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
                FlameIcon(level: streak.flameLevel, size: BoardText.heroUnitSize, beat: streak.todayCount)
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

    /// The same silhouette as "Jetzt", on purpose: one hero figure on the
    /// glass, then a well of running figures, then a second well the history
    /// has to earn. Switching tabs keeps the reader's eye where it was — the
    /// big number changes meaning, not position. The year total is the hero
    /// because it is this tab's counterpart to the streak: the one figure
    /// that needs no label beyond its unit phrase, and the one the
    /// milestones celebrate.
    ///
    /// The split between the wells is the period: everything in the first
    /// well states its own — the streak by nature, the two flow figures on
    /// the same 30-day window as every pace number in this popover — while
    /// the second well ranks the whole history and shares the "Seit …"
    /// footnote. Each flow row hides behind its own sample guard, so the
    /// section can simply thin out on a young board rather than showing
    /// confident-looking dashes; the ranked well disappears whole, gated by
    /// `WrappedStats.minSampleForRankings`.
    ///
    /// No heading on either well: a caption on one and not the other read as
    /// an accident, and a caption on both was tried and read as clutter this
    /// tab did not need — the gap between the two wells already says "these
    /// are two groups", and every row still names itself.
    private var pastTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            yearHero
            well {
                rows {
                    row("Längste Folge", Self.days(streak.best))

                    // The two flow figures, side by side and on the same
                    // 30-day window — with "In Bearbeitung" on the other
                    // tab, all three variables of Little's Law are on the
                    // board: the "Bis fertig" forecast stops being an
                    // oracle and becomes arithmetic the reader can check.
                    if let weekly = weeklyThroughput {
                        row("Pro Woche",
                            Self.tasks(weekly),
                            help: "Dein Durchsatz: erledigte Aufgaben pro Woche, Durchschnitt der letzten \(WrappedStats.trendWindowDays) Tage — das Tempo in Little’s Law.")
                    }
                    if let lead = wrapped.medianLeadTimeDays {
                        row("Durchlaufzeit",
                            Self.daysEstimate(lead),
                            help: "Median von „angelegt“ bis „erledigt“ bei einmaligen Aufgaben der letzten \(WrappedStats.trendWindowDays) Tage — mit Auslastung und Tempo die dritte Größe in Little’s Law.")
                    }
                }
            }
            if hasRankings {
                VStack(alignment: .leading, spacing: 8) {
                    well {
                        rows {
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
                    // A footnote about this group, below it and indented to
                    // its content edge — the system's own group-footer
                    // position, where a note about the numbers never reads as
                    // one of them. A real month rather than a vague "letzte
                    // 13 Monate", which is the kind of range nobody can
                    // check. Scoped to the rankings rather than the tab as a
                    // whole: "Dieses Jahr" and "Längste Folge" above already
                    // state their own period.
                    if let since = historySince {
                        Text(since)
                            .font(BoardText.meta)
                            // Tertiary on glass is already near the contrast
                            // floor; under Increase Contrast it has to step
                            // up, or the one line that says which period
                            // these numbers cover is the first thing to
                            // disappear for the people who asked for more
                            // contrast.
                            .foregroundStyle(contrast == .increased
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(.tertiary))
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    /// True exactly when the ranked section has something to show.
    /// `WrappedStats` only ever produces `bestDay`, `mostActiveWeekday` and
    /// `mostUsedList` together (see `minSampleForRankings`), so checking one
    /// would already do — checking all three costs nothing and does not
    /// depend on that invariant holding forever.
    private var hasRankings: Bool {
        wrapped.bestDay != nil || wrapped.mostActiveWeekday != nil || wrapped.mostUsedList != nil
    }

    private var historySince: String? {
        guard let start = wrapped.historyStart else { return nil }
        return "Seit \(start.formatted(.dateTime.month(.wide).year()))"
    }

    /// The year total, set exactly like the streak hero next door — same
    /// row, same type, same optional note line beneath. No glyph where the
    /// flame sits: the flame is a state (empty, started, full) and earns its
    /// place by changing; a permanent trophy beside the year count would be
    /// furniture. The reward moment this hero owns is the milestone, and it
    /// appears as the note — the same slot where "Jetzt" celebrates the
    /// record.
    private var yearHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("\(wrapped.yearCount)")
                    .font(BoardText.heroUnit)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(wrapped.yearCount == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                Text(wrapped.yearCount == 1 ? "Aufgabe dieses Jahr" : "Aufgaben dieses Jahr")
                    .font(BoardText.heroUnit)
                    .foregroundStyle(.secondary)
            }
            if let milestone = wrapped.milestone {
                // Reward styling, like the record line on "Jetzt": a fact
                // about the count, at reading size, in the primary colour.
                Text("Meilenstein erreicht: \(milestone) erledigte Aufgaben")
                    .font(BoardText.body)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Self.tasks(wrapped.yearCount)) dieses Jahr erledigt."
                + (wrapped.milestone.map { " Meilenstein erreicht: \($0)." } ?? ""))
    }

    /// Completions per week over the trend window, behind the same sample
    /// guard as the forecast — the two describe the same pace and must not
    /// disagree about when the data is thin.
    private var weeklyThroughput: Int? {
        guard wrapped.throughputSampleCount >= WrappedStats.minSampleForForecast else { return nil }
        return max(1, Int((wrapped.throughputPerDay * 7).rounded()))
    }

    // MARK: - Trend

    /// The last 30 days as a shape, under a label that says so. The bars once
    /// stood alone at the foot of the window, and an unlabelled chart is the
    /// difference between minimal and unfinished — quiet is allowed,
    /// unexplained is not. Per-day figures stay in each bar's tooltip.
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Letzte 30 Tage")
            trendRow
        }
    }

    /// How much room the bars get. Tall enough that the difference between a
    /// two-task day and a five-task day is legible across the desk — the
    /// whole reason the chart exists — while the well stays clearly a
    /// supporting panel under the hero, not a second hero.
    private static let trendBarsHeight: CGFloat = 72

    private var trendRow: some View {
        // The bars still size against the height they are given rather than
        // hard-coding it twice: the constant above owns the number, the
        // geometry reads it back.
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
        .frame(height: Self.trendBarsHeight)
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

    /// A duration in days, one decimal while it is small enough for the
    /// fraction to matter — but never a decorative one: "1,0 Tage" is a
    /// machine talking, "1 Tag" is the answer. Shared by the forecast and
    /// the lead time so the window never says "3,4 Tage" in one row and
    /// "3 Tage" in the next for the same kind of figure.
    private static func daysEstimate(_ days: Double) -> String {
        let rounded = (days * 10).rounded() / 10
        let wantsFraction = days < 10 && rounded != rounded.rounded()
        let formatted = rounded.formatted(.number.precision(.fractionLength(wantsFraction ? 1 : 0)))
        return "\(formatted) \(rounded == 1 ? "Tag" : "Tage")"
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
