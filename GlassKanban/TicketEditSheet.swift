import SwiftUI
import EventKit
import AppKit

/// Edits a reminder directly in GlassKanban, styled as the very card it
/// opened from — same shape, fill, border, zone dividers and list stripe as
/// `CardView.fullBody`. What you see is what you get: this is not a form
/// about the card, it *is* the card, made editable.
///
/// Every field carries a visible caption. Placeholders vanish the moment
/// something is typed, which left the user guessing what a filled field
/// actually meant; a caption stays.
///
/// No Sichern/Abbrechen — like Reminders.app's own quick-look popover, every
/// change is live and closing is what persists it (`save()` runs in
/// `.onDisappear`, regardless of how it closes).
///
/// Presented by the board, centred, over a dimmed backdrop (see
/// `BoardView.editorOverlay`) — not anchored to the card that opened it. An
/// anchored panel put its own position at the mercy of where that card
/// happened to sit: a ticket near the top pushed it over the title bar, one
/// in the last lane pushed it off to the side. Centred, it is in the same
/// place every time. A click on the backdrop closes it, as do "Fertig" and
/// Return.
///
/// **Escape does not close it, and that is a known defect.** AppKit gives the
/// title field first responder as the editor opens, and a focused
/// NSTextField consumes the key for its own "abort editing" instead of
/// letting it travel up. Measured, not assumed: Return reaches "Fertig" from
/// the same focused field, so key equivalents do arrive — Escape specifically
/// is eaten. `.onExitCommand`, a local `NSEvent` monitor, a hidden button
/// carrying `.keyboardShortcut(.cancelAction)`, and removing
/// `FirstResponderNeutralizer` altogether were all tried against the previous
/// popover presentation and all failed; the last of those rules the
/// neutralizer out as the cause.
struct TicketEditSheet: View {
    let card: KanbanCard

    /// Closing is the only exit, and it is what saves — see `save()`. Passed
    /// in rather than taken from `\.dismiss` because the board presents this,
    /// not a sheet or popover of its own.
    let onClose: () -> Void

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date?
    @State private var hasDueTime = false
    @State private var priority = 0
    @State private var calendarID = ""
    @State private var isDuePopoverPresented = false
    /// Set by the "In Erinnerungen öffnen" button, acted on after `save()` —
    /// handing over to the native app before writing would show it a stale
    /// reminder, and leaving this sheet open beside it would let its own
    /// save on close overwrite whatever was edited there.
    @State private var opensRemindersOnClose = false
    /// Guards `save()` against a sheet dismissed before `load()` finishes —
    /// without it, an instant close-before-load would overwrite the reminder
    /// with blank fields.
    @State private var isLoaded = false

