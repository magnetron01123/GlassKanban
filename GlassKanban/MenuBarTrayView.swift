import SwiftUI
import UniformTypeIdentifiers

/// The menu bar tray: three sections, one under the other — "Als Nächstes",
/// "In Bearbeitung", "Erledigt" — in the shape a menu bar panel has.
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
    /// Observed, not just read: the tray's own footer changes with it (see
    /// `MenuBarTray.offersQuit`), and the panel's hosting view is built once
    /// and then lives on — a plain read of the shared value showed the
    /// footer of whichever mode was current when the tray was first opened.
    @ObservedObject private var presence = PresenceController.shared

    /// The sections with rows, top to bottom, in board order. The Backlog
    /// stands above them as a head alone (`BacklogHead`) — planning belongs
    /// to the board.
    static let lanes: [KanbanStatus] = [.next, .inProgress, .done]

    var body: some View {
        // No background, no clip, no edge here: the panel's body is the
        // glass view this sits in (`TrayGlassController`), and the glass
        // brings its own corner, rim and shadow.
        content
            .frame(width: Board.trayWidth)
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
                .padding(Board.trayPadding * 2)
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
            // The flow starts here, so this is where the Backlog stands —
            // as a head with its number and nothing under it. Its rows live
            // on the board, and the head says so by taking you there.
            BacklogHead(
                count: store.cards(for: .backlog, applyingFilters: false).count,
                openBoard: { openBoard(nil) })
            ForEach(Self.lanes) { status in
                TraySection(status: status, openBoard: openBoard)
            }
            // No "Open Board" row: the Backlog head is the way to the board,
            // and every row opens it with its card. What is left down here
            // is Quit, and only where there is no Dock icon to quit from.
            if MenuBarTray.offersQuit(presence.selection) {
                VStack(alignment: .leading, spacing: 0) {
                    separator
                    TrayActionRow(title: String(localized: "Quit Glass Kanban")) { NSApp.terminate(nil) }
                }
            }
        }
        .padding(.top, Board.trayTopPadding)
        .padding(.bottom, Board.trayPadding)
        // The board's own reflow curve, so a row changing section moves at
        // the board's pace rather than at a second one.
        .animation(reduceMotion ? nil : Board.cardMoveAnimation, value: store.cards)
    }

    /// A menu's separator: a hairline, inset like the rows.
    private var separator: some View {
        Rectangle()
            .fill(Board.columnBorder(contrast))
            .frame(height: 1)
            .padding(.horizontal, Board.trayPadding + Board.trayRowInset)
            .padding(.bottom, Board.trayPadding / 2)
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
        .padding(Board.trayPadding * 2)
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
        if let board = NSApp.windows.first(where: { $0.identifier?.rawValue == "board" }) {
            board.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "board")
        }
        // Activated *after* the window is up, and with the modern call. The
        // tray's panel is non-activating, so in the menu bar mode the app is
        // never frontmost while the tray is open — and an
        // `activate(ignoringOtherApps:)` fired before the window existed was
        // simply dropped: the board appeared behind the previous app, with
        // no menu bar of its own and no keyboard focus (measured
        // 08.09.2026). Without the menu bar there is also no way into
        // Settings in that mode.
        NSApp.activate()
        // Only after the window is up: `editingCardID` is cleared by
        // `BoardView.closeEditor`, so a value set with no window to close it
        // would simply stay there.
        if let cardID {
            store.editingCardID = cardID
        }
    }

}

// MARK: - The Backlog, as a head

/// The first head in the tray, and the only one with nothing under it.
///
/// The Backlog is where the flow begins, so a number for it at the bottom
/// read as an afterthought — and a number the user could not act on
/// contradicted a panel in which everything else moves. Two ways out were
/// weighed on 11.09.2026 and set aside: showing the ripe rows behind a
/// disclosure (the pull chain complete in the panel, but the panel grows and
/// starts planning), and leaving the Backlog out entirely (the panel goes
/// quiet about where "Als Nächstes" is fed from). This is the third: the head
/// stands in its place in the flow, counts, and a click on it opens the board,
/// where the rows are. It lights up under the pointer so that it is
/// recognisably the one head that does something.
private struct BacklogHead: View {
    let count: Int
    let openBoard: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(KanbanStatus.backlog.displayName)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(count)")
                .monospacedDigit()
                .contentTransition(.numericText())
            // The one head that leads somewhere says so, with the system's
            // own sign for it. Without it, this head looked exactly like an
            // empty section's — and only the hover told them apart. It sits
            // in the slot every head keeps free, so the counts stay in line.
            Image(systemName: "chevron.right")
                .font(BoardText.glyph)
                .frame(width: Board.trayHeadTrailingSlot, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .font(BoardText.chip)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Board.trayRowInset)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background {
            if isHovered {
                Color.clear.glassEffect(.regular, in: Board.trayRowShape)
            }
        }
        .padding(.horizontal, Board.trayPadding)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: openBoard)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(KanbanStatus.backlog.displayName), \(String(localized: "\(count) cards"))")
        .accessibilityHint(Text("Open Board"))
    }
}

// MARK: - One section

/// One section of the tray: a head with the count, then rows. Also the drop
/// target for a row on its way here.
private struct TraySection: View {
    let status: KanbanStatus
    /// Handing a card — or nothing — over to the board.
    let openBoard: (String?) -> Void

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTargeted = false

