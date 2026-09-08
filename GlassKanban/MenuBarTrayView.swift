import SwiftUI
import UniformTypeIdentifiers

/// The menu bar tray: the board's three lanes after the Backlog, in one row,
/// in board order — "Als Nächstes" · "In Bearbeitung" · "Erledigt".
///
/// **As close to the board as it can be** (see SPEC.md, "Menüleiste"): the
/// same tokens, the same strings, the same rules, the same `move()`. Where it
/// differs it is for room or for technique, and each of those is named where
/// it happens.
struct MenuBarTrayView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    /// The lanes the tray shows, left to right. Backlog is a number in the
    /// footer — planning belongs to the board.
    static let lanes: [KanbanStatus] = [.next, .inProgress, .done]

    var body: some View {
        // The lane heads carry the board's own tooltip, and that needs a host
        // to draw into — the same wrapper `BoardView` puts around its lanes.
        TooltipHost { content }
            .frame(width: Board.trayWidth)
            .background { trayBackground }
            // `store.start()` hangs on the board window's `.task`. In the menu
            // bar mode there is no window, so without this the tray would be
            // empty and would never have asked for access. `start()` is
            // idempotent (`hasStarted`), so calling it from both is safe.
            .task { await store.start() }
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
                .padding(Board.trayPadding)
                .frame(maxWidth: .infinity)
        }
    }

    private var tray: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: Board.trayLaneSpacing) {
                ForEach(Self.lanes) { status in
                    TrayLane(status: status, rows: laneRows, openBoard: openBoard)
                }
            }
            footer
        }
        .padding(Board.trayPadding)
        // The board's own reflow curve, so a card changing lane in the tray
        // moves at the board's pace rather than at a second one.
        .animation(reduceMotion ? nil : Board.cardMoveAnimation, value: store.cards)
    }

    /// All three wells share one height — see `MenuBarTray.laneRows`.
    private var laneRows: Int {
        MenuBarTray.laneRows(
            next: store.cards(for: .next, applyingFilters: false).count,
            inProgress: store.cards(for: .inProgress, applyingFilters: false).count,
            done: DoneWindow.recent(store.cards(for: .done, applyingFilters: false)).count)
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
        .padding(Board.trayPadding)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            // The smallest form of "make the work visible": one number for
            // the one lane the tray does not show. It counts; it does not
            // accuse. No full stop — this is a figure, not a sentence.
            Text("Backlog · \(store.cards(for: .backlog, applyingFilters: false).count)")
                .monospacedDigit()
            Spacer(minLength: 0)
            Button("Open Board") { openBoard(nil) }
                .buttonStyle(.plain)
            if MenuBarTray.offersQuit(PresenceController.shared.selection) {
                Button("Quit Glass Kanban") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
            }
        }
        .font(BoardText.meta)
        .foregroundStyle(.secondary)
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
        NSApp.activate(ignoringOtherApps: true)
        if let board = NSApp.windows.first(where: { $0.identifier?.rawValue == "board" }) {
            board.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "board")
        }
        // Only after the window is up: `editingCardID` is cleared by
        // `BoardView.closeEditor`, so a value set with no window to close it
        // would simply stay there.
        if let cardID {
            store.editingCardID = cardID
        }
    }

    /// The tray is chrome, so glass is right here — the same material the
    /// window wears, for the same reason (`HUDGlassMaterial`). With
    /// "Transparenz reduzieren" on it takes the same opaque stand-in the
    /// window does (see `ContentView.windowBackground`).
    @ViewBuilder
    private var trayBackground: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            HUDGlassMaterial()
        }
    }
}

// MARK: - One lane

/// One well of the tray. Head, hairline, rows — the board's lane, at the
/// tray's size.
private struct TrayLane: View {
    let status: KanbanStatus
    /// Rows every well is tall, so all three match (see `MenuBarTray.laneRows`).
    let rows: Int
    /// Handing a card — or nothing — over to the board.
    let openBoard: (String?) -> Void

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTargeted = false

