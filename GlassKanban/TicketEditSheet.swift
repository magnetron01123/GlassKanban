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
/// No Sichern/Abbrechen *buttons* — like Reminders.app's own quick-look
/// popover, every change is live and closing is what persists it (`save()`
/// runs in `.onDisappear`). The two answers a card can be given are on the
/// keyboard instead, in the words the board already uses for its inline
/// rename: **Return übernimmt, Escape verwirft.** A click on the board behind
/// it counts as Return — putting the note back on the wall keeps what is
/// written on it.
///
/// Escape is what this editor was missing rather than a convenience: a card
/// opened by accident, typed into by accident, had no way back at all.
/// Cancelling a ticket the "+" has just made cancels the creation with it
/// (`RemindersStore.cancelNewTicket`) — nothing typed here was ever written,
/// so there is nothing to keep.
///
/// Presented by the board, centred, over a dimmed backdrop (see
/// `BoardView.editorOverlay`) — not anchored to the card that opened it. An
/// anchored panel put its own position at the mercy of where that card
/// happened to sit: a ticket near the top pushed it over the title bar, one
/// in the last lane pushed it off to the side. Centred, it is in the same
/// place every time.
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
    @State private var url = ""
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
    /// Escape was pressed: this close discards instead of saving. Read in
    /// `.onDisappear` the same way `opensRemindersOnClose` is — the close
    /// runs an animation out, so the decision has to survive until the view
    /// is actually gone.
    @State private var isCancelled = false
    /// Guards `closeAndPersist` — see there.
    @State private var hasClosed = false
    /// What was loaded, verbatim — the reference a close compares against.
    /// Without it every glance at a card wrote every field back on close,
    /// which bumped `lastModifiedDate` (resetting the card's dwell-time
    /// label), pushed no-op changes through iCloud, and raised the save-error
    /// alert on read-only lists for merely looking.
    @State private var loadedTicket: EditableTicket?
    @Environment(\.undoManager) private var undoManager
    @State private var hoveredField: EditableField?
    /// Claimed for a brand-new ticket only. An existing card opens for
    /// *reading* — there the neutralizer keeps stray keystrokes out of the
    /// title on purpose. A ticket the "+" just made opens for *writing*, and
    /// its first missing thing is the name.
    @FocusState private var titleFocused: Bool

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
            urlZone
            zoneDivider
            factsZone
        }
        // 500, and the notes below reserve four lines: at 520 with a three-line
        // notes field the card came out near 3:1, which is a banner rather
        // than a note. The lanes' own full cards sit near 2.4:1, and matching
        // that is what keeps this reading as the same object enlarged.
        .frame(width: 500)
        .background(cardFill)
        .overlay(alignment: .leading) { listStripe }
        // The card's own contour, back now that nothing else supplies one:
        // a popover brought its shape, border and shadow with it, and this
        // is presented on the bare board. Same shape as every card on it,
        // because that is what this is.
        .clipShape(Board.openCardShape)
        .overlay { Board.openCardShape.strokeBorder(Board.cardBorder(contrast)) }
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
        // Return and Escape, for whichever field is being typed in — or none.
        // Switched off while the date popover is up: that is a window of its
        // own, and both keys belong to it while it stands.
        .background(
            EditorKeyCommands(
                isEnabled: !isDuePopoverPresented,
                onCommit: onClose,
                onCancel: cancel))
        .task { load() }
        .onDisappear { closeAndPersist() }
        // Quitting is the one close that does not go through `onDisappear`:
        // AppKit tears the window down without SwiftUI running a disappear
        // pass, so ⌘Q with a card open dropped whatever had been typed — and
        // for a ticket the "+" had just made, left the untitled placeholder
        // behind in Reminders, which is exactly the ghost
        // `finalizeNewTicket` exists to prevent. Terminating counts as
        // closing: the note goes back on the wall with what is written on it.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            closeAndPersist()
        }
    }

    /// Everything a close has to do, on either route in. Runs at most once:
    /// with both routes live, a normal close would otherwise save twice —
    /// harmless for the write itself (`save` compares against the baseline),
    /// but `finalizeNewTicket` is not idempotent in spirit and neither is the
    /// jump to Reminders.
    private func closeAndPersist() {
        guard !hasClosed else { return }
        hasClosed = true
        // Escape: write nothing, and take back a creation that was
        // cancelled rather than finished. Everything the fields hold is
        // still local state at this point — discarding is literally not
        // saving, which is why there is nothing else to undo here.
        if isCancelled {
            store.cancelNewTicket(cardID: card.id, undoManager: undoManager)
            return
        }
        save()
        if opensRemindersOnClose {
            store.openInReminders(cardID: card.id)
        }
        // A ticket the "+" just made, closed without any input, is an
        // abandoned creation — the store removes it again so no untitled
        // ghost stays behind. Jumping to Reminders counts as keeping it:
        // the user is clearly on the way to fill it in over there.
        store.finalizeNewTicket(cardID: card.id, keep: opensRemindersOnClose, undoManager: undoManager)
    }

    /// Escape: mark the close as a discard, then close on the same path
    /// everything else does, so the card goes back with the same animation
    /// whichever answer it was given.
    private func cancel() {
        isCancelled = true
        onClose()
    }

    /// The card carries no buttons.
    ///
    /// It had two — "Fertig" and a link out to Reminders — and they were what
    /// made a card read as a dialog wearing a card's clothes. Nothing you pin
    /// to a wall has an OK button. Closing is done by putting the card back
    /// (a click on the board behind it), and the one remaining action is the
    /// hand-off to the native app, which is a *link* and therefore belongs
    /// where links live on a card: a small mark in the corner, the same place
    /// a real ticket carries its reference number.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: Board.editorCaptionSpacing) {
                fieldCaption("Titel")
                // Empty placeholder: the caption above already names the
                // field, and a second "Titel" inside it just said the same
                // thing twice.
                TextField("", text: $title)
                    .textFieldStyle(.plain)
                    .font(BoardText.editorTitle)
                    .focused($titleFocused)
                    .editableHint(hoveredField == .title, scheme: colorScheme)
                    // The chip beside it is a sibling view, not part of this
                    // field, so the state has to be said here too.
                    .accessibilityLabel(isDone ? "Titel, erledigt" : "Titel")
            }
            .onHover { hovering in
                withAnimation(Board.hoverAnimation) {
                    hoveredField = hovering ? .title : (hoveredField == .title ? nil : hoveredField)
                }
            }
            openInRemindersMark
        }
        .padding(EdgeInsets(top: 16, leading: Board.openCardInset, bottom: 12, trailing: Board.openCardInset))
    }

    /// Only the spoken label distinguishes a finished ticket now. Nothing
    /// on screen does, by design — but a screen reader has no lane around the
    /// card to infer it from, and dropping the word for the sake of symmetry
    /// would take away information rather than noise.
    private var isDone: Bool { card.status == .done }

    private var openInRemindersMark: some View {
        Button {
            opensRemindersOnClose = true
            onClose()
        } label: {
            Image(systemName: "arrow.up.forward.app")
                .font(BoardText.editorGlyph)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        // No `.help` — the card is content, and tooltips on a card are a
        // settled no (BACKLOG.md, "Explizit abgelehnt"); the opened card is
        // still a card. `BoardTooltip` says the same thing from the other
        // side: it replaces `.help()`, never joins it. VoiceOver keeps the
        // label below.
        .accessibilityLabel("In Erinnerungen öffnen")
    }

    private var notesZone: some View {
        VStack(alignment: .leading, spacing: Board.editorCaptionSpacing) {
            fieldCaption("Notizen")
            // A `TextEditor`, not a vertical-axis `TextField`.
            //
            // The field was chosen to dodge the scroll view a TextEditor
            // brings with it, and it cost the one thing notes are for:
            // Return in a TextField submits and re-selects rather than
            // breaking the line, so a list could be read but never written
            // here. Notes on a ticket are lists more often than they are
            // prose.
            //
            // The chrome that drove the original choice is switched off
            // rather than avoided — `scrollContentBackground(.hidden)` takes
            // away the inset box, and macOS's overlay scrollers stay out of
            // sight until there is something to scroll. TextEditor also insets
            // its text by a few points of its own, which the negative padding
            // cancels so the first character sits on the same left edge as
            // every caption and field above it.
            TextEditor(text: $notes)
                .font(BoardText.editorBody)
                .scrollContentBackground(.hidden)
                // The scroller track is the rest of that chrome, and it shows
                // on this field the moment the text reaches four lines. A
                // four-line box does not need one: text cut mid-line at the
                // bottom edge already says there is more, which is the cue
                // every compact field on the platform relies on.
                .scrollIndicators(.never)
                .padding(.leading, -5)
                // Room for four lines, like the lanes' own cards keep a body
                // even when the notes are empty — a card with no room for
                // text is a label. Longer notes scroll rather than stretching
                // the card, which is what keeps its proportion steady.
                .frame(height: Self.notesHeight)
                // The lane card's answer for an empty notes zone, carried
                // into the opened card — same words, same tier. Four blank
                // lines under a caption pose the same question the blank
                // strip on the card did.
                .overlay(alignment: .topLeading) {
                    emptyValue("Keine Notizen", when: Self.normalizedNotes(notes).isEmpty)
                        // TextEditor sets its first line a hair below its own
                        // top edge; the label follows it rather than the
                        // frame, so the two sit on one baseline.
                        .padding(.top, 1)
                }
                .editableHint(hoveredField == .notes, scheme: colorScheme)
                .onHover { hovering in
                    withAnimation(Board.hoverAnimation) {
                        hoveredField = hovering ? .notes : (hoveredField == .notes ? nil : hoveredField)
                    }
                }
        }
        .padding(EdgeInsets(top: 12, leading: Board.openCardInset, bottom: 12, trailing: Board.openCardInset))
    }

    /// Which field the pointer is over, so each lights up on its own rather
    /// than the whole card reacting as one block.
    private enum EditableField { case title, notes, url }

    /// The reminder's own URL field, which Reminders shows on every task and
    /// this editor did not.
    ///
    /// A zone of its own, ruled off from the notes above it. It is a
    /// different kind of content — one address, not a body of text — and
    /// sharing the notes' zone left the two reading as one block whose
    /// second half happened to be labelled.
    private var urlZone: some View {
        VStack(alignment: .leading, spacing: Board.editorCaptionSpacing) {
            fieldCaption("URL")
            TextField("", text: $url)
                .font(BoardText.editorBody)
                .textFieldStyle(.plain)
                .lineLimit(1)
                // No autocorrection or capitalisation on an address — the
                // system would otherwise "fix" a domain into a sentence.
                .autocorrectionDisabled()
                .overlay(alignment: .leading) {
                    emptyValue("Keine URL", when: url.isEmpty)
                }
                .editableHint(hoveredField == .url, scheme: colorScheme)
                .onHover { hovering in
                    withAnimation(Board.hoverAnimation) {
                        hoveredField = hovering ? .url : (hoveredField == .url ? nil : hoveredField)
                    }
                }
        }
        .padding(EdgeInsets(top: 12, leading: Board.openCardInset, bottom: 12, trailing: Board.openCardInset))
    }

    /// The card's facts, one labelled row each — from the most stable
    /// property to the most volatile: which list a card belongs to rarely
    /// changes, its due date changes most often. "Dringlichkeit"/"Fälligkeit"
    /// are the same words the find popover uses for these two properties, so
    /// the board speaks one vocabulary throughout.
    private var factsZone: some View {
        VStack(spacing: 8) {
            // The creation date leads because the zone's own order demands
            // it: rows run from the most stable property to the most
            // volatile, and this one never changes at all. Leading also
            // parks it as far as possible from "Fälligkeit", so the card's
            // two dates can never read as one stacked pair.
            //
            // It is here because the open lanes sort by age (see
            // `KanbanCard.openLaneOrder`): a card's position carries a rule
            // the board never spells out, and Kanban's "make policies
            // explicit" asks that such a rule be findable — the same reason
            // the WIP limit rides along in the lane counter. The editor is
            // where it costs nothing: the ambient board stays untouched.
            // "Erfasst", not "Angelegt": Personal Kanban's own word for the
            // act the "+" performs — capturing work out of the head and
            // onto the board (Benson's capture step). "Angelegt" is file-
            // system German; this board speaks Kanban in its chrome
            // ("Fertigwerden beginnt hier"), and the date names when the
            // commitment was captured, not when a record was created.
            if let created = card.creationDate {
                factRow("Erfasst") {
                    // Bare secondary text where the other rows carry
                    // controls: no bezel, no chevron — the stillness is
                    // what says "fact, not setting". The row itself is the
                    // shape Finder's own info panel gives an uneditable
                    // date sitting among editable fields.
                    //
                    // Indented by the bezel's own text inset so it starts on
                    // the same vertical line as the three values below it:
                    // without a bezel of its own it would otherwise sit a
                    // control's padding further left than every value it is
                    // stacked above.
                    Text(created.formatted(date: .long, time: .omitted))
                        .font(BoardText.editorBody)
                        .foregroundStyle(.secondary)
                        .padding(.leading, Self.controlTextInset)
                        .frame(width: Self.factControlWidth, alignment: .leading)
                }
            }
            factRow("Liste") { listControl }
            factRow("Dringlichkeit") { priorityControl }
            factRow("Fälligkeit") { dueDateControl }
        }
        .padding(EdgeInsets(top: 14, leading: Board.openCardInset, bottom: 16, trailing: Board.openCardInset))
    }

    /// One caption at the card's left edge, one control at its right — and
    /// every control the same width, which is what makes the zone a grid
    /// rather than four rows that happen to sit above each other.
    ///
    /// Sized controls, not self-sizing ones: left to their own intrinsic
    /// width each control ended somewhere else on the left — a long bar for
    /// the lists, a stub for the four priorities, a third width for the date
    /// — so the block had one clean edge (the right) and a ragged one facing
    /// the captions, and the date's bar was three times the length of the
    /// word in it. One width is the platform's own answer: an AppKit form
    /// aligns its controls on both edges. It is deliberately *not* the row
    /// pattern of System Settings, whose ragged left edge is carried by a
    /// grey row background with dividers — chrome this card does not have.
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
            // No width forced from out here: neither a menu nor a bordered
            // button accepts one (see `factControlLabel`). Each control is
            // sized from the inside instead, by a label of one fixed width —
            // which comes to the same thing, and actually holds.
            control()
        }
        // Every row keeps a menu control's height whatever it holds, so the
        // card never grows or shrinks as values are set and cleared.
        .frame(minHeight: Self.factRowHeight)
    }

    /// Four lines of `editorBody` plus its leading.
    private static let notesHeight: CGFloat = 72

    /// Height of a menu picker at this text size — the tallest of the three
    /// controls, and therefore what the other rows have to reserve.
    private static let factRowHeight: CGFloat = 26

    /// One width for all three controls, which is what gives the zone its
    /// second edge.
    ///
    /// Wide enough for the longest value any of them can hold — a full date
    /// with a time ("00.00.0000, 00:00") and a list name of ordinary length —
    /// with a little room to spare, and no wider: a bar that dwarfs its own
    /// content reads as an empty field rather than a filled one. Longer list
    /// names truncate, which is what a pop-up button on this platform does
    /// anyway; growing the control instead would hand the card's layout to
    /// whatever someone called their list.
    private static let factControlWidth: CGFloat = 180

    /// How far a bordered control insets its own text. Only the uncontrolled
    /// value ("Erfasst") has to add it by hand, so that all four values in
    /// the zone start on one vertical line.
    private static let controlTextInset: CGFloat = 6

    /// A structural label, not decorative meta — it has to read clearly at a
    /// glance, so it borrows `BoardText.chip`'s semibold weight (this app's
    /// answer to "small text that must stay legible") rather than the
    /// thinner `BoardText.meta` used for de-emphasized detail.
    private func fieldCaption(_ text: String) -> some View {
        Text(text)
            .font(BoardText.editorCaption)
            .foregroundStyle(.secondary)
    }

    /// What a field says while it holds nothing — one wording and one tier
    /// for all three of them ("Keine Notizen", "Keine URL", "Kein Datum").
    ///
    /// This is not the placeholder the captions replaced: that one repeated
    /// the field's *name* inside it and vanished as soon as anything was
    /// typed, leaving a filled field with no label. This one carries the
    /// field's *state*, and the caption above it stands either way.
    ///
    /// Secondary, because a placeholder is not a value — it is the app
    /// saying there isn't one, which is the second tier's whole job (see
    /// `BoardText`). Set in primary it was indistinguishable from typed
    /// text: "Keine Notizen" sat in the notes field in the same black as a
    /// real note, two rows above "Dringlichkeit: Keine", which *is* a value.
    /// Nothing on screen said which of the two was content. The platform
    /// makes the same distinction — this window's own search field dims its
    /// placeholder — and it costs no third shade to follow it.
    ///
    /// Non-interactive, because it lies over the field it describes and a
    /// click on it belongs to that field.
    @ViewBuilder
    private func emptyValue(_ text: String, when isEmpty: Bool) -> some View {
        if isEmpty {
            Text(text)
                .font(BoardText.editorBody)
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var zoneDivider: some View {
        Rectangle()
            .fill(Board.cardBorder(contrast))
            .frame(height: 1)
            .padding(.leading, Board.openCardInset)
            .padding(.trailing, Board.openCardInset)
    }

    /// One paper tone whatever the ticket's state. The lanes dim a finished
    /// card because it is one of many and has to recede among them; held open
    /// on its own there is nothing for it to recede behind, and a card that
    /// looks different depending on which lane it came from is two cards.
    ///
    /// And one fill in every mode, for the reason `CardView.cardFill` gives:
    /// a solid colour has nothing for "Transparenz reduzieren" to switch off,
    /// and the stand-in this used to reach for was darker than the board
    /// behind it in dark mode.
    private var cardFill: Color {
        Board.cardFill(colorScheme)
    }

    private var listStripe: some View {
        Capsule()
            .fill(stripeColor.opacity(0.9))
            .frame(width: Board.cardStripeWidth + 1)
            .padding(.vertical, 12)
            .padding(.leading, 7)
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


    // MARK: - Fact controls

    /// The date button's label, built to match what AppKit draws inside the
    /// two pop-up buttons above it: value at the leading edge, chevron at the
    /// trailing one, the button's width in between.
    private func factControlLabel(_ text: String, isPlaceholder: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(BoardText.editorBody)
                .foregroundStyle(isPlaceholder ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            // A chevron on each of the three, because they open the same way.
            // The date used to be a bare push button, so the pair with a ⌄
            // looked like controls and it like a label that happened to be
            // raised.
            //
            // Drawn at the size and offset AppKit gives the two pop-up
            // buttons above, measured against them on screen: a hand-made
            // glyph that is a shade smaller or a few points further in is
            // exactly the kind of near-miss that makes three aligned rows
            // look accidental again.
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.trailing, -3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priorityControl: some View {
        FactPopUpButton(
            titles: PriorityOption.allCases.map(\.displayName),
            selectedIndex: PriorityOption.allCases.firstIndex(of: PriorityOption.nearest(to: priority)) ?? 0,
            width: Self.factControlWidth,
            accessibilityLabel: "Dringlichkeit"
        ) { index in
            priority = PriorityOption.allCases[index].rawValue
        }
    }

    /// A pop-up button in everything but mechanism: same width as the two
    /// menus above it, same bezel, value left and chevron right, because it
    /// answers the same kind of question. Only its menu is a calendar.
    ///
    /// "Same bezel" was checked rather than assumed — a SwiftUI button beside
    /// two AppKit pop-ups is exactly where a stray shade would hide. Sampled
    /// on screen, all three fills are the same pixel: 240 in light, 98 in
    /// dark. What looks lighter here is the placeholder text, one tier down
    /// on purpose (see `emptyValue`).
    ///
    /// Its text is formatted here rather than by a stepper field, whose own
    /// text follows the system region ("1. 9.2026") with no way to pin it to
    /// dd.MM.yyyy.
    ///
    /// One width whatever it shows — no date, a date, or a date and time.
    /// That width now comes from the row (`factControlWidth`) rather than an
    /// invisible template inside the button, but it is doing the same job:
    /// the calendar hangs off this button, so a button that resized with its
    /// own value slid the whole popover sideways under the pointer while the
    /// switch that caused it was still being aimed at.
    private var dueDateControl: some View {
        Button {
            isDuePopoverPresented = true
        } label: {
            if let dueDate {
                factControlLabel(Self.dueLabel(for: dueDate, includesTime: hasDueTime))
                    .monospacedDigit()
            } else {
                // Same tier as the two empty fields above it — it says the
                // same thing about the same card.
                factControlLabel("Kein Datum", isPlaceholder: true)
            }
        }
        .frame(width: Self.factControlWidth)
        .popover(isPresented: $isDuePopoverPresented, arrowEdge: .bottom) {
            duePopover
        }
        .accessibilityLabel("Fälligkeit")
        .accessibilityValue(dueDate.map { Self.dueLabel(for: $0, includesTime: hasDueTime) } ?? "Kein Datum")
    }

    /// Picking a day in the calendar is what sets the date — opening the
    /// popover on an undated card must not, or merely looking would date it.
    /// Reads midnight for an undated card, but a *working* hour once a time
    /// is actually switched on. Switching "Uhrzeit" on used to leave the
    /// picker at 00:00, so a reminder that had been all-day quietly became
    /// one due at midnight — and Reminders duly notified at midnight.
    private var dueBinding: Binding<Date> {
        Binding(
            get: { dueDate ?? Foundation.Calendar.current.startOfDay(for: .now) },
            set: { dueDate = $0 })
    }

    /// The hour a date gets when a time is switched on for the first time.
    /// Nine in the morning is what Reminders itself defaults to, and it is a
    /// time someone might have meant.
    private static let defaultDueHour = 9

    private func dueTimeSwitchedOn() {
        let calendar = Foundation.Calendar.current
        let base = dueDate ?? calendar.startOfDay(for: .now)
        guard calendar.component(.hour, from: base) == 0,
              calendar.component(.minute, from: base) == 0 else { return }
        dueDate = calendar.date(
            bySettingHour: Self.defaultDueHour, minute: 0, second: 0, of: base) ?? base
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
                    .onChange(of: hasDueTime) { _, isOn in
                        if isOn { dueTimeSwitchedOn() }
                    }
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
            .font(BoardText.editorBody)
            if dueDate != nil {
                Divider()
                Button("Datum entfernen") {
                    dueDate = nil
                    hasDueTime = false
                    isDuePopoverPresented = false
                }
                .buttonStyle(.link)
                .font(BoardText.editorBody)
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
        FactPopUpButton(
            titles: calendarOptions.map(\.title),
            selectedIndex: calendarOptions.firstIndex { $0.calendarIdentifier == calendarID } ?? 0,
            width: Self.factControlWidth,
            accessibilityLabel: "Liste"
        ) { index in
            guard calendarOptions.indices.contains(index) else { return }
            calendarID = calendarOptions[index].calendarIdentifier
        }
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
        guard var ticket = store.loadEditableTicket(cardID: card.id) else { return }
        // Normalised on the way in, so the baseline is measured the same way
        // the edit will be. `save` trims the title before comparing; against
        // an untrimmed baseline a stored "Angebot prüfen " differed from
        // itself, and merely opening the card and closing it again counted as
        // a change — a write, a bumped modification date, and a reset dwell
        // time for a card nobody edited.
        ticket.title = ticket.title.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.notes = Self.normalizedNotes(ticket.notes)
        title = ticket.title
        notes = ticket.notes
        url = ticket.url
        dueDate = ticket.dueDate
        hasDueTime = ticket.hasDueTime
        priority = ticket.priority
        calendarID = ticket.calendarID
        loadedTicket = ticket
        isLoaded = true
        // A brand-new ticket opens ready to type its name. Delayed a beat:
        // the field is not in the responder chain in the same tick it
        // appears, and the neutralizer below needs to have done its work
        // first so this claim lands after it, not before.
        if store.newlyCreatedCardID == card.id {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                titleFocused = true
            }
        }
    }

    /// Writes only when something actually changed — opening a card to read
    /// it and putting it back must be a read, not a write. An emptied title
    /// falls back to the loaded one: a card whose name was wiped by accident
    /// is not a rename (same rule as `TicketRename` for the inline path).
    /// A note that holds nothing but blank lines *is* nothing.
    ///
    /// Three taps of Return in an empty field left "\n\n\n" behind, which is
    /// not equal to "" — so closing the card wrote it, and in the two lanes
    /// that carry no tag (Backlog, Erledigt) nothing ever trimmed it away
    /// again. The field then looked empty on every later visit while
    /// "Keine Notizen" stayed hidden, because the placeholder asked
    /// `isEmpty`. Text with any content at all is passed through untouched:
    /// paragraph breaks inside a note are the user's, not ours.
    static func normalizedNotes(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : text
    }

    private func save() {
        guard isLoaded, let loadedTicket else { return }
        var edited = EditableTicket(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: Self.normalizedNotes(notes),
            url: url,
            dueDate: dueDate,
            hasDueTime: hasDueTime,
            priority: priority,
            calendarID: calendarID)
        if edited.title.isEmpty {
            edited.title = loadedTicket.title
        }
        guard edited != loadedTicket else { return }
        // `loadedTicket` travels along as the baseline: it is what this sheet
        // was opened on, so the store can tell an edited field from one that
        // only looks unchanged, and leave the latter to whatever the live
        // reminder holds.
        store.updateTicket(
            cardID: card.id,
            edited: edited,
            baseline: loadedTicket,
            undoManager: undoManager)
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

/// A real `NSPopUpButton`, sized by this card rather than by its own contents.
///
/// SwiftUI's menu controls will not do that. A `Picker` sizes itself to its
/// widest *menu item* and ignores any width it is offered; a `Menu` with a
/// custom label throws that label away and renders its text with an indicator
/// of its own. Both leave the facts zone with as many control widths as it has
/// rows — a ragged edge facing the captions, and a block that does not read as
/// one thing. AppKit's own pop-up button takes a width and keeps it.
///
/// It is also the more faithful control: a pop-up button opens its menu *over*
/// itself with the current choice under the pointer, which is what this
/// platform does for a choice among a handful of values.
private struct FactPopUpButton: NSViewRepresentable {
    let titles: [String]
    let selectedIndex: Int
    let width: CGFloat
    let accessibilityLabel: String
    let onSelect: (Int) -> Void

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.font = .systemFont(ofSize: 13)
        button.target = context.coordinator
        button.action = #selector(Coordinator.didSelect(_:))
        button.setAccessibilityLabel(accessibilityLabel)
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.onSelect = onSelect
        button.setAccessibilityLabel(accessibilityLabel)
        if button.itemTitles != titles {
            button.removeAllItems()
            // One item at a time: `addItems(withTitles:)` silently drops a
            // repeated title, and two accounts may well each have a list
            // called "Erinnerungen".
            for title in titles {
                button.menu?.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
            }
        }
        if titles.indices.contains(selectedIndex), button.indexOfSelectedItem != selectedIndex {
            button.selectItem(at: selectedIndex)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject {
        var onSelect: (Int) -> Void

        init(onSelect: @escaping (Int) -> Void) {
            self.onSelect = onSelect
        }

        @objc func didSelect(_ sender: NSPopUpButton) {
            onSelect(sender.indexOfSelectedItem)
        }
    }
}

/// The wash that appears behind an editable field on hover.
///
/// Inset with negative padding rather than by growing the field: the field
/// keeps the exact frame the card's layout gave it, and the hint reaches a
/// little past the text on every side so it reads as a place to write rather
/// than a box drawn tight around the glyphs.
private extension View {
    func editableHint(_ isShowing: Bool, scheme: ColorScheme) -> some View {
        padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                Board.editableHoverShape
                    .fill(Board.editableHoverFill(scheme))
                    .opacity(isShowing ? 1 : 0)
            }
            .padding(.horizontal, -6)
            .padding(.vertical, -4)
    }
}

/// The opened card's two keyboard answers: Return keeps what is written,
/// Escape throws it away.
///
/// A local key monitor rather than SwiftUI's own `.onSubmit`,
/// `.onExitCommand` or a hidden `.keyboardShortcut(.cancelAction)` button.
/// All three are delivered through whatever holds first responder, and a
/// focused `NSTextField` is edited through the window's field editor, which
/// takes Escape for its own "abort editing" and passes nothing on: all three
/// were tried against this editor's earlier popover presentation and all
/// three failed there. A monitor does not ask the responder chain — it sees
/// the key event before the window is handed it at all, which is the one
/// place both keys are reachable whichever field, or no field at all (see
/// `FirstResponderNeutralizer`), has focus.
///
/// A monitor stood on that list of failures too, and the guard below is the
/// likeliest reason why: a popover is a window of its own, so key events
/// aimed at it never match the *board's* window. The editor is an overlay
/// inside the board's window now, and does match.
///
/// That guard is deliberately narrow, because a local monitor is otherwise
/// app-wide: only events aimed at this view's own window are touched, so the
/// date popover, an open picker menu and the settings window all keep their
/// own Return and Escape.
private struct EditorKeyCommands: NSViewRepresentable {
    /// False while the card has a popover of its own open.
    var isEnabled: Bool
    var onCommit: () -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MonitoringView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? MonitoringView else { return }
        apply(to: view)
    }

    private func apply(to view: MonitoringView) {
        view.isEnabled = isEnabled
        view.onCommit = onCommit
        view.onCancel = onCancel
    }

    final class MonitoringView: NSView {
        var isEnabled = true
        var onCommit: () -> Void = {}
        var onCancel: () -> Void = {}
        private var monitor: Any?
        /// Set the moment this card has been given its answer.
        ///
        /// A closed card takes a third of a second to animate off the board
        /// and is still in the window — this monitor with it — for all of it.
        /// Without this, a Return and an Escape typed fast one after the
        /// other would let the second overturn the first: the edit was
        /// already confirmed, and Escape would still throw it away, taking a
        /// just-created ticket with it. First answer wins.
        private var hasAnswered = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return removeMonitor() }
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handle(event)
            }
        }

        deinit { removeMonitor() }

        private func removeMonitor() {
            monitor.map(NSEvent.removeMonitor)
            monitor = nil
        }

        /// Returns nil to swallow the key, the event itself to let it travel
        /// on to whatever would normally receive it. Which of the two it is
        /// comes from `EditorKeyCommand`; this view only supplies the state
        /// that question needs and carries out the answer.
        private func handle(_ event: NSEvent) -> NSEvent? {
            guard isEnabled, !hasAnswered, let window, event.window === window else { return event }
            let command = EditorKeyCommand.forKey(
                code: event.keyCode,
                holdsCommand: event.modifierFlags.contains(.command),
                isEditingMultilineText: Self.isEditingMultilineText(in: window))
            switch command {
            case .commit:
                hasAnswered = true
                onCommit()
                return nil
            case .cancel:
                hasAnswered = true
                onCancel()
                return nil
            case .passThrough:
                return event
            }
        }

        /// True while the notes field has the cursor.
        ///
        /// A focused `TextField` is edited through the window's *field
        /// editor*, which is an `NSTextView` as well; `isFieldEditor` is what
        /// tells the one-line fields apart from the real multi-line one.
        private static func isEditingMultilineText(in window: NSWindow) -> Bool {
            guard let textView = window.firstResponder as? NSTextView else { return false }
            return !textView.isFieldEditor
        }
    }
}

/// A zero-size view whose only job is to take first responder away from
/// whatever AppKit assigned it by default, the moment its window has one.
/// `viewDidMoveToWindow` is not late enough by itself — the window can still
/// be in the middle of becoming key — so `didBecomeKeyNotification` backs it
/// up.
///
/// The keys are `EditorKeyCommands`' business, not this view's: a local
/// monitor sees them before the responder chain does, so nothing here can
/// take Return or Escape away. What is left is this view's actual job —
/// keeping a stray keystroke from landing in the title of a card that was
/// only opened to be read.
///
/// Targets `window.contentView` (the SwiftUI hosting view), not the window
/// itself. The hosting view is the neutral default this editor would already
/// have if AppKit didn't treat a freshly presented panel's first text field
/// as a special case; restoring that default is a smaller intervention than
/// parking responder status on the window, which took it out of the SwiftUI
/// hierarchy altogether and broke view-level key handling with it.
private struct FirstResponderNeutralizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NeutralizingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class NeutralizingView: NSView {
        private var observer: NSObjectProtocol?
        /// The neutralisation is a one-off, and this is what makes it one.
        ///
        /// The observer exists because the window may still be becoming key
        /// when this view lands, so the first attempt can come too early. It
        /// used to keep firing for as long as the editor was open, which made
        /// it something else entirely: every return from another app took the
        /// cursor out of whatever field was being typed in. Worse on a card
        /// the "+" had just made — the title claims focus 120 ms after
        /// opening, so one ⌘Tab away and back sent the next keystrokes
        /// nowhere, and closing then deleted the ticket as "empty".
        private var hasNeutralized = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observer.map(NotificationCenter.default.removeObserver)
            observer = nil
            hasNeutralized = false
            guard let window else { return }
            if window.isKeyWindow {
                window.makeFirstResponder(window.contentView)
                hasNeutralized = true
                return
            }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let self, !self.hasNeutralized else { return }
                self.hasNeutralized = true
                window?.makeFirstResponder(window?.contentView)
                self.observer.map(NotificationCenter.default.removeObserver)
                self.observer = nil
            }
        }

        deinit {
            observer.map(NotificationCenter.default.removeObserver)
        }
    }
}
