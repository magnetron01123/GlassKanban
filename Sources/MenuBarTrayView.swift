import SwiftUI
import UniformTypeIdentifiers

/// The menu bar tray: four sections, one under the other — "Backlog", "Als
/// Nächstes", "In Bearbeitung", "Erledigt" — in the shape a menu bar panel has.
///
/// **Not a small board.** The first build (08.09.2026) put the board's three
/// lanes side by side with wells, paper cards and the empty lane's
/// invitation. Measured against the reason a menu bar item exists at all —
/// you open it to *finish something quickly* — that was the whole board,
/// shrunk. Retaken 11.09.2026 (user): the tray reminds of the board, but is
/// more abstract: sections and rows like a menu, one layer of glass, no
/// sentences. What stays is the point of it — a row is dragged from one
/// section into the next, through the same `move()` the board uses, with the
/// same limit question and the same sound.
struct MenuBarTrayView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    /// The panel's current height (see `TrayFit`).
    @ObservedObject private var fit = MenuBarTrayController.shared.fit

    /// The section a row is being dragged out of, so that section alone does
    /// not light up as a target for its own row. Kept here rather than in the
    /// store: `store.draggingCardID` also drives the board's 40 % ghost, and a
    /// drag in the panel must not ghost the card in the window behind it.
    @State private var liftedFrom: KanbanStatus?
    /// The row a move has just sent to another section, and from which side
    /// it arrives there (see `TraySection.transition(for:)`).
    @State private var arrival: TrayArrival?

    /// The four sections, top to bottom, in board order. The Backlog is one
    /// of them since 12.09.2026 (user): it folds shut by default and shows
    /// everything it holds when opened — earlier it stood as a head alone,
    /// and a head with only the capture line under it read as an empty
    /// section that happened to offer a "+".
    static let lanes: [KanbanStatus] = KanbanStatus.allCases

    /// Reminders' own icon, as installed — read once; the app does not change
    /// while the panel is open. `nil` only where Reminders is missing, and
    /// then the row still reads.
    /// This app's own icon, for the row that leads to its board.
    static let boardIcon: NSImage? = NSApp.applicationIconImage

    static let remindersIcon: NSImage? = {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders")
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }()


    var body: some View {
        // No background, no clip, no edge here: the panel's body is the
        // glass view this sits in (`TrayGlassController`), and the glass
        // brings its own corner, rim and shadow.
        // The panel grows downward with its content and never scrolls a
        // section in itself (12.09.2026, user). Only when the screen is too
        // short is the panel clamped to it — and then the whole panel
        // scrolls. The scroll view is always there so the clamped case needs
        // no second layout; with room enough it never moves.
        // One structure, always — never a scroll view in one case and bare
        // content in the other. The two branches were two identities: when an
        // unfold made the panel taller than the screen, the switch rebuilt
        // every section with its fold shut, the height fell back, the switch
        // went back, and the edge travelled into nothing (probe, 13.09.2026,
        // on a simulated 600 pt screen). Scrolling only happens once the
        // content really is taller than the panel (`.basedOnSize`), and the
        // scroller never shows: with `.hidden` the system's 16 pt scroller
        // still took its place during an unfold and pushed the content 8 pt
        // to the left; `.never` refuses it outright.
        //
        // The root is given the panel's own height, explicitly, on every
        // layout of the hosting view (`TrayFit.hostHeight`), and pins the
        // content to its top. `NSHostingView` centres a root that is smaller
        // than itself, and for the half second of a fold the rows *are*
        // smaller than the edge — a `Color.clear` filler did not stop it:
        // the head still dipped 7 pt and came back (measured 13.09.2026).
        // Before the first layout the height is unknown, and the root is as
        // tall as its content — which is exactly what the first measurement
        // asks.
        ScrollView(.vertical) { measured }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.never)
            .frame(width: Board.trayWidth, height: fit.hostHeight > 0 ? fit.hostHeight : nil, alignment: .top)
        // `store.start()` hangs on the board window's `.task`. In the menu
            // bar mode there is no window, so without this the tray would be
            // empty and would never have asked for access. `start()` is
            // idempotent (`hasStarted`), so calling it from both is safe.
            .task { await store.start() }
            // The item's menu asks for the board through here: this view is
            // the only place in the menu bar mode that holds `openWindow`.
            .onReceive(NotificationCenter.default.publisher(for: .glassKanbanOpenBoard)) { _ in
                openBoard(nil)
            }
            // And for Settings, for the same reason: `openSettings` is the
            // one way into a SwiftUI `Settings` scene that still works. The
            // selector AppKit used to install for it (`showSettingsWindow:`)
            // is accepted and then ignored — the menu item did nothing, twice,
            // on 13.09.2026.
            .onReceive(NotificationCenter.default.publisher(for: .glassKanbanOpenSettings)) { _ in
                openSettings()
            }
    }

    /// The content at its own width, reporting its own height — the height
    /// the panel wants. Measured here rather than trusted to the hosting
    /// controller: `preferredContentSize` did not move the window when a
    /// section folded shut (12.09.2026).
    private var measured: some View {
        content
            .frame(width: Board.trayWidth)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                MenuBarTrayController.shared.contentHeightChanged(height)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.accessState {
        case .granted:
            tray
        case .denied:
            deniedNotice
        case .unknown, .requesting:
            ProgressView("Accessing Reminders…")
                .padding(Board.trayNoticePadding)
                .frame(maxWidth: .infinity)
        }
    }

    private var tray: some View {
        // Groups are told apart by air, not by lines (see
        // `Board.trayGroupSpacing`). The one hairline left is the one before
        // Quit, which is not a group but a way out.
        VStack(alignment: .leading, spacing: Board.trayGroupSpacing) {
            // The limit question stands above everything, across the whole
            // tray — it *is* a question about the whole tray: while it
            // stands, no row in here moves.
            if let overflow = trayOverflow {
                OverflowQuestionRow(overflow: overflow)
            }
            // A write the panel asked for and EventKit refused. Here rather
            // than in the board's alert: the move was made here, and in the
            // menu bar mode there may be no board for an alert to appear over
            // (see `RemindersStore.SaveFailure.source`).
            if let failure = trayFailure {
                TrayNoticeRow(title: failure.title, message: failure.message) {
                    store.pendingSaveFailure = nil
                }
            }
            ForEach(Array(Self.lanes.enumerated()), id: \.element) { index, status in
                if index > 0 { separator }
                TraySection(status: status, openBoard: openBoard, liftedFrom: $liftedFrom, arrival: $arrival)
            }
            // The foot, the way the system's panels end: a hairline, then the
            // ways out. First the board itself: a row opens it *with* a card,
            // but in the menu bar mode the panel is the one thing on screen,
            // and a user who wants the board and not a card had no row to
            // click — the way to the app has to be visible, and it stands
            // above the way to Reminders (13.09.2026, user; reverses the
            // "no Open Board row" of 12.09.). Then Reminders, the store with
            // the search, subtasks and attachments this panel leaves out —
            // Bluetooth's "Bluetooth-Einstellungen …" is the pattern.
            VStack(alignment: .leading, spacing: 0) {
                separator
                TrayActionRow(title: String(localized: "Open Board"), icon: Self.boardIcon) {
                    openBoard(nil)
                }
                .padding(.horizontal, Board.trayPadding)
                TrayActionRow(title: String(localized: "Open Reminders"), icon: Self.remindersIcon) {
                    MenuBarTrayController.shared.close()
                    store.openRemindersApp()
                }
                .padding(.horizontal, Board.trayPadding)
                // No Quit here: the item's own menu has it, where every menu
                // bar item keeps it. A panel that could end the app read as
                // more than a panel (13.09.2026, user).
            }
        }
        .padding(.top, Board.trayTopPadding)
        .padding(.bottom, Board.trayPadding)
        // The board's own reflow curve, so a row changing section moves at
        // the board's pace rather than at a second one.
        .animation(reduceMotion ? nil : Board.cardMoveAnimation, value: store.cards)
    }

    /// A menu's separator: a hairline, inset like the rows, with the same
    /// air above and below.
    ///
    /// Groups were told apart by air alone until 12.09.2026 — a deliberate
    /// choice, and the wrong one here. Seen side by side: with two short
    /// sections above each other ("Als Nächstes 0 / 5", "In Bearbeitung
    /// 0 / 3") the air read as one block of four grey lines, and the heads
    /// are too quiet to carry the division on their own. The system's own
    /// menu bar panels draw the line; this is the closer answer, and the
    /// group spacing gives back what the line costs.
    private var separator: some View {
        Rectangle()
            .fill(Board.columnBorder(contrast))
            .frame(height: 1)
            .padding(.horizontal, Board.trayPadding + Board.trayRowInset)
    }

    /// A refusal the panel itself provoked. The board's own stay with the
    /// board's alert.
    private var trayFailure: RemindersStore.SaveFailure? {
        guard let failure = store.pendingSaveFailure, failure.source == .tray else { return nil }
        return failure
    }

    /// The tray's own limit question, if one is standing. The board's own
    /// stays with the board's alert.
    private var trayOverflow: RemindersStore.PendingOverflow? {
        guard let overflow = store.pendingOverflow, overflow.source == .tray else { return nil }
        return overflow
    }

    /// Without access the tray would be silently empty on the first launch.
    /// The same words the board uses, and the one way out it can offer from
    /// up here.
    private var deniedNotice: some View {
        VStack(spacing: 10) {
            Text("No Access to Reminders")
                .font(.headline)
            Text("Glass Kanban needs full access to your reminders to show the board. Allow access in System Settings under Privacy & Security → Reminders.")
                .font(BoardText.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(Board.trayNoticePadding)
        .frame(maxWidth: .infinity)
    }

    /// Hands over to the board: the tray closes first, then the window comes
    /// forward. The panel is ours, so it goes when we say — measured
    /// 08.09.2026 (M1): a `MenuBarExtra` popover stayed open beside the very
    /// window it had just opened.
    ///
    /// A board that was closed is still in `NSApp.windows` and only needs
    /// ordering front; in the menu bar mode at launch there may be none yet,
    /// and then the scene has to make one.
    private func openBoard(_ cardID: String?) {
        MenuBarTrayController.shared.close()
        var hadToCreateWindow = false
        if let board = NSApp.windows.first(where: { $0.identifier?.rawValue == "board" }) {
            board.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "board")
            hadToCreateWindow = true
        }
        // Activated *after* the window is up, and with the modern call. The
        // tray's panel is non-activating, so in the menu bar mode the app is
        // never frontmost while the tray is open — and an
        // `activate(ignoringOtherApps:)` fired before the window existed was
        // simply dropped: the board appeared behind the previous app, with
        // no menu bar of its own and no keyboard focus (measured
        // 08.09.2026). Without the menu bar there is also no way into
        // Settings in that mode.
        // `openWindow(id:)` does not put the window up before this line
        // returns, and an activation with no window of ours on screen is
        // dropped — measured 08.09.2026 and again 12.09.2026, when the item's
        // menu made the board appear behind Finder. One turn of the run loop
        // is enough for the scene to exist.
        if hadToCreateWindow {
            AppearanceDelegate.bringBoardForward()
        } else {
            NSApp.activate()
        }
        // Only after the window is up: `editingCardID` is cleared by
        // `BoardView.closeEditor`, so a value set with no window to close it
        // would simply stay there.
        if let cardID {
            store.editingCardID = cardID
        }
    }

}