    /// Unfiltered, always: the tray has no find control, no badge and no
    /// empty notice to explain why a card is missing (see
    /// `RemindersStore.cards(for:applyingFilters:)`).
    private var cards: [KanbanCard] {
        let all = store.cards(for: status, applyingFilters: false)
        // Erledigt takes the board's own seven-day window, newest first, so
        // the two lanes hold the same cards.
        return status == .done ? DoneWindow.recent(all) : all
    }

    /// What is drawn. Beyond the cap the chip counts on without the row being
    /// shown — a deliberate exception to "a dragged card stays visible where
    /// it lands" (SPEC.md), because a scroll area under a drag is trouble
    /// without a benefit.
    private var shownCards: [KanbanCard] { Array(cards.prefix(MenuBarTray.rowCap)) }

    private var wipLimit: Int? { store.wipLimit(for: status) }
    private var isOverLimit: Bool { wipLimit.map { cards.count > $0 } ?? false }

    /// The tray's own limit question, if one is standing.
    private var trayOverflow: RemindersStore.PendingOverflow? {
        guard let overflow = store.pendingOverflow, overflow.source == .tray,
              overflow.status == status else { return nil }
        return overflow
    }

    /// Every move route is off while a question of the tray's own stands.
    private var allowsMoves: Bool {
        MenuBarTray.allowsMoves(pendingSource: store.pendingOverflow?.source)
    }

    private var showsEmptySlot: Bool {
        guard cards.isEmpty, trayOverflow == nil else { return false }
        // The board's rule, shared rather than rebuilt.
        return status.invitesWhenEmpty(
            nextIsEmpty: store.cards(for: .next, applyingFilters: false).isEmpty,
            backlogIsEmpty: store.cards(for: .backlog, applyingFilters: false).isEmpty)
    }

