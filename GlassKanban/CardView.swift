import SwiftUI

/// One card, styled as a paper sticky note tinted in its Reminders list color.
///
/// Three shapes, driven by the lane's information density:
/// - full (Als Nächstes / In Bearbeitung): hero title with priority marks,
///   optional notes preview, and a meta row (due date, recurrence, list).
/// - compact (Backlog): one line with what you need to triage — priority,
///   recurrence, due date.
/// - minimal (Erledigt): the title alone.
struct CardView: View {
    let card: KanbanCard

    private var density: CardDensity { card.status.cardDensity }

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.undoManager) private var undoManager

    @State private var isHovered = false
    @State private var settleScale: CGFloat = 1
    /// Degrees of tilt while a pulled card shakes itself into place.
    @State private var settleTilt: Double = 0
    /// How much of the done title's strike line is drawn, 0...1. Rests at 1:
    /// every settled done card carries its full line. Only a card that just
    /// completed starts at 0 and draws it (see `playSettleIfFlagged`).
    @State private var strikeProgress: CGFloat = 1
    @State private var isRenaming = false
    @State private var renameText = ""
    /// The title the edit started from — the *stored* one, not the sanitized
    /// display form. Kept so the commit can tell a real change from a no-op
    /// (see `TicketRename`).
    @State private var renameOriginal = ""
    @FocusState private var isRenameFieldFocused: Bool

    /// Lanes this card can be sent to — everything except where it already is.
    private var moveTargets: [KanbanStatus] {
        KanbanStatus.allCases.filter { $0 != card.status }
    }

    var body: some View {
        Group {
            switch density {
            case .full: fullBody
            case .compact: compactBody
            case .minimal: minimalBody
            }
        }
        .background { surface }
        .overlay(alignment: .leading) { listStripe }
        .overlay { contour }
        .overlay { topHighlight }
        .shadow(color: contactShadow.color, radius: contactShadow.radius, y: contactShadow.y)
        // Finished work sits flatter: it keeps the contact shadow but loses
        // the ambient one, so it recedes without losing its paper edge.
        .shadow(
            color: card.status == .done ? .clear : Board.cardShadowAmbient.color,
            radius: Board.cardShadowAmbient.radius,
            y: Board.cardShadowAmbient.y)
        .scaleEffect(settleScale)
        .rotationEffect(.degrees(settleTilt))
        .offset(y: isHovered && !reduceMotion ? -1 : 0)
        // The card being dragged stays visible in its source lane, which reads
        // as "it is still here" while the cursor carries a copy of it. Ghosting
        // it says the original has been lifted.
        .opacity(store.draggingCardID == card.id ? 0.4 : 1)
        .animation(reduceMotion ? nil : Board.hoverAnimation, value: store.draggingCardID)
        .contentShape(Board.cardShape)
        // Deliberately NOT `.focusable()`. Cards must not take keyboard focus
        // — settled user decision, recorded in BACKLOG.md ("Explizit
        // abgelehnt"): cards are dragged around all day, and a board that
        // keeps pointing at one of them emphasises exactly the thing that
        // needs no emphasis. Reintroduced once by a merge, removed again —
        // check BACKLOG.md before touching this. VoiceOver is unaffected: it
        // carries its own cursor and the accessibility actions below.
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : Board.hoverAnimation) { isHovered = hovering }
        }
        // One click, one meaning. Double-click used to start an inline
        // rename, and the cost of that was paid on every single click:
        // SwiftUI has to hold a lone tap back until a second one can be ruled
        // out, so opening a card — the thing you actually do — always lagged
        // behind the click by the double-click interval.
        //
        // Renaming loses nothing. The card that opens on a single click has
        // the title as its first editable field, and "Umbenennen" is still in
        // the context menu and the accessibility actions for anyone who wants
        // the inline route.
        .onTapGesture {
            guard !isRenaming else { return }
            beginEdit()
        }
        .contextMenu {
            Button("Edit") { beginEdit() }
            Button("Open in Reminders") { openInReminders() }
            Divider()
            // Drag & drop is the accelerator; this is the route that works
            // without a pointer. Both go through store.move, so the WIP
            // question fires either way.
            Menu("Move to") {
                ForEach(moveTargets) { target in
                    Button(target.displayName) {
                        store.move(cardID: card.id, to: target, undoManager: undoManager)
                    }
                }
            }
            Divider()
            Button("Rename") { beginRename() }
            // Asks first — see `RemindersStore.requestDelete`. ⌘Z brings
            // the ticket back, but not its subtasks or attachments, and that
            // gap has to be named before the deletion, not discovered after.
            Button("Delete", role: .destructive) {
                store.requestDelete(cardID: card.id)
            }
        }
        // No tooltip anywhere on a card — body, dwell label or repeat glyph.
        // Settled user decision, recorded in BACKLOG.md ("Explizit
        // abgelehnt"): text springing up on every touched ticket is standing
        // noise, and everything it said is one click away in the editor.
        // Tooltips belong to the chrome (lane header, "+" button), where they
        // explain rules. Reintroduced once by a merge, removed again — check
        // BACKLOG.md before touching this.
        // While renaming, the card stops being one combined button and lets
        // the text field speak for itself. Combined, VoiceOver announced the
        // *old* title and offered "Bearbeiten" — the field the cursor was
        // actually sitting in, and everything typed into it, did not exist as
        // far as the screen reader was concerned.
        .accessibilityElement(children: isRenaming ? .contain : .combine)
        .accessibilityAddTraits(isRenaming ? [] : .isButton)
        .accessibilityLabel(isRenaming ? "" : accessibilityLabel)
        // Still spoken, though no longer drawn: VoiceOver has no other route
        // to a card's notes.
        .accessibilityHint(isRenaming ? "" : helpText)
        .accessibilityActions {
            if !isRenaming {
                Button("Edit") { beginEdit() }
                Button("Open in Reminders") { openInReminders() }
            }
        }
        .accessibilityActions {
            if !isRenaming {
                ForEach(moveTargets) { target in
                    Button("Move to \(target.displayName)") {
                        store.move(cardID: card.id, to: target, undoManager: undoManager)
                    }
                }
                Button("Rename") { beginRename() }
                Button("Delete") { store.requestDelete(cardID: card.id) }
            }
        }
        // Losing focus commits, same as clicking away from a Finder rename —
        // Escape (`onExitCommand` on the field itself) is the only way out
        // that discards instead.
        .onChange(of: isRenameFieldFocused) { _, focused in
            if !focused { commitRename() }
        }
        // A click on bare lane, or another edit starting anywhere on the
        // board, also ends this rename. Focus alone cannot carry that: the
        // click lands in a view that has no way to reach this one (see
        // `BoardEdit`).
        .onChange(of: store.activeEdit) { _, edit in
            if isRenaming, edit != .renaming(cardID: card.id) { commitRename() }
        }
        .onAppear {
            // The completed card appears fresh in Erledigt with the flag
            // already set, so trigger the settle here rather than on change.
            playSettleIfFlagged()
        }
    }

    // MARK: - Layouts

    /// Ticket anatomy in three zones divided by hairlines, like a ruled
    /// index card. The header carries the card's PROCESS state (title, how
    /// long it has been sitting here), the footer carries the TASK's facts
    /// (due date, recurrence, source list) — the two time signals stay in
    /// opposite corners so they can never be confused.
    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                titleOrField(font: BoardText.title)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                agingLabel
            }
            .padding(EdgeInsets(top: 11, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))

            zoneDivider

            notesZone

            zoneDivider

            HStack(spacing: 6) {
                if let badge = fullBadge {
                    badgeView(badge)
                }
                if card.isRecurring {
                    repeatIcon
                }
                Spacer(minLength: 8)
                // Secondary — a supporting fact, like everything else in
                // this row. It was briefly primary, to set it apart from the
                // pale "Keine Notizen" one zone above; that separated the
                // two but put the loudest text on the card's least important
                // fact (the source list, at 11pt, as dark as the name of the
                // ticket) and left four ranks of grey stacked in 118pt of
                // paper. The board's three text ranks each mean one thing —
                // see `BoardText` — and the separation comes from the
                // placeholder receding, not from the metadata shouting.
                // Tertiary is ruled out here for the opposite reason: at
                // this size it washes out on paper, and the list name is
                // something you actually read.
                Text(card.listName)
                    .font(BoardText.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(EdgeInsets(top: 8, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
        }
        // Fixed, not a minimum: every card in a working lane is the same
        // height, whether it carries three lines of note or none. The notes
        // zone above takes up the slack (`maxHeight: .infinity`), so the
        // footer stays pinned to the bottom edge either way.
        .frame(
            maxWidth: .infinity,
            minHeight: Board.fullCardHeight,
            maxHeight: Board.fullCardHeight,
            alignment: .topLeading)
    }

    /// The ticket's middle zone. It always stands, because the zone is part
    /// of the card's anatomy — but a card without a note used to leave it
    /// blank, and an empty strip framed by two hairlines reads as something
    /// that failed to load rather than as "nothing written here". Saying so
    /// costs one quiet line and answers the question the gap posed.
    ///
    /// Primary, like the note in the opened card: it is the same text on
    /// both surfaces, and a card that changed colour on the way into the
    /// editor made one body of writing look like two. Rank inside the card
    /// is carried by size and weight instead — 15pt semibold title over
    /// 12pt regular note — which is what separates them in the editor too.
    ///
    /// The placeholder is the one thing in this zone that is *not* what the
    /// ticket says — it is the app describing an absence — so it takes the
    /// second tier, exactly as the rule reads (see `BoardText`). That is not
    /// a third shade: the board still has two, and this is the one the
    /// footer facts already use. It was briefly primary, and on a board
    /// where most tickets carry no note, four cards announcing "Keine
    /// Notizen" in full black said nothing four times as loudly as the
    /// tickets that had something to say. Same font, same insets and the
    /// same expanding frame as a real excerpt, so a card with a note and a
    /// card without one keep identical geometry.
    @ViewBuilder
    private var notesZone: some View {
        Group {
            if card.notesExcerpt.isEmpty {
                Text("No Notes")
                    .foregroundStyle(.secondary)
            } else {
                Text(card.notesExcerpt)
                    .foregroundStyle(.primary)
            }
        }
        .font(BoardText.body)
        .lineLimit(3)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(EdgeInsets(top: 8, leading: Board.cardInsetLeading, bottom: 8, trailing: Board.cardInsetTrailing))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Hairline between ticket zones, inset to the text margin so it reads
    /// as a rule on the card, not a cut through it.
    private var zoneDivider: some View {
        Rectangle()
            .fill(Board.cardBorder(contrast))
            .frame(height: 1)
            .padding(.leading, Board.cardInsetLeading)
            .padding(.trailing, Board.cardInsetTrailing)
    }

    /// Dwell time, top right in the header: process state, deliberately far
    /// from the due date in the footer.
    @ViewBuilder
    private var agingLabel: some View {
        if let days = card.daysInColumn(), days >= Board.agingThresholdDays {
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(BoardText.glyph)
                Text("\(days) days")
                    .font(BoardText.meta)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
        }
    }

    /// Backlog: everything needed to decide what to pull next.
    ///
    /// Badge before glyph, the same order the full card's footer uses. The
    /// two were mirrored — badge-then-glyph there, glyph-then-badge here —
    /// so a card swapped its two meta marks around as it moved from Backlog
    /// into a working lane, which reads as the card being rearranged rather
    /// than relocated.
    private var compactBody: some View {
        HStack(spacing: 8) {
            titleOrField(font: BoardText.titleCompact)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge = compactBadge {
                badgeView(badge)
            }
            if card.isRecurring {
                repeatIcon
            }
        }
        .padding(EdgeInsets(top: 9, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
        // One height for every row in a storage lane. Intrinsic, a row with
        // a date badge came out a point taller than one without, so Backlog
        // and Erledigt never quite lined up with each other.
        .frame(
            maxWidth: .infinity,
            minHeight: Board.compactCardHeight,
            maxHeight: Board.compactCardHeight,
            alignment: .leading)
    }

    /// Erledigt: the work is done — the name is the only thing left to say.
    private var minimalBody: some View {
        titleOrField(font: BoardText.titleCompact)
            .lineLimit(1)
            // The overlay sits on the text itself, before the padding and
            // the width expansion, so the line spans exactly the words —
            // a strike across the whole row would cross empty paper.
            .overlay(alignment: .leading) { strikeLine }
            .padding(EdgeInsets(top: 9, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
            // Same row height as Backlog — see `compactBody`.
            .frame(
            maxWidth: .infinity,
            minHeight: Board.compactCardHeight,
            maxHeight: Board.compactCardHeight,
            alignment: .leading)
    }

    /// The done title's strike, drawn by the board instead of by
    /// `Text.strikethrough` — because the completion reward *is* this line
    /// being drawn. On a settled card it simply sits there at full width,
    /// indistinguishable from the text attribute it replaces; on a card that
    /// just completed it starts at zero and sweeps left to right (see
    /// `playSettleIfFlagged`), the pen crossing the task off. Scaled rather
    /// than measured: `scaleEffect(x:anchor:)` animates the sweep without a
    /// GeometryReader, and a 1pt line has no content to distort.
    @ViewBuilder
    private var strikeLine: some View {
        if card.status == .done, !isRenaming {
            Rectangle()
                .fill(.secondary)
                .frame(height: 1)
                .scaleEffect(x: strikeProgress, anchor: .leading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Title with Reminders-style priority marks ("!!") in front. The marks
    /// are neutral on purpose: their count already encodes priority, and
    /// colouring them would spend orange — which on this board means "due
    /// today" — on a second, unrelated meaning.
    private var titleText: Text {
        // No `.strikethrough` here: the done title's line is `strikeLine`,
        // drawn by the board so that completing can animate it.
        //
        // Full-strength colour even when done: the strike line already
        // marks completion, so dimming the text on top of it was a second,
        // redundant signal for the same fact.
        let base = Text(displayTitle)
            .foregroundStyle(.primary)
        guard let marks = card.priorityMarks, card.status != .done else { return base }
        // Interpolation rather than `+`: concatenating Text is deprecated as
        // of macOS 26 and each run keeps its own styling this way.
        let marksText = Text(marks).foregroundStyle(.secondary).bold()
        return Text("\(marksText) \(base)")
    }

    /// Swaps in for `titleText` while renaming — a plain field over the same
    /// spot the title already sits in, not a separate window. Priority marks
    /// drop out during the edit: they describe `priority`, not `title`, and
    /// were never something to type.
    @ViewBuilder
    private func titleOrField(font: Font) -> some View {
        if isRenaming {
            TextField("Title", text: $renameText)
                .font(font)
                .textFieldStyle(.plain)
                .accessibilityLabel("Title")
                .focused($isRenameFieldFocused)
                .onAppear { isRenameFieldFocused = true }
                .onSubmit { commitRename() }
                .onExitCommand {
                    isRenaming = false
                    if store.activeEdit == .renaming(cardID: card.id) {
                        store.activeEdit = nil
                    }
                }
        } else {
            titleText.font(font)
        }
    }

    private var repeatIcon: some View {
        Image(systemName: "repeat")
            .font(BoardText.glyph)
            .foregroundStyle(.secondary)
    }

    /// Compact rows have no room for the notes preview, so the tooltip
    /// carries it — information without pixels.
    ///
    /// One fact per line, because the tooltip sets the first line as the
    /// subject and the rest as its qualifiers. Joined with "·" they were one
    /// run-on that wrapped mid-phrase and threw the note, the list and the
    /// gesture hint into a single weight.
    ///
    /// The list name is not repeated here: `accessibilityLabel` already says
    /// it, and VoiceOver reads label and hint back to back, so every card was
    /// announcing its list twice.
    private var helpText: String {
        var lines: [String] = []
        if !noteForVoiceOver.isEmpty {
            lines.append(noteForVoiceOver)
        }
        lines.append(String(localized: "Click to edit"))
        return lines.joined(separator: "\n")
    }

    /// The note as spoken. The hint used to carry it for single-line rows
    /// only — on the very cards where the excerpt is *drawn*, three lines of
    /// it, VoiceOver said nothing about it at all: the explicit
    /// `accessibilityLabel` replaces what `children: .combine` would have
    /// picked up, and it never included the note.
    private var noteForVoiceOver: String {
        density.isSingleLine ? card.notesPreview : card.notesExcerpt
    }

    private var displayTitle: String {
        card.title.isEmpty ? String(localized: "Untitled") : card.title
    }

    /// Built explicitly rather than left to `children: .combine`. Combining
    /// reads the priority marks as punctuation ("exclamation exclamation"),
    /// never mentions that a card is done — strikethrough carries no
    /// semantics — and reduces the list colour, which is the only channel
    /// carrying the source list on compact rows, to nothing at all.
    /// The lane itself is announced by the column's accessibility container.
    private var accessibilityLabel: String {
        var parts: [String] = []
        if card.status == .done {
            parts.append(String(localized: "Done"))
        }
        if let priority = priorityDescription {
            parts.append(priority)
        }
        parts.append(displayTitle)
        if let due = card.dueDate {
            parts.append(String(localized: "Due \(badge(for: due).label)"))
        }
        if card.isRecurring {
            parts.append(String(localized: "Repeats"))
        }
        parts.append(String(localized: "List \(card.listName)"))
        if let days = card.daysInColumn(), days >= Board.agingThresholdDays {
            parts.append(String(localized: "In this column for \(days) days"))
        }
        return parts.joined(separator: ", ")
    }

    private var priorityDescription: String? {
        switch card.priority {
        case 1...4: String(localized: "High priority")
        case 5: String(localized: "Medium priority")
        case 6...9: String(localized: "Low priority")
        default: nil
        }
    }

    // MARK: - Surface (sticky note)

    private var surface: some View {
        Board.cardShape.fill(cardFill)
    }

    /// Slim list-color marker along the leading edge — the ticket's color
    /// code, inset like a physical tab so it reads as part of the card.
    private var listStripe: some View {
        Capsule()
            .fill(stripeColor.opacity(card.status == .done ? 0.45 : 0.9))
            .frame(width: Board.cardStripeWidth)
            .padding(.vertical, density.isSingleLine ? 7 : 9)
            .padding(.leading, 5)
            .allowsHitTesting(false)
    }

    /// Reminders list colours are chosen by the user and some are very light —
    /// a pale yellow stripe vanishes on white paper, and the stripe is the only
    /// channel carrying the source list on compact rows. Mixing in a little
    /// label colour keeps every list distinguishable without shifting its hue:
    /// `labelColor` is near-black in light mode and near-white in dark, so the
    /// stripe moves away from the card's own fill in both.
    private var stripeColor: Color {
        card.listColor.mix(with: Color(nsColor: .labelColor), by: 0.18)
    }

    /// Opaque "paper" so cards read as physical objects on the recessed
    /// lanes — independent of whatever wallpaper shines through the window.
    ///
    /// One fill in every mode: this is a solid colour, never a material, so
    /// "Transparenz reduzieren" has nothing to switch off. It used to swap in
    /// `controlBackgroundColor` there, which in dark mode is darker than the
    /// lane and dropped the card *below* the surface it lies on — and which
    /// also lost the dimmer paper a finished ticket carries, because the
    /// fallback had nowhere to put `isDone`. See `Board.opaqueGlassFill`.
    private var cardFill: Color {
        Board.cardFill(colorScheme, isDone: card.status == .done)
    }

    private var contour: some View {
        Board.cardShape.strokeBorder(Board.cardBorder(contrast))
    }

    /// Light catching the top edge. Only in dark mode: on white paper a white
    /// highlight is invisible, so in light mode this was pure render cost.
    @ViewBuilder
    private var topHighlight: some View {
        if colorScheme == .dark {
            Board.cardShape
                .strokeBorder(
                    LinearGradient(colors: [Board.cardTopHighlight, .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }


    private var contactShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        isHovered ? Board.cardShadowHover : Board.cardShadowResting
    }

    // MARK: - Badges

    private struct BadgeInfo {
        let label: String
        let tint: Color?
        /// Solid fill instead of a tint. Reserved for overdue — the one
        /// state that has already failed and should catch the eye from
        /// across the room. Everything else stays quiet.
        var isEmphasized = false
    }

    /// Full cards (never Done) show the due date when there is one; the
    /// uninformative "Kein Datum" is deliberately omitted.
    private var fullBadge: BadgeInfo? {
        card.dueDate.map(badge(for:))
    }

    /// Compact cards always carry their date when they have one — essential
    /// in the backlog, where recurring reminders resurface by date. Urgency
    /// still tints, everything else stays a quiet grey.
    private var compactBadge: BadgeInfo? {
        guard card.status != .done, let due = card.dueDate else { return nil }
        return badge(for: due)
    }

    private func badge(for due: Date) -> BadgeInfo {
        let calendar = Calendar.current
        if calendar.isDateInToday(due) {
            return BadgeInfo(label: String(localized: "Today"), tint: .orange)
        }
        if due < calendar.startOfDay(for: .now) {
            return BadgeInfo(label: String(localized: "Overdue"), tint: .red, isEmphasized: true)
        }
        if calendar.isDateInTomorrow(due) {
            return BadgeInfo(label: String(localized: "Tomorrow"), tint: nil)
        }
        return BadgeInfo(label: due.formatted(.dateTime.day().month()), tint: nil)
    }

    /// Three weights, so urgency reads at a glance: solid (overdue), tinted
    /// (today), quiet grey (everything else).
    private func badgeView(_ info: BadgeInfo) -> some View {
        Text(info.label)
            .font(BoardText.chip)
            .monospacedDigit()
            .foregroundStyle(badgeForeground(info))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(badgeBackground(info), in: Board.chipShape)
    }

    /// The tint colours the capsule, never the label. System orange as 11pt
    /// text on white paper measures ~2.2:1, well under the 4.5:1 minimum —
    /// and Apple never uses it that way either: in Reminders and Calendar
    /// orange is always a plane or a glyph.
    private func badgeForeground(_ info: BadgeInfo) -> AnyShapeStyle {
        if info.isEmphasized { return AnyShapeStyle(.white) }
        return info.tint == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    private func badgeBackground(_ info: BadgeInfo) -> AnyShapeStyle {
        guard let tint = info.tint else { return AnyShapeStyle(.quaternary.opacity(Board.chipFill)) }
        if info.isEmphasized { return AnyShapeStyle(Board.overdueFill) }
        return AnyShapeStyle(tint.opacity(Board.badgeTintFill))
    }

    // MARK: - Motivation animations

    /// Completion is a pen stroke, and nothing else: the card lies down,
    /// a breath passes, then the strike line draws across the title (see
    /// `strikeLine`). The beat between landing and stroke is the point —
    /// it is what a hand does at a real board (place the card, *then*
    /// cross it off), and it lets each phase read singly where drawing
    /// during the arrival made neither legible. The card holds perfectly
    /// still while the line moves: one event, one gesture. Two earlier
    /// companions were removed for that rule — a green flash (a colour
    /// wash over paper, which these cards never wear) and the squish that
    /// had carried it (once the pen is the reward, a press-and-spring
    /// before it was just noise in front of the gesture). `easeInOut`,
    /// not `easeOut`: a pen sets down deliberately, sweeps, and lifts —
    /// full speed from a standstill is a swipe.
    ///
    /// A pull into "In Bearbeitung" *shakes* instead — the card pops a
    /// touch oversized and a low-damped spring swings a tilt back through
    /// zero a couple of times, the card shimmying itself into the slot with
    /// somewhere to be. Eagerness, not arrival. Two coupled channels: the
    /// rotation carries legibility — it is the one motion this board never
    /// uses anywhere else (cards scale, fade and translate, but nothing ever
    /// *tilts*), so it cannot be absorbed by the lane's other motion — and a
    /// quick scale pop *upward* is the punch that makes it read across the
    /// desk. Loud on purpose where completion is calm: finishing is the
    /// quiet pen stroke, starting bursts up and out, so the two rewards
    /// never feel like the same gesture. A big first swing that settles in
    /// ~0.4 s: loud enough to read, gone before it can slow the hand. No
    /// stroke here — the finishing mark stays reserved for finishing.
    ///
    /// Both settles share one clock and one shape. The clock: they hold for
    /// `Board.settleDelay` first, because `onAppear` fires when the card
    /// *starts* fading into the lane, not when it lies there — a settle
    /// launched immediately played mid-flight, a reward for an arrival that
    /// had not visibly happened yet. (Haptics and the chime deliberately do
    /// not wait: they answer the hand, which acted at the drop — see
    /// `Board.settleDelay`.) The shape: a short ease *into* the displaced
    /// state, then springs home — animating into the start state is also
    /// what sidesteps SwiftUI coalescing a same-tick set-then-animate into
    /// nothing, which silently killed an earlier version of the shake.
    private func playSettleIfFlagged() {
        guard !reduceMotion else { return }
        let completed = store.recentlyCompletedIDs.contains(card.id)
        guard completed || store.recentlyPulledIDs.contains(card.id) else { return }
        if completed {
            // Synchronously, before the first frame: the just-completed
            // title appears bare, so the stroke below has a line to draw.
            // Under Reduce Motion this is never reached and the line simply
            // stands complete, like on every settled card.
            strikeProgress = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: Board.settleDelay)
            if completed {
                // The breath between landing and pen — anticipation is half
                // the reward, and a stroke that starts while the card is
                // still arriving reads as neither arriving nor striking.
                try? await Task.sleep(for: .milliseconds(300))
                // Unhurried on purpose: the sweep *is* the reward, and a
                // stroke over in a blink is a checkbox, not a pen.
                withAnimation(.easeInOut(duration: 0.45)) { strikeProgress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.07)) {
                    settleTilt = 4
                    settleScale = 1.08
                }
                try? await Task.sleep(for: .milliseconds(70))
                // Damped below critical: the tilt crosses zero a couple of
                // times — that crossing *is* the shake — and is home in
                // ~0.4 s. The pop returns with a single gentle overshoot.
                withAnimation(.spring(response: 0.34, dampingFraction: 0.3)) {
                    settleTilt = 0
                }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) {
                    settleScale = 1
                }
            }
        }
    }

    // MARK: - Actions

    /// A click opens the in-app editor now — title, notes, due date and
    /// priority all live in GlassKanban itself.
    private func beginEdit() {
        // The board presents the editor, not the card — see
        // `RemindersStore.editingCardID` for why its position must not depend
        // on where the card that opened it happens to sit.
        // Animated at the source, not by a modifier further up: a
        // `.transition` only plays if the state change that triggers it is
        // itself animated, and the board's blur lives on a different view
        // than the card's arrival. Wrapping the mutation is what makes the
        // two one gesture rather than two coincidences.
        withAnimation(reduceMotion ? nil : Board.cardOpenAnimation) {
            store.editingCardID = card.id
        }
    }

    /// Escape hatch to the native app, for anything the edit sheet
    /// deliberately leaves out. The sheet offers the same route, so both go
    /// through one implementation.
    private func openInReminders() {
        store.openInReminders(cardID: card.id)
    }

    /// Starts from the title as *stored in Reminders*, not the one on the
    /// card. The card shows the sanitized form with URLs stripped, so opening
    /// the field on `card.title` and letting it commit — which a click
    /// elsewhere does on its own — would write the stripped text back and
    /// delete the link for good. ("Ohne Titel" is likewise a display
    /// placeholder, never something to hand the user to type over.)
    private func beginRename() {
        renameOriginal = store.storedTitle(forCardID: card.id) ?? card.title
        renameText = renameOriginal
        isRenaming = true
        store.activeEdit = .renaming(cardID: card.id)
    }

    /// Guarded so the three paths that can end an edit — Return, focus loss,
    /// a click elsewhere on the board — can't all fire for the same one.
    /// Writes only a real change: an untouched or emptied field discards
    /// instead (see `TicketRename`).
    private func commitRename() {
        guard isRenaming else { return }
        isRenaming = false
        if store.activeEdit == .renaming(cardID: card.id) {
            store.activeEdit = nil
        }
        guard case let .save(title) = TicketRename.outcome(
            original: renameOriginal, edited: renameText) else { return }
        store.renameTicket(cardID: card.id, title: title, undoManager: undoManager)
    }
}