// MARK: - Capture

/// The one place in the panel where something is written rather than moved.
///
/// **Why this exists here at all.** The board's own rule was "kein Anlegen im
/// Element" (05.09.2026) — a second creation surface beside the "+" would
/// have been the board twice. The panel is the other case: it is open in the
/// two seconds a thought lasts, and the way to the board is exactly the
/// distance in which the thought is lost. It captures a *title* and nothing
/// else, so it stays a capture and does not become a second editor
/// (BACKLOG.md, 12.09.2026).
///
/// Three states and no fourth: at rest a row like any other, in edit a field
/// in the same place, and after a refusal the same field with the reason
/// under it and the text still in it. Nothing survives the panel closing —
/// half a sentence that comes back days later is noise, not a draft.
private struct BacklogCaptureRow: View {
    @EnvironmentObject private var store: RemindersStore

    @State private var isEditing = false
    @State private var draft = ""
    /// Why the last save was refused, in the system's own words. Inline and
    /// not an alert: an alert takes the focus, and the panel would close over
    /// the title that was just typed.
    @State private var failure: String?
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            if let failure {
                Text(failure)
                    .font(BoardText.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Board.trayRowInset + Board.trayRowIndent + Board.trayRowGlyphSlot + Board.traySymbolGap)
                    .padding(.trailing, Board.trayRowInset)
                    .padding(.bottom, 4)
            }
        }
        // Every closing and opening leaves it at rest — the panel's view is
        // built once and then lives on, so without this a draft would outlive
        // its moment. Without animation: the reset is not an event the user
        // made, and it runs while the panel is being ordered out.
        .onReceive(NotificationCenter.default.publisher(for: .glassKanbanTrayResets)) { _ in
            var quiet = Transaction()
            quiet.disablesAnimations = true
            withTransaction(quiet) { rest() }
        }
    }

    private var row: some View {
        HStack(spacing: Board.traySymbolGap) {
            // In the rows' glyph field, where the other rows keep their
            // dot: this is a row, not a head.
            Image(systemName: "plus")
                .font(BoardText.chip)
                .frame(width: Board.trayRowGlyphSlot)
                .accessibilityHidden(true)
            if isEditing {
                TextField(String(localized: "New Task"), text: $draft)
                    .textFieldStyle(.plain)
                    .font(BoardText.trayRow)
                    .focused($isFocused)
                    .onSubmit(submit)
                    // Escape gives up the draft, as it does in every field
                    // this app has.
                    .onExitCommand(perform: rest)
                    .onChange(of: draft) { _, _ in failure = nil }
                    // Clicking anywhere else in the panel ends the capture.
                    // A field that keeps a blinking caret while the user is
                    // dragging rows around claims a focus it is not using.
                    .onChange(of: isFocused) { _, focused in
                        if !focused { rest() }
                    }
            } else {
                Text("New Task")
                    .font(BoardText.trayRow)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isEditing ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        // A row under the Backlog head, indented like every other row: what
        // is typed here falls into the section above.
        .padding(.leading, Board.trayRowIndent)
        .padding(.horizontal, Board.trayRowInset)
        .frame(height: Board.trayRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isHovered && !isEditing {
                Color.clear.glassEffect(.regular, in: Board.trayRowShape)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { beginEditing() }
        // A button at rest; in the editing state the field speaks for
        // itself. Left on unconditionally, the propagated trait made
        // VoiceOver announce the text field as a button — the same mistake
        // the card's rename field already paid for (see `CardView`).
        .accessibilityAddTraits(isEditing ? [] : .isButton)
        .accessibilityLabel(Text("New Task"))
    }

    private func beginEditing() {
        guard !isEditing else { return }
        draft = ""
        failure = nil
        isEditing = true
        isFocused = true
    }

    /// Return. With something in the field it is written and the field stays
    /// open for the next thought — several in a row is the normal case, not
    /// the exception. Empty, it is the way out.
    private func submit() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            rest()
            return
        }
        switch store.createTicket(title: title) {
        case .created:
            // No confirmation of its own: the number in the head above jumps
            // and the field is empty. That is the receipt, and it is where
            // the eye already is.
            draft = ""
            failure = nil
            isFocused = true
        case .empty:
            rest()
        case .failed(let reason):
            // The text stays exactly where it was — a refused save must not
            // also cost the sentence.
            failure = reason
            isFocused = true
        }
    }

    private func rest() {
        isEditing = false
        isFocused = false
        draft = ""
        failure = nil
    }
}

/// The stage as a glyph, in front of a head's name.
///
/// Secondary like the name it belongs to, and hidden from VoiceOver: the
/// name stands right beside it and says the same thing. The panel was
/// legible without these and still too abstract — four rows of grey text
/// with numbers, telling nothing apart at a glance (12.09.2026, user).
private struct TraySymbol: View {
    let status: KanbanStatus

    var body: some View {
        Image(systemName: status.traySymbolName)
            // The head's own size and weight: the glyph is a word in that
            // line, not a decoration beside it.
            .font(BoardText.header)
            .frame(width: Board.traySymbolSlot)
            .accessibilityHidden(true)
    }
}

// MARK: - One section

/// A row that a move has just sent into another section, and from which
/// side it arrives there.
struct TrayArrival: Equatable {
    let id: String
    let fromAbove: Bool
}

/// One section of the tray: a head with the count, then rows. Also the drop
/// target for a row on its way here.
private struct TraySection: View {
    let status: KanbanStatus
    /// Handing a card — or nothing — over to the board.
    let openBoard: (String?) -> Void
    /// Which section the row in flight came from (see `MenuBarTrayView`).
    @Binding var liftedFrom: KanbanStatus?
    /// The row on its way into a section, shared by all of them: the section
    /// that sends a row is never the one that receives it.
    @Binding var arrival: TrayArrival?

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTargeted = false
    /// Whether the fold under this section is open. Per session, as on the
    /// board: the panel opens at rest every time (see the notification
    /// below), the way the board launches folded.
    @State private var expanded = false

    /// Unfiltered, always: the tray has no find control, no badge and no
    /// empty notice to explain why a card is missing (see
    /// `RemindersStore.cards(for:applyingFilters:)`).
    private var cards: [KanbanCard] {
        let all = store.cards(for: status, applyingFilters: false)
        // Erledigt takes the board's own seven-day window, newest first, so
        // the two hold the same cards.
        return status == .done ? DoneWindow.recent(all) : all
    }

    /// At rest, by the board's rules at the panel's caps.
    private var restingCards: [KanbanCard] {
        MenuBarTray.restingRows(cards, in: status, foldsNotYetDue: store.foldNotYetDue)
    }
    private var shownCards: [KanbanCard] { expanded ? cards : restingCards }
    private var foldedCards: [KanbanCard] { Array(cards.dropFirst(restingCards.count)) }
    private var foldedCount: Int { foldedCards.count }

    private var wipLimit: Int? { store.wipLimit(for: status) }
    private var isOverLimit: Bool { wipLimit.map { cards.count > $0 } ?? false }

    /// Every move route is off while a question of the tray's own stands.
    private var allowsMoves: Bool {
        MenuBarTray.allowsMoves(pendingSource: store.pendingOverflow?.source)
    }

    /// Only sections that would actually receive the row light up. This read
    /// `store.draggingCardID` until 13.09.2026 — which the panel never sets,
    /// so the check was always false and a lifted row's own section lit up
    /// and ticked for a drop that does nothing.
    private var isDragSource: Bool { liftedFrom == status }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            // The capture first, right under the head: a fixed place to type
            // into from another app, whatever the length of the pile below.
            // The count above it is the receipt.
            if status == .backlog {
                BacklogCaptureRow()
            }
            rows
            if foldedCount > 0 {
                foldLine
            }
            // Nothing else under a head without rows: an empty section is its
            // head, and the head is the drop target then.
        }
        .onReceive(NotificationCenter.default.publisher(for: .glassKanbanTrayResets)) { _ in
            // Shut without the fold's own animation — see the capture row's
            // receiver for why a reset must not be seen to move.
            var quiet = Transaction()
            quiet.disablesAnimations = true
            withTransaction(quiet) {
                expanded = false
                // Also the backstop for a drag that ended nowhere.
                liftedFrom = nil
            }
        }
        .padding(.horizontal, Board.trayPadding)
        // The drop target is the whole section, tinted the way a menu row
        // lights up — not a dashed card outline, which was the board's.
        .background {
            if isTargeted && !isDragSource {
                // Glass on glass, as the system's own menus highlight: a
                // lighter layer, not a colour block. Admissible here because
                // the panel itself is native glass — on the board's pinned
                // HUD material this would be stacked blur.
                Color.clear
                    .glassEffect(.regular.tint(Color.accentColor.opacity(Board.trayDropTint)), in: Board.trayRowShape)
                    .padding(.horizontal, Board.trayPadding)
            }
        }
        .animation(reduceMotion ? nil : Board.dropTargetAnimation, value: isTargeted)
        // The same delegate shape the board uses: without one, macOS assumes
        // a copy and hangs its green "+" badge on the cursor for the whole
        // drag (see `ColumnView`).
        .onDrop(of: [.text], delegate: TrayDropDelegate(
            accepts: allowsMoves,
            entered: {
                if !isTargeted && !isDragSource { MoveFeedback.dragEnteredTarget() }
                isTargeted = true
            },
            exited: { isTargeted = false },
            perform: { id in
                if let source = liftedFrom { noteArrival(of: id, from: source) }
                liftedFrom = nil
                // No undo manager: the tray has no ⌘Z and no text focus, so a
                // registered entry would only be reachable from the board,
                // where it would be a surprise.
                _ = store.move(cardID: id, to: status, undoManager: nil, source: .tray)
            }))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(status.displayName), \(countHelp)")
    }

    /// The rows: what rests, or everything once the line under the pile has
    /// been opened. The panel grows with them (see `MenuBarTrayView.body`).
    private var rows: some View {
        // Decided once for the section, not once per row: one row with a
        // dwell time or a date gives every row the column for it
        // (`Board.trayDwellColumn`, `trayDueColumn`), so all titles end on
        // one line.
        let shown = shownCards
        let dwell = shown.contains { MenuBarTray.showsDwellTime(status: $0.status, days: $0.daysInColumn()) }
        let due = shown.contains { MenuBarTray.showsDueDate($0) }
        return ForEach(shown) { card in
            row(for: card, reservesDwellColumn: dwell, reservesDueColumn: due)
        }
    }

    /// The board's line under the pile, word for word (see
    /// `ColumnView.moreLabel`): "noch nicht fällig" when the fold is purely
    /// a later, "weitere" when the pile is merely long, "ältere" for
    /// Erledigt. Bare text, a chevron that turns, hover lifts it to primary
    /// and nothing else — what tells it apart from a ticket is what it lacks:
    /// no dot in the glyph field, no glass under the pointer.
    private var foldLine: some View {
        TrayFoldLine(label: foldLabel, expanded: expanded) {
            // The board's own fold, curve and duration: the rows slide as
            // the board's cards do, and the panel's bottom edge travels with
            // them on the same curve (`MenuBarTrayController.foldStarted`) —
            // one motion, downward. The edge is told how far, not asked to
            // measure: the rows are fixed-height, so the travel is exactly
            // the folded rows' height and is known before layout, where the
            // content's own report still answers with the old height.
            let travel = CGFloat(foldedCount) * Board.trayRowHeight * (expanded ? -1 : 1)
            // Driven exactly as `ColumnView.fold` drives the board's: an
            // explicit `withAnimation` on the shared curve, none under
            // Reduce Motion. Recognition is the point — the same gesture
            // must look the same in both places (13.09.2026, user).
            if reduceMotion {
                expanded.toggle()
            } else {
                withAnimation(Board.foldAnimation) { expanded.toggle() }
            }
            NotificationCenter.default.post(
                name: .glassKanbanTrayFolds, object: nil, userInfo: ["travel": travel])
        }
    }

    private var foldLabel: String {
        switch (status, expanded) {
        case (.done, false): String(localized: "Show \(foldedCount) older")
        case (.done, true): String(localized: "Hide older")
        case (_, false) where BacklogFold.canNameNotYetDue(folded: foldedCards):
            String(localized: "\(foldedCount) not yet due")
        case (_, false): String(localized: "Show \(foldedCount) more")
        case (_, true): String(localized: "Show less")
        }
    }

    /// Rows, with the three move routes the board offers — drag, the
    /// context menu, the VoiceOver action. "Die Frage stellt sich bei jeder
    /// Route" (SPEC.md, "WIP-Limits"), and a tray in which VoiceOver can move
    /// nothing is not this tray.
    @ViewBuilder
    private func row(for card: KanbanCard, reservesDwellColumn: Bool, reservesDueColumn: Bool) -> some View {
        let movable = MenuBarTray.allowsMoving(from: card.status) && allowsMoves
        TrayRow(card: card, reservesDwellColumn: reservesDwellColumn, reservesDueColumn: reservesDueColumn)
            .transition(transition(for: card))
            .contentShape(.dragPreview, Board.trayRowShape)
            .onTapGesture { openBoard(card.id) }
            .modifier(TrayDraggable(
                card: card, enabled: movable,
                lifted: { liftedFrom = status },
                ended: { liftedFrom = nil }))
            .contextMenu {
                // The board's menu, in the board's order. "Edit" is what a
                // tap on the row does, named — a menu that says less than
                // the one on the board makes the row look like it can do
                // less (13.09.2026). "Open in Reminders" on every row,
                // Erledigt included: the one thing a finished card still has
                // to say is what it was, and everything the board's editor
                // leaves out (recurrence, subtasks, attachments) lives there.
                Button("Edit") { openBoard(card.id) }
                Button("Open in Reminders") { openInReminders(card) }
                if movable {
                    Divider()
                    Menu("Move to") {
                        ForEach(moveTargets(for: card)) { target in
                            Button(target.displayName) { move(card, to: target) }
                        }
                    }
                }
            }
            .accessibilityActions {
                Button("Edit") { openBoard(card.id) }
                Button("Open in Reminders") { openInReminders(card) }
                if movable {
                    ForEach(moveTargets(for: card)) { target in
                        Button("Move to \(target.displayName)") { move(card, to: target) }
                    }
                }
            }
    }

    /// Every other section, the Backlog included: a card put back there
    /// lands in a count that is on screen, and in the rows behind the fold.
    private func moveTargets(for card: KanbanCard) -> [KanbanStatus] {
        MenuBarTrayView.lanes.filter { $0 != card.status }
    }

    private func move(_ card: KanbanCard, to target: KanbanStatus) {
        noteArrival(of: card.id, from: card.status, to: target)
        store.move(cardID: card.id, to: target, undoManager: nil, source: .tray)
    }

    /// Remembers, for the length of one move animation, which row is about
    /// to appear in another section and from which side. Set before the
    /// move so the row's first render already carries the right transition;
    /// cleared afterwards so a later fold shows the row the board's way.
    private func noteArrival(of id: String, from source: KanbanStatus, to target: KanbanStatus? = nil) {
        let arrival = TrayArrival(
            id: id, fromAbove: MenuBarTray.arrivesFromAbove(from: source, to: target ?? status))
        self.arrival = arrival
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.arrival == arrival { self.arrival = nil }
        }
    }

    /// The board's own transition for a card the fold reveals or hides
    /// (`ColumnView`, `isFolding`): a fade, no scale. A row that has just
    /// been *moved* here also fades, and travels the few points that say
    /// which way it came — down the panel for a move forward (14.09.2026,
    /// user: the panel's flow runs top to bottom, and should say so quietly,
    /// in the moment of the move rather than in a standing mark). Under
    /// Reduce Motion the root's animation is off, so the row simply appears.
    private func transition(for card: KanbanCard) -> AnyTransition {
        guard let arrival, arrival.id == card.id else { return .opacity }
        let travel = arrival.fromAbove ? -Board.trayFlowOffset : Board.trayFlowOffset
        return .opacity.combined(with: .offset(y: travel))
    }

    /// The panel closes first, then Reminders comes forward — the same order
    /// every hand-over here follows (see `MenuBarTrayView.openBoard`). Left
    /// standing, the panel would hang over the app it just opened until the
    /// next click somewhere else.
    private func openInReminders(_ card: KanbanCard) {
        MenuBarTrayController.shared.close()
        store.openInReminders(cardID: card.id)
    }

    // MARK: - Head

    /// A menu's section head: the name and one number, both secondary. The
    /// number takes the board's teal capsule only while the section is over
    /// its limit — at rest it is plain text, which is all a head needs.
    private var header: some View {
        HStack(spacing: Board.traySymbolGap) {
            TraySymbol(status: status)
            Text(status.displayName)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(countLabel)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(isOverLimit ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .padding(.horizontal, isOverLimit ? 6 : 0)
                .padding(.vertical, isOverLimit ? 1 : 0)
                .background {
                    if isOverLimit {
                        Board.chipShape.fill(Board.wipLimitTint.opacity(Board.wipCapsuleFill))
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isOverLimit)
                .accessibilityValue(countHelp)
        }
        // The board's own lane-head type, and the size the system's panels
        // give their heads: Bluetooth's and Screen Mirroring's titles are 13
        // pt bold over 13 pt rows (measured 13.09.2026). At 11 pt — an
        // `NSMenu` section header's size — the heads read as footnotes to
        // their rows (user, same day).
        .font(BoardText.header)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Board.trayRowInset)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }

    /// The count always tells the whole truth, even where a row is not drawn.
    private var countLabel: String {
        if let wipLimit { return "\(cards.count) / \(wipLimit)" }
        return "\(cards.count)"
    }

    /// Spoken with the section, since the number alone carries the rule.
    private var countHelp: String {
        var lines: [String] = []
        if let wipLimit {
            lines.append(String(localized: "\(cards.count) of \(wipLimit) cards"))
            lines.append(String(localized: isOverLimit ? "Over your limit" : "Finish before you stack"))
        } else {
            lines.append(String(localized: "\(cards.count) cards"))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - One row

/// A menu row: a dot in the list's colour, the title, and the due date if
/// there is one. Nothing of the board's card — no paper, no stripe, no
/// shadow, no repeat glyph. The dot is the one piece of context a quick
/// glance uses; the date is the one fact that decides what to finish first.
private struct TrayRow: View {
    let card: KanbanCard
    /// Whether the section keeps each trailing column open on this row even
    /// if it has nothing of its own to put there (see `TraySection.rows`).
    let reservesDwellColumn: Bool
    let reservesDueColumn: Bool

    @State private var isHovered = false

    private var dwellLabel: String? {
        guard let days = card.daysInColumn(),
              MenuBarTray.showsDwellTime(status: card.status, days: days) else { return nil }
        return String(localized: "\(days) days")
    }

    private var dueBadge: CardParts.BadgeInfo? {
        guard MenuBarTray.showsDueDate(card) else { return nil }
        return CardParts.compactBadge(for: card)
    }

    private var dueStyle: AnyShapeStyle {
        guard let dueBadge else { return AnyShapeStyle(.secondary) }
        return dueBadge.isEmphasized ? AnyShapeStyle(Board.overdueText) : AnyShapeStyle(.primary)
    }

    var body: some View {
        HStack(spacing: Board.traySymbolGap) {
            // Under the head's name, not under its symbol: the row is the
            // head's child, and the indent is what says so.
            Circle()
                .fill(CardParts.stripeColor(of: card).opacity(card.status == .done ? 0.45 : 0.9))
                .frame(width: Board.trayDotSize, height: Board.trayDotSize)
                .frame(width: Board.trayRowGlyphSlot)
            // The strike as a text attribute, not the board's drawn line:
            // the drawn one exists so that completing can animate it, and
            // that reward plays on the board, where the finishing happened.
            CardParts.titleText(for: card)
                .strikethrough(card.status == .done, color: .secondary)
                .font(BoardText.trayRow)
                .lineLimit(1)
            Spacer(minLength: 8)
            // The trailing facts, each in its column. An empty label still
            // holds the column open, so the titles of a section end on one
            // line (see `TraySection.rows`); `minWidth` rather than `width`,
            // so a label wider than measured pushes the title instead of
            // losing its own last letters.
            // How long this one has been open, and only where that is a
            // question (see `MenuBarTray.showsDwellTime`). No clock glyph:
            // the board's full card has one because it has room for it, and
            // in a menu row the bare number is quieter and just as clear.
            if reservesDwellColumn {
                Text(dwellLabel ?? "")
                    .font(BoardText.meta)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: Board.trayDwellColumn, alignment: .trailing)
            }
            // Only the dates that decide what to finish *now* (see
            // `MenuBarTray.showsDueDate`). As text, not the board's capsule:
            // in a menu the extra fact stands as plain text at the right
            // (Time Machine's "Heute, 08:36"), and Reminders itself writes
            // an overdue date as red text. The capsule was the loudest thing
            // in the panel — three of them stacked read as a standing charge
            // (13.09.2026, user). The board's three weights survive as text
            // colours: red for overdue, primary for today, and the dwell
            // time beside them stays secondary — orange as 11 pt text fails
            // contrast (see `CardBadgeView`), so today lifts by weight of
            // colour, not by hue.
            if reservesDueColumn {
                Text(dueBadge?.label ?? "")
                    .font(BoardText.meta)
                    .monospacedDigit()
                    .foregroundStyle(dueStyle)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: Board.trayDueColumn, alignment: .trailing)
            }
        }
        .padding(.leading, Board.trayRowIndent)
        .padding(.horizontal, Board.trayRowInset)
        .frame(height: Board.trayRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A menu's hover: a lighter layer of the same glass under the
        // pointer, nothing more.
        .background {
            if isHovered {
                Color.clear.glassEffect(.regular, in: Board.trayRowShape)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        // Deliberately not a `Button` and not `.focusable()`: rows take no
        // keyboard focus, on the board or here (BACKLOG.md, "Explizit
        // abgelehnt").
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(CardParts.accessibilityLabel(for: card))
        .accessibilityHint(Text("Click to edit"))
    }
}

/// The board's fold line, in the panel: `ColumnView.moreButton` at menu
/// size. Bare text one weight up, a chevron that turns, secondary until the
/// pointer lifts it — no glass, because glass is what a *row* does under the
/// pointer, and this is the one line that is not one. In the rows' column
/// rather than centred as on the board, with the chevron in the glyph field
/// like the capture's plus: in a panel where every line starts at the left,
/// a centred one read as misplaced (12.09.2026, user).
///
/// One view through both states, unlike the board's two: the board swaps
/// the line so it dissolves instead of racing down the lane, but here the
/// pointer is usually still on the line when it swaps, and the new view
/// never received the hover's end — it stayed lifted and read as bold.
private struct TrayFoldLine: View {
    let label: String
    let expanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Board.traySymbolGap) {
            // The chevron where a row keeps its dot and the capture its
            // plus: the glyph field names the kind of line, and this one
            // is the fold. Trailing, it stood alone at the end of a short
            // label and read as misaligned against "Neue Aufgabe"
            // (12.09.2026, user).
            Image(systemName: "chevron.down")
                .font(BoardText.glyph)
                .rotationEffect(.degrees(expanded ? -180 : 0))
                .frame(width: Board.trayRowGlyphSlot)
                // The label says it; the glyph would be an unnamed stop.
                .accessibilityHidden(true)
            Text(label)
                .font(BoardText.trayRow)
                .fontWeight(.medium)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(isHovered ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .padding(.leading, Board.trayRowIndent)
        .padding(.horizontal, Board.trayRowInset)
        .frame(height: Board.trayRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture(perform: action)
        // One element, like every row: without it the button trait fell on
        // each child, and VoiceOver read an unnamed button beside the label.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A row that does something rather than showing something — "Board öffnen",
/// "Glass Kanban beenden", "5 weitere". Same height and hover as a card row,
/// so the tray reads as one list.
private struct TrayActionRow: View {
    let title: String
    /// An app's icon in front of the title — the one glyph a menu row draws
    /// at full colour, as the Finder's "Open With" and Spotlight do, so the
    /// row says at a glance which app it leads to.
    var icon: NSImage? = nil
    /// Secondary text for a row that is more a note than a command.
    var quiet = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        // The heads' geometry, not the rows': the foot is a way out of the
        // panel, a line of its own rank, and Apple's panels start their
        // footer at the text margin. The icon takes the field the stage
        // symbols keep, so the panel has two glyph columns and no third.
        HStack(spacing: Board.traySymbolGap) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: Board.trayAppIconSize, height: Board.trayAppIconSize)
                } else {
                    Color.clear
                }
            }
            .frame(width: Board.traySymbolSlot)
            .accessibilityHidden(true)
            Text(title)
                .font(BoardText.trayRow)
                .foregroundStyle(quiet ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(1)
        }
            .padding(.horizontal, Board.trayRowInset)
            .frame(height: Board.trayRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isHovered {
                    Color.clear.glassEffect(.regular, in: Board.trayRowShape)
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - The limit question

/// The WIP question, inline.
///
/// Not an `.alert`: an alert takes the focus, and the tray's panel would
/// close out from under its own question. It stands at the top until it is
/// answered — closing the tray does not answer it, in either direction.
/// "Karte springt zurück" is the pattern this project has paid the most for.
private struct OverflowQuestionRow: View {
    let overflow: RemindersStore.PendingOverflow

    @EnvironmentObject private var store: RemindersStore

    var body: some View {
        // One line when it fits, two when it does not. In German it usually
        // does not: "Erst abschließen" and "Passt schon" beside the question
        // left 45 pt too few in a 340 pt panel, and SwiftUI took them out of
        // the lane name and the ratio — the very numbers the question is
        // about (review, 12.09.2026).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                question
                Spacer(minLength: 8)
                answers
            }
            VStack(alignment: .leading, spacing: 6) {
                question
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    answers
                }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, Board.trayRowInset)
        .padding(.vertical, 6)
        // Teal, because the question is about the limit and teal is the
        // limit's colour on the board — the one tint in the tray, and only
        // while there is something to answer.
        .background { Board.trayRowShape.fill(Board.wipLimitTint.opacity(Board.trayDropTint)) }
        .padding(.horizontal, Board.trayPadding)
        .accessibilityElement(children: .contain)
    }

    private var question: some View {
        Text(store.overflowTitle(for: overflow))
            .font(BoardText.trayRow)
            .monospacedDigit()
            .lineLimit(1)
    }

    /// Real buttons, not plain text: these two *answer a question*, and "die
    /// Frage stellen die Knöpfe" (CONCEPT.md, "Ton der Texte") only holds if
    /// they read as something to press. The safe answer prominent and first —
    /// Return does not reach these buttons in the panel, and Escape closes
    /// the panel rather than answering (the question stays), so shape and
    /// position are what carry it.
    private var answers: some View {
        HStack(spacing: 8) {
            Button("Finish First") {
                store.move(
                    cardID: overflow.cardID, to: overflow.origin,
                    undoManager: nil, feedback: false)
                store.pendingOverflow = nil
            }
            .buttonStyle(.borderedProminent)
            Button("That's Fine") { store.pendingOverflow = nil }
                .buttonStyle(.bordered)
        }
    }
}

/// What did not happen, and why, without an alert.
///
/// An alert would take the focus and close the panel out from under its own
/// news — the same reason the WIP question is a row here (see
/// `OverflowQuestionRow`). It states the refusal and stays until it is
/// clicked away: a failure nobody read is a move that vanished silently, and
/// that is the failure mode this project has paid the most for.
private struct TrayNoticeRow: View {
    let title: String
    let message: String
    let dismiss: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(BoardText.trayRow)
                .fontWeight(.medium)
            Text(message)
                .font(BoardText.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Board.trayRowInset)
        .padding(.vertical, 6)
        // The board's own colour for a refused write, at the tint the panel
        // uses for everything that is not a row.
        .background { Board.trayRowShape.fill(Color.red.opacity(Board.trayDropTint)) }
        .overlay {
            if isHovered {
                Board.trayRowShape.strokeBorder(Color.primary.opacity(0.12))
            }
        }
        .padding(.horizontal, Board.trayPadding)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        // Both halves are already localized by the store; this only joins
        // them, so it must not be looked up as a key of its own.
        .accessibilityLabel(Text(verbatim: "\(title). \(message)"))
        .accessibilityHint(Text("Click to dismiss"))
    }
}

// MARK: - Dragging

/// `.draggable` only when the row may actually move — a lift that can never
/// land is a promise the tray does not keep.
///
/// The tray deliberately does not call `store.beginDrag`: without the ghost,
/// a drag that ends nowhere leaves no half state behind (SPEC.md, "Was das
/// Board gegen sich selbst absichert"). It reports the lift to its own state
/// instead, with the board's gesture (`ColumnView`): threshold 0 so it stays
/// ahead of the system drag, and a travel check so a plain click is no lift.
private struct TrayDraggable: ViewModifier {
    let card: KanbanCard
    let enabled: Bool
    let lifted: () -> Void
    let ended: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            // With an explicit preview. The default one is a snapshot of
            // the row — and the row's text is vibrant text *in* the glass,
            // which renders as nothing once it is lifted out of it: the
            // user dragged a bare coloured dot across the screen (seen
            // 12.09.2026). The preview below is drawn plain, on a solid
            // ground, with an ordinary label colour.
            content
                .draggable(card.id) { TrayDragPreview(card: card) }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard value.translation != .zero else { return }
                            lifted()
                        }
                        .onEnded { _ in ended() })
        } else {
            content
        }
    }
}