    /// One surface, edge to edge.
    ///
    /// The card used to be inset by 20pt inside a popover, which put two
    /// backgrounds on screen behind one piece of content: an opaque rectangle
    /// floating in a ring of glass, with the board showing through the ring.
    /// That doubling is exactly what this board's depth model exists to
    /// prevent. The paper now fills the panel, and the panel is the card.
    ///
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            zoneDivider
            notesZone
            zoneDivider
            factsZone
            zoneDivider
            actionsZone
        }
        .frame(width: 420)
        .background(cardFill)
        .overlay(alignment: .leading) { listStripe }
        // The card's own contour, back now that nothing else supplies one:
        // a popover brought its shape, border and shadow with it, and this
        // is presented on the bare board. Same shape as every card on it,
        // because that is what this is.
        .clipShape(Board.cardShape)
        .overlay { Board.cardShape.strokeBorder(Board.cardBorder(contrast)) }
        .shadow(color: Board.cardShadowResting.color, radius: Board.cardShadowResting.radius, y: Board.cardShadowResting.y)
        .shadow(color: .black.opacity(0.22), radius: 30, y: 12)
        // macOS assigns a freshly presented popover's first eligible text
        // field as first responder on its own — before anything SwiftUI's own
        // focus system can do about it. Both `@FocusState` (however it was
        // timed) and `prefersDefaultFocus`/`.focusScope` were tried here and
        // lost that race; they operate above AppKit's own default-responder
        // assignment for a window that has just become key, not underneath
        // it. `FirstResponderNeutralizer` reaches AppKit directly instead, so
        // a stray keystroke while just glancing at a card is safely absorbed
        // rather than landing — silently, permanently, this editor has no
        // Cancel — in the title field.
        .background(FirstResponderNeutralizer())
        .task { load() }
        .onDisappear {
            save()
            if opensRemindersOnClose {
                store.openInReminders(cardID: card.id)
            }
        }
    }

    /// The card's last zone rather than a button bar below it — once the card
    /// fills the popover there is no "below it" left, and the buttons belong
    /// to the same surface as everything else.
    private var actionsZone: some View {
        HStack {
            // A link, not a second filled button: this is the rarely needed
            // way out to the native app, and giving it equal weight beside
            // "Fertig" would suggest the editor needs it. It lives here
            // because the card's context menu — the other route to it — is
            // unreachable while this popover is open.
            Button("In Erinnerungen öffnen") {
                opensRemindersOnClose = true
                onClose()
            }
            .buttonStyle(.link)
            .font(BoardText.body)
            Spacer(minLength: 12)
            Button("Fertig") { onClose() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(EdgeInsets(top: 10, leading: Board.cardInsetLeading, bottom: 12, trailing: Board.cardInsetTrailing))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            fieldCaption("Titel")
            // Empty placeholder: the caption above already names the field,
            // and a second "Titel" inside it just said the same thing twice.
            TextField("", text: $title)
                .textFieldStyle(.plain)
                .font(BoardText.title)
        }
        .padding(EdgeInsets(top: 11, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
    }

    private var notesZone: some View {
        VStack(alignment: .leading, spacing: 3) {
            fieldCaption("Notizen")
            // A `TextEditor` here always wrapped its content in a scrollable
            // NSScrollView, which drew scroller chrome even on empty notes.
            // A field that grows with its content sidesteps the scroll view
            // entirely for the common case (short notes), matching how
            // Reminders.app's own notes field behaves.
            TextField("", text: $notes, axis: .vertical)
                .font(BoardText.body)
                .textFieldStyle(.plain)
                .lineLimit(3...8)
        }
        .padding(EdgeInsets(top: 8, leading: Board.cardInsetLeading, bottom: 8, trailing: Board.cardInsetTrailing))
    }

    /// The card's facts, one labelled row each — from the most stable
    /// property to the most volatile: which list a card belongs to rarely
    /// changes, its due date changes most often. "Dringlichkeit"/"Fälligkeit"
    /// are the same words the find popover uses for these two properties, so
    /// the board speaks one vocabulary throughout.
    private var factsZone: some View {
        VStack(spacing: 8) {
            factRow("Liste") { listControl }
            factRow("Dringlichkeit") { priorityControl }
            factRow("Fälligkeit") { dueDateControl }
        }
        .padding(EdgeInsets(top: 10, leading: Board.cardInsetLeading, bottom: 11, trailing: Board.cardInsetTrailing))
    }

    private func factRow<Control: View>(
        _ caption: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            fieldCaption(caption)
                // Without this a long value makes SwiftUI wrap the caption
                // rather than the value — the same failure the find popover
                // documents on its own filter rows.
                .fixedSize()
            Spacer(minLength: 0)
            control()
        }
        // Every row keeps a menu control's height whatever it holds, so the
        // card never grows or shrinks as values are set and cleared.
        .frame(minHeight: Self.factRowHeight)
    }

    /// Height of a menu picker at this text size — the tallest of the three
    /// controls, and therefore what the other rows have to reserve.
    private static let factRowHeight: CGFloat = 22

    /// A structural label, not decorative meta — it has to read clearly at a
    /// glance, so it borrows `BoardText.chip`'s semibold weight (this app's
    /// answer to "small text that must stay legible") rather than the
    /// thinner `BoardText.meta` used for de-emphasized detail.
    private func fieldCaption(_ text: String) -> some View {
        Text(text)
            .font(BoardText.chip)
            .foregroundStyle(.secondary)
    }

    private var zoneDivider: some View {
        Rectangle()
            .fill(Board.cardBorder(contrast))
            .frame(height: 1)
            .padding(.leading, Board.cardInsetLeading)
            .padding(.trailing, Board.cardInsetTrailing)
    }

    private var cardFill: Color {
        reduceTransparency
            ? Color(nsColor: .controlBackgroundColor)
            : Board.cardFill(colorScheme)
    }

    private var listStripe: some View {
        Capsule()
            .fill(stripeColor.opacity(0.9))
            .frame(width: Board.cardStripeWidth)
            .padding(.vertical, 9)
            .padding(.leading, 5)
            .allowsHitTesting(false)
    }

    /// Follows the list picker live, so switching lists re-colours the stripe
    /// immediately — the card's own colour code, same mix as `CardView`.
    private var stripeColor: Color {
        let color = store.selectableCalendars
            .first { $0.calendarIdentifier == calendarID }
            .map { Color(nsColor: $0.color ?? .controlAccentColor) }
            ?? card.listColor
        return color.mix(with: Color(nsColor: .labelColor), by: 0.18)
    }

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

    // MARK: - Fact controls

    private var priorityControl: some View {
        Picker("Dringlichkeit", selection: priorityBinding) {
            ForEach(PriorityOption.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    /// Reads through `PriorityOption.nearest(to:)` so the menu always shows
    /// one of the four buckets Reminders.app itself offers; writes the
    /// bucket's exact value.
    private var priorityBinding: Binding<PriorityOption> {
        Binding(
            get: { PriorityOption.nearest(to: priority) },
            set: { priority = $0.rawValue })
    }

    /// One button at one width, whatever it is showing — no date, a date, or
    /// a date and time. Its text is formatted here rather than by a stepper
    /// field, whose own text follows the system region ("1. 9.2026") with no
    /// way to pin it to dd.MM.yyyy.
    ///
    /// The width is held by an invisible copy of the longest form it can ever
    /// show. Without it the button shrank the moment the time was switched
    /// off — and since the calendar hangs off this button, the whole popover
    /// slid sideways under the pointer while the switch that caused it was
    /// still being aimed at.
    private var dueDateControl: some View {
        Button {
            isDuePopoverPresented = true
        } label: {
            Text(Self.dueWidthTemplate)
                .monospacedDigit()
                .font(BoardText.body)
                .hidden()
                .overlay(alignment: .trailing) {
                    Group {
                        if let dueDate {
                            Text(Self.dueLabel(for: dueDate, includesTime: hasDueTime))
                                .monospacedDigit()
                        } else {
                            Text("Kein Datum").foregroundStyle(.secondary)
                        }
                    }
                    .font(BoardText.body)
                    .lineLimit(1)
                    .fixedSize()
                }
        }
        .popover(isPresented: $isDuePopoverPresented, arrowEdge: .bottom) {
            duePopover
        }
    }

    /// The widest string this button can hold — a full date with a time. All
    /// digits, so `monospacedDigit()` makes it an exact stand-in for any real
    /// value rather than an estimate.
    private static let dueWidthTemplate = "00.00.0000, 00:00"

    /// Picking a day in the calendar is what sets the date — opening the
    /// popover on an undated card must not, or merely looking would date it.
    private var dueBinding: Binding<Date> {
        Binding(
            get: { dueDate ?? Foundation.Calendar.current.startOfDay(for: .now) },
            set: { dueDate = $0 })
    }

    private var showsTimePicker: Bool { hasDueTime && dueDate != nil }

    private var duePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            // No explicit width: the month grid has a fixed intrinsic size on
            // macOS (the same one Calendar.app's date popover uses), so a
            // wider frame only pads empty space beside it.
            DatePicker("Fällig", selection: dueBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            Divider()
            HStack {
                Toggle("Uhrzeit", isOn: $hasDueTime)
                    .disabled(dueDate == nil)
                Spacer(minLength: 8)
                // Always laid out, only sometimes visible. Inserting the time
                // field when the switch went on resized the popover under the
                // pointer — and the switch sits one row above the calendar, so
                // the whole grid jumped with it. A control that appears must
                // not move the thing you are still aiming at; reserving its
                // space costs nothing and keeps the panel still.
                DatePicker("Uhrzeit", selection: dueBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .monospacedDigit()
                    .opacity(showsTimePicker ? 1 : 0)
                    .disabled(!showsTimePicker)
                    .accessibilityHidden(!showsTimePicker)
            }
            .font(BoardText.body)
            if dueDate != nil {
                Divider()
                Button("Datum entfernen") {
                    dueDate = nil
                    hasDueTime = false
                    isDuePopoverPresented = false
                }
                .buttonStyle(.link)
                .font(BoardText.body)
            }
        }
        .padding(14)
    }

    /// Fixed dd.MM.yyyy regardless of the system region, which is what was
    /// asked for — a locale-driven style renders "1. 9.2026" or "9/1/2026"
    /// depending on settings this app has no reason to follow.
    private static func dueLabel(for date: Date, includesTime: Bool) -> String {
        let day = date.formatted(
            .verbatim("\(day: .twoDigits).\(month: .twoDigits).\(year: .defaultDigits)",
                      timeZone: .current,
                      calendar: .current))
        guard includesTime else { return day }
        let time = date.formatted(
            .verbatim("\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                      timeZone: .current,
                      calendar: .current))
        return "\(day), \(time)"
    }

    /// Moving a card to another list is the one card property the sheet used
    /// to leave to Reminders.app. It is a plain `EKReminder.calendar` write,
    /// so it belongs here with the rest.
    private var listControl: some View {
        Picker("Liste", selection: $calendarID) {
            ForEach(calendarOptions, id: \.calendarIdentifier) { calendar in
                Text(calendar.title).tag(calendar.calendarIdentifier)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    /// The card's own list is always offered, even when it is read-only or
    /// hidden from the board — otherwise the picker would show a blank
    /// selection for a list the card demonstrably sits in.
    private var calendarOptions: [EKCalendar] {
        let selectable = store.selectableCalendars
        guard !calendarID.isEmpty,
              !selectable.contains(where: { $0.calendarIdentifier == calendarID }),
              let own = store.reminderCalendars.first(where: { $0.calendarIdentifier == calendarID })
        else { return selectable }
        return [own] + selectable
    }

    // MARK: - Persistence

    private func load() {
        guard let ticket = store.loadEditableTicket(cardID: card.id) else { return }
        title = ticket.title
        notes = ticket.notes
        dueDate = ticket.dueDate
        hasDueTime = ticket.hasDueTime
        priority = ticket.priority
        calendarID = ticket.calendarID
        isLoaded = true
    }

    private func save() {
        guard isLoaded else { return }
        store.updateTicket(
            cardID: card.id,
            title: title,
            notes: notes,
            dueDate: dueDate,
            hasDueTime: hasDueTime,
            priority: priority,
            calendarID: calendarID)
    }
}

/// The four priority buckets Reminders.app's own UI exposes, in its order.
/// EventKit's full 0–9 scale collapses onto these — same ranges as
/// `KanbanCard.priorityMarks`.
private enum PriorityOption: Int, CaseIterable, Identifiable {
    case none = 0
    case low = 9
    case medium = 5
    case high = 1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none: "Keine"
        case .low: "Niedrig"
        case .medium: "Mittel"
        case .high: "Hoch"
        }
    }

    static func nearest(to priority: Int) -> PriorityOption {
        switch priority {
        case 1...4: .high
        case 5: .medium
        case 6...9: .low
        default: .none
        }
    }
}

/// A zero-size view whose only job is to take first responder away from
/// whatever AppKit assigned it by default, the moment its window has one.
/// `viewDidMoveToWindow` is not late enough by itself — the window can still
/// be in the middle of becoming key — so `didBecomeKeyNotification` backs it
/// up.
///
/// Targets `window.contentView` (the SwiftUI hosting view), not the window
/// itself: an earlier version handed responder status to the window
/// directly, which did stop stray characters from landing in the title
/// field, but also silently broke Escape-to-dismiss — the sheet's own
/// cancel handling apparently routes through the hosting view, and a bare
/// `NSWindow` first responder doesn't forward into it. The hosting view is
/// the neutral default this sheet would already have if AppKit didn't treat
/// a fresh sheet's first text field as a special case; restoring that
/// default, rather than replacing it with something else entirely, is what
/// keeps Escape and Return both working.
private struct FirstResponderNeutralizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NeutralizingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class NeutralizingView: NSView {
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observer.map(NotificationCenter.default.removeObserver)
            guard let window else { return }
            window.makeFirstResponder(window.contentView)
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak window] _ in
                window?.makeFirstResponder(window?.contentView)
            }
        }

        deinit {
            observer.map(NotificationCenter.default.removeObserver)
        }
    }
}