    /// Unfiltered, always: the tray has no find control, no badge and no
    /// empty notice to explain why a card is missing (see
    /// `RemindersStore.cards(for:applyingFilters:)`).
    private var cards: [KanbanCard] {
        let all = store.cards(for: status, applyingFilters: false)
        // Erledigt takes the board's own seven-day window, newest first, so
        // the two hold the same cards.
        return status == .done ? DoneWindow.recent(all) : all
    }

    /// What is drawn. Beyond the cap the head counts on and a last row says
    /// how many are not here — a scroll area under a drag is trouble without
    /// a benefit.
    private var shownCards: [KanbanCard] { Array(cards.prefix(MenuBarTray.rowCap(for: status))) }
    private var hiddenRows: Int { MenuBarTray.hiddenRows(total: cards.count, in: status) }

    private var wipLimit: Int? { store.wipLimit(for: status) }
    private var isOverLimit: Bool { wipLimit.map { cards.count > $0 } ?? false }

    /// Every move route is off while a question of the tray's own stands.
    private var allowsMoves: Bool {
        MenuBarTray.allowsMoves(pendingSource: store.pendingOverflow?.source)
    }

    /// Only sections that would actually receive the row light up.
    private var isDragSource: Bool {
        guard let draggingID = store.draggingCardID else { return false }
        return cards.contains { $0.id == draggingID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(shownCards) { card in
                row(for: card)
            }
            if hiddenRows > 0 {
                moreRow
            }
            // Nothing under the head when there are no rows: an empty section
            // looks exactly like the Backlog head above it. The head itself is
            // the drop target then — the whole section takes the drop.
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
                store.endDrag()
                // No undo manager: the tray has no ⌘Z and no text focus, so a
                // registered entry would only be reachable from the board,
                // where it would be a surprise.
                _ = store.move(cardID: id, to: status, undoManager: nil, source: .tray)
            }))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(status.displayName), \(countHelp)")
    }

    /// Rows, with the three move routes the board offers — drag, the
    /// context menu, the VoiceOver action. "Die Frage stellt sich bei jeder
    /// Route" (SPEC.md, "WIP-Limits"), and a tray in which VoiceOver can move
    /// nothing is not this tray.
    @ViewBuilder
    private func row(for card: KanbanCard) -> some View {
        let movable = MenuBarTray.allowsMoving(from: card.status) && allowsMoves
        TrayRow(card: card)
            .contentShape(.dragPreview, Board.trayRowShape)
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

    /// The tray's own three sections — the Backlog is not a target here,
    /// because it is not shown and a card sent there would leave without a
    /// trace.
    private func moveTargets(for card: KanbanCard) -> [KanbanStatus] {
        MenuBarTrayView.lanes.filter { $0 != card.status }
    }

    private func move(_ card: KanbanCard, to target: KanbanStatus) {
        store.move(cardID: card.id, to: target, undoManager: nil, source: .tray)
    }

    /// The rows the cap keeps out, named in one quiet line. A click opens
    /// the board, where all of them are.
    private var moreRow: some View {
        TrayActionRow(title: String(localized: "\(hiddenRows) more"), quiet: true) { openBoard(nil) }
    }

    // MARK: - Head

    /// A menu's section head: the name and one number, both secondary. The
    /// number takes the board's teal capsule only while the section is over
    /// its limit — at rest it is plain text, which is all a head needs.
    private var header: some View {
        HStack(spacing: 8) {
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
            // The Backlog head's chevron slot, kept empty: one column of
            // counts across all four heads.
            Color.clear.frame(width: Board.trayHeadTrailingSlot, height: 1)
        }
        .font(BoardText.chip)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Board.trayRowInset)
        .padding(.top, 4)
        .padding(.bottom, 2)
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

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(CardParts.stripeColor(of: card).opacity(card.status == .done ? 0.45 : 0.9))
                .frame(width: Board.trayDotSize, height: Board.trayDotSize)
            // The strike as a text attribute, not the board's drawn line:
            // the drawn one exists so that completing can animate it, and
            // that reward plays on the board, where the finishing happened.
            CardParts.titleText(for: card)
                .strikethrough(card.status == .done, color: .secondary)
                .font(BoardText.trayRow)
                .lineLimit(1)
            Spacer(minLength: 8)
            // Only the dates that decide what to finish *now* — today and
            // overdue, the two that carry a tint. A grey "12. Sep" is
            // planning information, and planning happens on the board
            // (SPEC.md, "Menüleiste").
            if let badge = CardParts.compactBadge(for: card), badge.tint != nil {
                CardBadgeView(info: badge)
            }
        }
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

/// A row that does something rather than showing something — "Board öffnen",
/// "Glass Kanban beenden", "5 weitere". Same height and hover as a card row,
/// so the tray reads as one list.
private struct TrayActionRow: View {
    let title: String
    /// Secondary text for a row that is more a note than a command.
    var quiet = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Text(title)
            .font(BoardText.trayRow)
            .foregroundStyle(quiet ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .padding(.horizontal, Board.trayRowInset)
            .frame(height: Board.trayRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isHovered {
                    Color.clear.glassEffect(.regular, in: Board.trayRowShape)
                }
            }
            .padding(.horizontal, Board.trayPadding)
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
        HStack(spacing: 8) {
            Text(store.overflowTitle(for: overflow))
                .font(BoardText.trayRow)
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 8)
            // Real buttons, not plain text: these two *answer a question*,
            // and "die Frage stellen die Knöpfe" (CONCEPT.md, "Ton der
            // Texte") only holds if they read as something to press. The
            // safe answer prominent and first — Escape and Return do not
            // exist in a non-activating panel, so shape and position are
            // what carry it.
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
}

// MARK: - Dragging

/// `.draggable` only when the row may actually move — a lift that can never
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