/// What travels under the pointer: the row again, but on paper of its own —
/// nothing vibrant, nothing that needs a material behind it to be visible.
private struct TrayDragPreview: View {
    let card: KanbanCard

    var body: some View {
        HStack(spacing: Board.traySymbolGap) {
            Circle()
                .fill(CardParts.stripeColor(of: card).opacity(0.9))
                .frame(width: Board.trayDotSize, height: Board.trayDotSize)
                .frame(width: Board.trayRowGlyphSlot)
            CardParts.titleText(for: card)
                .font(BoardText.trayRow)
                .lineLimit(1)
        }
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(.horizontal, Board.trayRowInset)
        .frame(height: Board.trayRowHeight)
        .frame(maxWidth: Board.trayWidth - 2 * Board.trayPadding, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .background(Board.trayRowShape.fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(Board.trayRowShape.strokeBorder(Color(nsColor: .separatorColor)))
    }
}

private struct TrayDropDelegate: DropDelegate {
    let accepts: Bool
    let entered: () -> Void
    let exited: () -> Void
    let perform: (String) -> Void

    func validateDrop(info: DropInfo) -> Bool { accepts && info.hasItemsConforming(to: [.text]) }
    func dropEntered(info: DropInfo) { if accepts { entered() } }
    func dropExited(info: DropInfo) { exited() }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: accepts ? .move : .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        // macOS sends no exit after a landing; the highlight must not stick.
        exited()
        guard accepts,
              let provider = info.itemProviders(for: [.text]).first,
              provider.canLoadObject(ofClass: NSString.self) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let id = object as? String else { return }
            DispatchQueue.main.async { perform(id) }
        }
        return true
    }
}
