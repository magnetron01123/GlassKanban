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

    @State private var isHovered = false
    @State private var settleScale: CGFloat = 1
    @State private var settleFlash = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var isFocused: Bool
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
        .overlay { flashOverlay }
        .shadow(color: contactShadow.color, radius: contactShadow.radius, y: contactShadow.y)
        // Finished work sits flatter: it keeps the contact shadow but loses
        // the ambient one, so it recedes without losing its paper edge.
        .shadow(
            color: card.status == .done ? .clear : Board.cardShadowAmbient.color,
            radius: Board.cardShadowAmbient.radius,
            y: Board.cardShadowAmbient.y)
        .scaleEffect(settleScale)
        .offset(y: isHovered && !reduceMotion ? -1 : 0)
        // The card being dragged stays visible in its source lane, which reads
        // as "it is still here" while the cursor carries a copy of it. Ghosting
        // it says the original has been lifted.
        .opacity(store.draggingCardID == card.id ? 0.4 : 1)
        .animation(reduceMotion ? nil : Board.hoverAnimation, value: store.draggingCardID)
        .contentShape(Board.cardShape)
        .focusable()
        // The default system ring is what we just removed our own overlay
        // for — .focusable() draws its own underneath regardless. Keyboard
        // focus (Tab, then Return to open) still works without it.
        .focusEffectDisabled()
        .focused($isFocused)
        // Return matches what a single click does, so the keyboard path is
        // not a lesser version of the pointer one. Renaming already owns
        // Return — the TextField's own `onSubmit` — so this steps aside.
        .onKeyPress(.return) {
            guard !isRenaming else { return .ignored }
            beginEdit()
            return .handled
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : Board.hoverAnimation) { isHovered = hovering }
        }
        // One click for the common action (edit), two for the rare one
        // (rename) — SwiftUI holds the single-tap just long enough to rule
        // out a second one, same as Finder's icon-name click-to-rename.
        .onTapGesture(count: 1) {
            guard !isRenaming else { return }
            beginEdit()
        }
        .onTapGesture(count: 2) {
            guard !isRenaming else { return }
            beginRename()
        }
        .contextMenu {
            Button("Bearbeiten") { beginEdit() }
            Button("In Erinnerungen öffnen") { openInReminders() }
            Divider()
            // Drag & drop is the accelerator; this is the route that works
            // without a pointer. Both go through store.move, so the WIP
            // question fires either way.
            Menu("Verschieben nach") {
                ForEach(moveTargets) { target in
                    Button(target.displayName) { store.move(cardID: card.id, to: target) }
                }
            }
            Divider()
            Button("Umbenennen") { beginRename() }
            Button("Löschen", role: .destructive) { store.deleteTicket(cardID: card.id) }
        }
        .boardTooltip(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
        // `.help` used to carry this to VoiceOver as well. The notes preview
        // is only on the tooltip for compact rows, so without it here that
        // text would exist for sighted users alone.
        .accessibilityHint(helpText)
        .accessibilityAction(named: "Bearbeiten") { beginEdit() }
        .accessibilityAction(named: "In Erinnerungen öffnen") { openInReminders() }
        .accessibilityActions {
            ForEach(moveTargets) { target in
                Button("Verschieben nach \(target.displayName)") {
                    store.move(cardID: card.id, to: target)
                }
            }
            Button("Umbenennen") { beginRename() }
            Button("Löschen") { store.deleteTicket(cardID: card.id) }
        }
        // Losing focus commits, same as clicking away from a Finder rename —
        // Escape (`onExitCommand` on the field itself) is the only way out
        // that discards instead.
        .onChange(of: isRenameFieldFocused) { _, focused in
            if !focused { commitRename() }
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

            Group {
                if card.notesExcerpt.isEmpty {
                    Spacer(minLength: 8)
                } else {
                    Text(card.notesExcerpt)
                        .font(BoardText.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(EdgeInsets(top: 8, leading: Board.cardInsetLeading, bottom: 8, trailing: Board.cardInsetTrailing))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            zoneDivider

            HStack(spacing: 6) {
                if let badge = fullBadge {
                    badgeView(badge)
                }
                if card.isRecurring {
                    repeatIcon
                }
                Spacer(minLength: 8)
                // Secondary, not tertiary: on opaque paper the tertiary
                // style washes out to the point of being unreadable.
                Text(card.listName)
                    .font(BoardText.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(EdgeInsets(top: 8, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
        }
        .frame(
            maxWidth: .infinity,
            minHeight: Board.fullCardMinHeight,
            alignment: .topLeading)
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
                Text("\(days) Tage")
                    .font(BoardText.meta)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            // The card as a whole already announces its dwell time in
            // `accessibilityLabel`, and the row is combined into one element —
            // so this is the tooltip only, with no accessibility to restore.
            .boardTooltip("Seit \(days) Tagen in dieser Spalte")
        }
    }

    /// Backlog: everything needed to decide what to pull next.
    private var compactBody: some View {
        HStack(spacing: 8) {
            titleOrField(font: BoardText.titleCompact)
                .lineLimit(1)
            Spacer(minLength: 0)
            if card.isRecurring {
                repeatIcon
            }
            if let badge = compactBadge {
                badgeView(badge)
            }
        }
        .padding(EdgeInsets(top: 9, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Erledigt: the work is done — the name is the only thing left to say.
    private var minimalBody: some View {
        titleOrField(font: BoardText.titleCompact)
            .lineLimit(1)
            .padding(EdgeInsets(top: 9, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Title with Reminders-style priority marks ("!!") in front. The marks
    /// are neutral on purpose: their count already encodes priority, and
    /// colouring them would spend orange — which on this board means "due
    /// today" — on a second, unrelated meaning.
    private var titleText: Text {
        let base = Text(displayTitle)
            .foregroundStyle(card.status == .done ? HierarchicalShapeStyle.secondary : .primary)
            .strikethrough(card.status == .done)
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
            TextField("Titel", text: $renameText)
                .font(font)
                .textFieldStyle(.plain)
                .focused($isRenameFieldFocused)
                .onAppear { isRenameFieldFocused = true }
                .onSubmit { commitRename() }
                .onExitCommand { isRenaming = false }
        } else {
            titleText.font(font)
        }
    }

    private var repeatIcon: some View {
        Image(systemName: "repeat")
            .font(BoardText.glyph)
            .foregroundStyle(.secondary)
            // Likewise announced by the card's own label ("Wiederholend").
            .boardTooltip("Wiederholende Erinnerung")
    }

    /// Compact rows have no room for the notes preview, so the tooltip
    /// carries it — information without pixels.
    ///
    /// One fact per line, because the tooltip sets the first line as the
    /// subject and the rest as its qualifiers. Joined with "·" they were one
    /// run-on that wrapped mid-phrase and threw the note, the list and the
    /// gesture hint into a single weight.
    private var helpText: String {
        var lines: [String] = []
        if density.isSingleLine && !card.notesPreview.isEmpty {
            lines.append(card.notesPreview)
        }
        lines.append(card.listName)
        lines.append("Klick öffnet Bearbeiten")
        return lines.joined(separator: "\n")
    }

    private var displayTitle: String {
        card.title.isEmpty ? "Ohne Titel" : card.title
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
            parts.append("Erledigt")
        }
        if let priority = priorityDescription {
            parts.append(priority)
        }
        parts.append(displayTitle)
        if let due = card.dueDate {
            parts.append("Fällig \(badge(for: due).label)")
        }
        if card.isRecurring {
            parts.append("Wiederholend")
        }
        parts.append("Liste \(card.listName)")
        if let days = card.daysInColumn(), days >= Board.agingThresholdDays {
            parts.append("Seit \(days) Tagen in dieser Spalte")
        }
        return parts.joined(separator: ", ")
    }

    private var priorityDescription: String? {
        switch card.priority {
        case 1...4: "Hohe Priorität"
        case 5: "Mittlere Priorität"
        case 6...9: "Niedrige Priorität"
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
    private var cardFill: Color {
        reduceTransparency
            ? Color(nsColor: .controlBackgroundColor)
            : Board.cardFill(colorScheme, isDone: card.status == .done)
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

    private var flashOverlay: some View {
        Board.cardShape
            .fill(Color.green.opacity(settleFlash ? 0.18 : 0))
            .allowsHitTesting(false)
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
            return BadgeInfo(label: "Heute", tint: .orange)
        }
        if due < calendar.startOfDay(for: .now) {
            return BadgeInfo(label: "Überfällig", tint: .red, isEmphasized: true)
        }
        if calendar.isDateInTomorrow(due) {
            return BadgeInfo(label: "Morgen", tint: nil)
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

    /// Brief squish-and-settle plus a green flash when this card completes.
    /// One timeline: the squish is animated too. Setting `settleScale` without
    /// an animation snapped the card 6% instantly before the spring took over,
    /// which read as a glitch rather than a reward.
    private func playSettleIfFlagged() {
        guard store.recentlyCompletedIDs.contains(card.id), !reduceMotion else { return }
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.09)) {
                settleScale = 0.94
                settleFlash = true
            }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(Board.settleAnimation) { settleScale = 1 }
            withAnimation(.easeOut(duration: 0.55)) { settleFlash = false }
        }
    }

    // MARK: - Actions

    /// A click opens the in-app editor now — title, notes, due date and
    /// priority all live in GlassKanban itself.
    private func beginEdit() {
        // The board presents the editor, not the card — see
        // `RemindersStore.editingCardID` for why its position must not depend
        // on where the card that opened it happens to sit.
        store.editingCardID = card.id
    }

    /// Escape hatch to the native app, for anything the edit sheet
    /// deliberately leaves out. The sheet offers the same route, so both go
    /// through one implementation.
    private func openInReminders() {
        store.openInReminders(cardID: card.id)
    }

    /// Pre-fills with the real title, not `displayTitle` — "Ohne Titel" is a
    /// placeholder for display, never something to actually type as a title.
    private func beginRename() {
        renameText = card.title
        isRenaming = true
    }

    /// Guarded so the focus-loss path (`onChange` above) and a manual Return
    /// can't both fire for the same edit.
    private func commitRename() {
        guard isRenaming else { return }
        isRenaming = false
        store.renameTicket(cardID: card.id, title: renameText)
    }
}