    /// Only lanes that would actually receive the card light up.
    private var isDragSource: Bool {
        guard let draggingID = store.draggingCardID else { return false }
        return cards.contains { $0.id == draggingID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Board.columnBorder(contrast))
                .frame(height: 1)
                .padding(.horizontal, Board.laneMargin)

            VStack(spacing: Board.trayRowSpacing) {
                if let trayOverflow {
                    OverflowQuestionRow(overflow: trayOverflow)
                }
                ForEach(shownCards) { card in
                    row(for: card)
                }
                if isTargeted && !isDragSource {
                    insertionSlot
                } else if showsEmptySlot {
                    emptySlot
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Board.laneMargin)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(height: contentHeight, alignment: .top)
            // Rows beyond the cap must not draw past the well they belong to.
            .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background { Board.columnShape.fill(Board.columnFill(colorScheme)) }
        .overlay {
            Board.columnShape
                .strokeBorder(Board.columnBorder(contrast))
                .shadow(color: Board.columnInnerShadow(colorScheme), radius: 2, y: 1)
                .clipShape(Board.columnShape)
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
                store.endDrag()
                // No undo manager: the tray has no ⌘Z and no text focus, so a
                // registered entry would only be reachable from the board,
                // where it would be a surprise.
                _ = store.move(cardID: id, to: status, undoManager: nil, source: .tray)
            }))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(status.displayName), \(countHelp)")
    }

    /// Card rows, with the three move routes the board offers — drag, the
    /// context menu, the VoiceOver action. "Die Frage stellt sich bei jeder
    /// Route" (SPEC.md, "WIP-Limits"), and a tray in which VoiceOver can move
    /// nothing is not this tray.
    @ViewBuilder
    private func row(for card: KanbanCard) -> some View {
        let movable = MenuBarTray.allowsMoving(from: card.status) && allowsMoves
        TrayCardView(card: card)
            .contentShape(.dragPreview, Board.cardShape)
            .onTapGesture { openBoard(card.id) }
            .modifier(TrayDraggable(cardID: card.id, enabled: movable))
            .contextMenu {
                if movable {
                    Menu("Move to") {
                        ForEach(moveTargets(for: card)) { target in
                            Button(target.displayName) { move(card, to: target) }
                        }
                    }
                }
            }
            .accessibilityActions {
                if movable {
                    ForEach(moveTargets(for: card)) { target in
                        Button("Move to \(target.displayName)") { move(card, to: target) }
                    }
                }
            }
    }

    /// The tray's own three lanes — the Backlog is not a target here, because
    /// it is not shown and a card sent there would leave without a trace.
    private func moveTargets(for card: KanbanCard) -> [KanbanStatus] {
        MenuBarTrayView.lanes.filter { $0 != card.status }
    }

    private func move(_ card: KanbanCard, to target: KanbanStatus) {
        store.move(cardID: card.id, to: target, undoManager: nil, source: .tray)
    }

    // MARK: - Head

    /// Word for word the board's lane header (`ColumnView.header`): the name
    /// in secondary, one count chip, teal when the lane is over its limit.
    /// One head, one number — no second "Limit N" chip and no "done today".
    private var header: some View {
        HStack(spacing: 8) {
            Text(status.displayName)
                .font(BoardText.header)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(countLabel)
                .font(BoardText.chip)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(isOverLimit ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background {
                    if isOverLimit {
                        Board.chipShape.fill(Board.wipLimitTint.opacity(Board.wipCapsuleFill))
                    } else {
                        Board.chipShape.fill(.quaternary.opacity(Board.chipFill))
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isOverLimit)
                .accessibilityValue(countHelp)
        }
        .padding(EdgeInsets(top: 12, leading: Board.laneMargin, bottom: 10, trailing: Board.laneMargin))
        // A lane header is chrome, and chrome tooltips explain rules —
        // "make policies explicit" holds up here too.
        .contentShape(Rectangle())
        .boardTooltip(countHelp)
    }

    /// The chip always tells the whole truth, even where a row is not drawn.
    private var countLabel: String {
        if let wipLimit { return "\(cards.count) / \(wipLimit)" }
        return "\(cards.count)"
    }

    private var countHelp: String {
        var lines = [countSummary]
        if isOverLimit {
            lines.append(String(localized: "Over your limit"))
        } else if wipLimit != nil {
            lines.append(String(localized: "Finish before you stack"))
        }
        if cards.count > shownCards.count {
            lines.append(String(localized: "\(cards.count - shownCards.count) more not shown here"))
        }
        return lines.joined(separator: "\n")
    }

    private var countSummary: String {
        guard let wipLimit else { return String(localized: "\(cards.count) cards") }
        return String(localized: "\(cards.count) of \(wipLimit) cards")
    }

    // MARK: - Slots

    private var insertionSlot: some View {
        Board.cardShape
            .strokeBorder(
                Color.accentColor.opacity(0.35),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .background(Color.accentColor.opacity(0.05), in: Board.cardShape)
            .frame(height: Board.compactCardHeight)
            .transition(.opacity)
    }

    /// The board's standing invitation, at row height. Same outline, same
    /// sentences (`ColumnView.emptySlotText`), same stillness — it is an
    /// invitation, not an event.
    private var emptySlot: some View {
        Board.cardShape
            .strokeBorder(
                Color.primary.opacity(0.25),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(height: Board.compactCardHeight)
            .overlay {
                Text(emptySlotText)
                    .font(BoardText.titleCompact)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    // The one place the tray may not simply copy the board.
                    // A well is ~200pt wide against a lane's 280, and
                    // "Fertigwerden beginnt hier" came out as "Fertigwerden
                    // begin…" — a truncated invitation is noise, not a
                    // signal. Widening the tray to fit it would have taken
                    // ~800pt, which is a second window, not a tray. Shrinking
                    // only as far as a line needs keeps the sentence whole
                    // and leaves the board's own slot untouched at 15pt.
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 12)
            }
            .transition(.opacity)
    }

    private var emptySlotText: String {
        switch status {
        case .backlog: String(localized: "Get it out of your head")
        case .next: String(localized: "Choose, don't collect")
        case .inProgress: String(localized: "Finishing starts here")
        case .done: String(localized: "Only finished counts")
        }
    }

    /// The height every well shares: `rows` card rows and the air between
    /// them, plus the padding above and below.
    private var contentHeight: CGFloat {
        let rowsHeight = CGFloat(rows) * Board.compactCardHeight
            + CGFloat(max(0, rows - 1)) * Board.trayRowSpacing
        return rowsHeight + 10 + 12
    }
}

// MARK: - The limit question, in the well

/// The WIP question, inline.
///
/// Not an `.alert`: an alert takes the focus, and the tray's panel would
/// close out from under its own question. It stands in the well above the
/// cards until it is answered — closing the tray does not answer it, in
/// either direction. "Karte springt zurück" is the pattern this project has
/// paid the most for.
private struct OverflowQuestionRow: View {
    let overflow: RemindersStore.PendingOverflow

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Text(store.overflowTitle(for: overflow))
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 0)
            // The safe answer stands first — Escape and Return do not exist
            // in a non-activating panel, so position is what carries it.
            Button("Finish First") {
                store.move(
                    cardID: overflow.cardID, to: overflow.origin,
                    undoManager: nil, feedback: false)
                store.pendingOverflow = nil
            }
            Button("That's Fine") { store.pendingOverflow = nil }
        }
        .font(BoardText.meta)
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .frame(height: Board.compactCardHeight)
        .background { Board.wellShape.fill(Board.wellFill(colorScheme)) }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - One card

/// A tray row. The board's anatomy at compact height — priority marks,
/// title, date badge, repeat glyph, list stripe (see `CardParts`) — and
/// nothing else: no rename, no editor, no delete, no tooltip, no settle.
private struct TrayCardView: View {
    let card: KanbanCard

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if card.status == .done {
                doneBody
            } else {
                compactBody
            }
        }
        .background { Board.cardShape.fill(Board.cardFill(colorScheme, isDone: card.status == .done)) }
        .overlay(alignment: .leading) { CardListStripe(card: card, isSingleLine: true) }
        .overlay { Board.cardShape.strokeBorder(Board.cardBorder(contrast)) }
        .overlay { topHighlight }
        .shadow(
            color: Board.cardShadowResting.color,
            radius: Board.cardShadowResting.radius,
            y: Board.cardShadowResting.y)
        .shadow(
            color: card.status == .done ? .clear : Board.cardShadowAmbient.color,
            radius: Board.cardShadowAmbient.radius,
            y: Board.cardShadowAmbient.y)
        .contentShape(Board.cardShape)
        // Deliberately not a `Button` and not `.focusable()`: cards take no
        // keyboard focus, on the board or here (BACKLOG.md, "Explizit
        // abgelehnt").
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(CardParts.accessibilityLabel(for: card))
        .accessibilityHint(Text("Click to edit"))
    }

    /// Backlog's row, word for word (`CardView.compactBody`): badge before
    /// glyph, the same order the full card's footer uses.
    private var compactBody: some View {
        HStack(spacing: 8) {
            CardParts.titleText(for: card)
                .font(BoardText.titleCompact)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge = CardParts.compactBadge(for: card) {
                CardBadgeView(info: badge)
            }
            if card.isRecurring {
                CardRepeatIcon()
            }
        }
        .padding(EdgeInsets(top: 9, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
        .frame(maxWidth: .infinity, minHeight: Board.compactCardHeight, maxHeight: Board.compactCardHeight, alignment: .leading)
    }

    /// Erledigt's row: the title alone, in full text colour — the strike is
    /// the signal (SPEC.md, "Karten-Anzeige"). Static, without the pen
    /// stroke: that sweep is the board's reward for finishing, and it plays
    /// where the finishing happened.
    private var doneBody: some View {
        CardParts.titleText(for: card)
            .font(BoardText.titleCompact)
            .lineLimit(1)
            .overlay(alignment: .leading) { CardStrikeLine() }
            .padding(EdgeInsets(top: 9, leading: Board.cardInsetLeading, bottom: 9, trailing: Board.cardInsetTrailing))
            .frame(maxWidth: .infinity, minHeight: Board.compactCardHeight, maxHeight: Board.compactCardHeight, alignment: .leading)
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
}

// MARK: - Dragging

/// `.draggable` only when the card may actually move — a lift that can never
/// land is a promise the tray does not keep.
///
/// The tray deliberately does not call `store.beginDrag`: without the ghost,
/// a drag that ends nowhere leaves no half state behind (SPEC.md, "Was das
/// Board gegen sich selbst absichert").
private struct TrayDraggable: ViewModifier {
    let cardID: String
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.draggable(cardID)
        } else {
            content
        }
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
