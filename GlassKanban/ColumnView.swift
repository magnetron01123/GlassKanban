import SwiftUI

struct ColumnView: View {
    let status: KanbanStatus

    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.undoManager) private var undoManager
    @State private var isTargeted = false
    @State private var expanded = false
    @State private var moreHovered = false
    @State private var addHovered = false
    /// Height of a real card in this lane, so the drop placeholder can match
    /// it exactly instead of guessing at a constant.
    @State private var cardHeight: CGFloat?

    private var cards: [KanbanCard] { store.cards(for: status) }
    private var singleLine: Bool { status.cardDensity.isSingleLine }

    /// The two stack lanes fold away what the resting board does not need:
    /// Backlog caps a huge pile at a count, Erledigt rests at the last week
    /// and brings back a month on request (see `DoneWindow`). Same gesture,
    /// different cut — one is "there is more of the same", the other is
    /// "there is a past".
    private var restingCards: [KanbanCard] {
        switch status {
        case .backlog where cards.count > Board.backlogCollapsedLimit:
            return Array(cards.prefix(Board.backlogCollapsedLimit))
        case .done:
            return DoneWindow.recent(cards)
        default:
            return cards
        }
    }

    private var displayedCards: [KanbanCard] { expanded ? cards : restingCards }

    /// How many cards the resting cut folds away right now — the number the
    /// footer offers to bring back, and the reason the footer exists at all.
    private var foldedCount: Int { cards.count - restingCards.count }

    /// True while a card from this very lane is being dragged. Dropping it
    /// back here changes nothing, so the lane must not promise a landing
    /// spot it will not honour.
    private var isDragSource: Bool {
        guard let draggingID = store.draggingCardID else { return false }
        return cards.contains { $0.id == draggingID }
    }

    /// Only lanes that would actually receive the card light up.
    private var showsDropFeedback: Bool { isTargeted && !isDragSource }

    /// The pull invitation lives in the *free slot*, not on a card: Kanban's
    /// answer to "what next" has always been the open space on the board, and
    /// putting it here means no single ticket gets singled out as the one to
    /// take. Shown only while there is actually something to pull.
    private var showsPullSlot: Bool {
        status == .inProgress
            && cards.isEmpty
            && !(store.cards(for: .next).isEmpty && store.cards(for: .backlog).isEmpty)
    }

    /// Completions done today, for the Erledigt header hint.
    private var todayCount: Int {
        let calendar = Calendar.current
        return cards.filter { $0.completionDate.map(calendar.isDateInToday) ?? false }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Hairline between header and cards, like a physical label strip.
            Rectangle()
                .fill(Board.columnBorder(contrast))
                .frame(height: 1)
                .padding(.horizontal, Board.laneMargin)

            ScrollView {
                LazyVStack(spacing: singleLine ? 5 : Board.cardSpacing) {
                    ForEach(displayedCards) { card in
                        // No custom drag preview: SwiftUI rasterizes preview
                        // closures into a bitmap, which turned rotation and
                        // material fills into a pixelated snapshot. The
                        // system's native lift preview renders the card
                        // itself crisply and adds its own depth; the
                        // drag-preview content shape rounds its corners so
                        // no rectangular snapshot edge shows behind them.
                        CardView(card: card)
                            .contentShape(.dragPreview, Board.cardShape)
                            .draggable(card.id)
                            // Runs alongside the system drag purely to note
                            // which card is moving. Deliberately additive:
                            // if it ever stops firing, dragging still works.
                            // Threshold 0 so it can never lag the system drag
                            // — at 6pt the source lane briefly treated the
                            // card as foreign and offered itself as a target.
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Threshold 0 keeps the gesture ahead
                                        // of the system drag, but it also fires
                                        // on plain mouse-down — which ghosted
                                        // the card to 40% on every single
                                        // click. The travel check restores the
                                        // distinction without giving the
                                        // threshold back: one pixel of movement
                                        // still comes long before the system
                                        // starts its own drag.
                                        guard value.translation != .zero else { return }
                                        store.beginDrag(cardID: card.id)
                                    }
                                    .onEnded { _ in store.endDrag() })
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                // One card is enough to size the placeholder.
                                if card.id == displayedCards.first?.id {
                                    cardHeight = height
                                    // The pull slot next door borrows this
                                    // measurement (see `nextTopCardHeight`).
                                    if status == .next { store.nextTopCardHeight = height }
                                }
                            }
                            // A card arriving in a lane settles into place
                            // instead of blinking on: it grows the last few
                            // percent into the shape this lane gives it.
                            // Erledigt and In Bearbeitung are the exceptions,
                            // both for the same reason: a card arriving there
                            // plays its own settle (the completion pen stroke,
                            // the pull shake-and-pop), and a second scale
                            // running underneath it made the arrival stutter —
                            // for the pull, the generic scale-in and the pop
                            // even pull in opposite directions and partly
                            // cancel.
                            .transition(.asymmetric(
                                insertion: status == .done || status == .inProgress
                                    ? .opacity
                                    : .scale(scale: 0.93).combined(with: .opacity),
                                removal: .opacity))
                    }

                    if status == .backlog {
                        addTicketButton
                    }

                    if showsDropFeedback {
                        insertionSlot
                    } else if showsPullSlot {
                        pullSlot
                    }
                }
                .padding(.horizontal, Board.laneMargin)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            // No scroll indicator inside the wells: the system's overlay bar
            // is the one element that would draw *above* the cards and break
            // the lane's depth model (recessed well, paper on top). The fade
            // below is the board's own "there is more" signal, and scrolling
            // itself is untouched.
            .scrollIndicators(.never)
            // "In Bearbeitung" alone gets headroom: the pull shake pops and
            // tilts the top card a few points past its own row, and the
            // scroll viewport clipped those corners flat right under the
            // header — the ticket slid *beneath* the lane's label in the one
            // moment it is the main event. Unclipped, the shaking card draws
            // over the hairline and header (the scroll view is the later
            // sibling), which is the correct depth: paper above chrome. The
            // other lanes keep their clip — with scrolling content, disabled
            // clipping would let scrolled-away cards peek out above the
            // viewport, and no other lane's settle ever leaves its row (the
            // pen stroke stays inside the card).
            .scrollClipDisabled(status == .inProgress)
            .mask {
                scrollFade.padding(
                    status == .inProgress
                        ? EdgeInsets(top: -Self.shakeHeadroom, leading: -Self.shakeHeadroom,
                                     bottom: 0, trailing: -Self.shakeHeadroom)
                        : EdgeInsets())
            }

            if foldedCount > 0 {
                moreButton
            }
        }
        .frame(
            minWidth: Board.columnMinWidth,
            maxWidth: Board.columnMaxWidth,
            maxHeight: .infinity,
            alignment: .top)
        .background { columnSurface }
        .overlay { columnContour }
        // Clicking the bare lane — not a card, not a control — is "outside"
        // for any inline edit open anywhere on the board: the usual pattern is
        // that an edit ends when you click away from it. Cards claim their own
        // taps first, so this only ever fires on empty space.
        .onTapGesture {
            store.activeEdit = nil
        }
        .animation(Board.dropTargetAnimation, value: showsDropFeedback)
        .dropDestination(for: String.self) { ids, _ in
            store.endDrag()
            guard let id = ids.first else { return false }
            // A drop destination has to answer synchronously, so the move
            // always goes through first and the WIP question — raised by the
            // store, for every move route — follows it. No haptic here: the
            // move itself answers the hand (see `MoveFeedback`, inside
            // `move`), and a second thud from the drop site on top of it
            // was a double knock for one landing.
            return store.move(cardID: id, to: status, undoManager: undoManager) != nil
        } isTargeted: { targeted in
            // No tick for the lane the card came from — nothing snaps there.
            if targeted && !isTargeted && !isDragSource { MoveFeedback.dragEnteredTarget() }
            isTargeted = targeted
        }
        // A lane that empties must forget its last card's height, or the
        // standing pull slot gets sized by whatever happened to be here last.
        .onChange(of: displayedCards.isEmpty) { _, isEmpty in
            if isEmpty {
                cardHeight = nil
                if status == .next { store.nextTopCardHeight = nil }
            }
        }
        // Without this a card announces its title and nothing about where it
        // is — on a board, the lane is half the meaning.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(status.displayName), \(countHelp)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // Secondary, and that is the hierarchy: the header once sat at
            // 13pt semibold in the primary colour, one point from the card
            // titles and in the same colour, so the label of a group competed
            // with the content inside it. Colour is what settled it. The
            // titles have since moved to 15pt (see `BoardText`), which widens
            // the gap as well — but the colour is still what carries it, and
            // is what the header must keep.
            Text(status.displayName)
                .font(BoardText.header)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            // A lane header states one number: how many cards are in it. The
            // Erledigt header also carried today's count ("7 · heute 2"),
            // which made the one piece of permanent chrome on every lane say
            // two different things. It survives in the tooltip and the
            // accessibility label — information without pixels.
            Text(countLabel)
                .font(BoardText.chip)
                .monospacedDigit()
                // Counts change one at a time; rolling the digit is how the
                // system animates a number that means something.
                .contentTransition(.numericText())
                // The middle weight of the board's badge scale: a tinted
                // backdrop, never tinted text. Teal on teal measured ~2:1 —
                // the capsule carries the colour, the label stays legible.
                // A solid fill would borrow the weight reserved for overdue;
                // being over capacity is worth noticing, not an emergency.
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
                .animation(.easeInOut(duration: 0.2), value: isOverLimit)
                // The over-limit signal is otherwise colour alone.
                .accessibilityValue(countHelp)
        }
        .padding(EdgeInsets(top: 12, leading: Board.laneMargin, bottom: 10, trailing: Board.laneMargin))
        // The whole header band, not just the count capsule. On the capsule
        // alone the tooltip was a 20pt target nobody found — including the
        // person who asked for it — which makes "explicit" true only on
        // paper. The header is the thing you point at when you wonder what
        // this lane is holding.
        .contentShape(Rectangle())
        .boardTooltip(countHelp)
    }

    private var wipLimit: Int? { store.wipLimit(for: status) }
    private var isOverLimit: Bool { wipLimit.map { cards.count > $0 } ?? false }

    /// What the capsule counts. Erledigt's membership is defined by its time
    /// window, so the capsule states what the lane shows and grows when the
    /// look back opens. Backlog's cap is a pure display crop — every card is
    /// genuinely in the lane — so its count stays the full pile.
    private var shownCount: Int {
        status == .done ? displayedCards.count : cards.count
    }

    /// The rule belongs on the board, not just in Settings ("make policies
    /// explicit"), so the limit rides along in the count itself.
    private var countLabel: String {
        if let wipLimit {
            return "\(cards.count) / \(wipLimit)"
        }
        return "\(shownCount)"
    }

    /// One shape for all four lanes: a lead line stating what the lane holds,
    /// then at most a couple of short qualifiers, one per line.
    ///
    /// They used to be four different sentences in three different builds —
    /// Erledigt opened with today's completions while the others opened with a
    /// count, two lanes folded a second fact in behind a "·" and a third used
    /// an em dash. The panel ranks lines, so a second fact belongs on a second
    /// line rather than trailing the first behind a separator.
    private var countHelp: String {
        ([countSummary] + countDetails).joined(separator: "\n")
    }

    /// Every lane opens the same way, so the four read as one family.
    private var countSummary: String {
        guard let wipLimit else { return "\(shownCount) Karten" }
        return "\(cards.count) von \(wipLimit) Karten"
    }

    private var countDetails: [String] {
        var details: [String] = []
        if status == .done, todayCount > 0 {
            details.append("\(todayCount) heute erledigt")
        }
        // Same reasoning as `recurringHint`: a lane that shows less than it
        // could must be able to say so. Once the look back is open, the one
        // thing still missing lives in the Reminders app — named here, at
        // the exact moment someone is digging for it.
        if status == .done {
            if !expanded, foldedCount > 0 {
                details.append("\(foldedCount) ältere Karten")
            } else if expanded {
                details.append("Älteres liegt in Erinnerungen")
            }
        }
        if isOverLimit {
            details.append("Limit überschritten")
        } else if wipLimit != nil {
            details.append("Lieber abschließen als stapeln")
        }
        if let recurringHint {
            details.append(recurringHint)
        }
        return details
    }

    /// What the count is leaving out. The capsule states what the lane shows,
    /// so the one rule that shows less than the lane holds has to be readable
    /// from the board — the same reason the WIP limit rides along in the
    /// count. Only ever present when it has something to report, so it costs
    /// nothing on a lane that is hiding nothing.
    private var recurringHint: String? {
        let hidden = store.recurringHiddenCount(for: status)
        guard hidden > 0 else { return nil }
        // "wiederkehrende" carries both numbers, so no singular branch needed.
        return "\(hidden) wiederkehrende Karten"
    }

    // MARK: - Pieces

    /// Dashed placeholder marking where the dragged card will land.
    private var insertionSlot: some View {
        Board.cardShape
            .strokeBorder(
                Color.accentColor.opacity(0.35),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .background(Color.accentColor.opacity(0.05), in: Board.cardShape)
            .frame(height: slotHeight)
            .transition(.opacity)
    }

    /// The resting counterpart to `insertionSlot`: same card-shaped outline,
    /// so "a card belongs here" reads identically whether or not something is
    /// being dragged. Neutral rather than accent-coloured — accent stays
    /// reserved for the live drop target — and completely static. It is a
    /// standing invitation, not an event, and the board spends motion only on
    /// things that just happened.
    private var pullSlot: some View {
        Board.cardShape
            .strokeBorder(
                Color.primary.opacity(0.25),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(height: pullSlotHeight)
            .overlay {
                // Names the payoff rather than the emptiness: this lane is not
                // "empty", it is the entrance to finishing. Shares its key word
                // with the WIP dialog ("Weniger gleichzeitig, mehr fertig") so
                // the board speaks about its principle in one vocabulary.
                Text("Fertig werden beginnt hier")
                    // Card scale, because this slot stands in for a card: at
                    // `body` it was a 12pt line adrift in a 118pt outline,
                    // reading as a caption for the empty space rather than as
                    // the ticket that belongs there. `titleCompact` is the
                    // card title's size one weight down — present enough to
                    // fill the slot it occupies, light and secondary enough to
                    // stay the ghost it is.
                    .font(BoardText.titleCompact)
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
    }

    /// Matches a real card in this lane; falls back to the lane's own card
    /// metrics while the lane is still empty.
    private var slotHeight: CGFloat {
        cardHeight ?? (singleLine ? Board.compactCardHeight : Board.fullCardMinHeight)
    }

    /// The pull slot's height: exactly the ticket it is inviting. The top
    /// card of "Als Nächstes" keeps its measured height when it lands here —
    /// both lanes render at full density — so the promised spot and the
    /// promised card are the same size, not "a card-ish rectangle" next to
    /// a visibly different real one. Falls back to the lane's own metrics
    /// while "Als Nächstes" has nothing measured.
    private var pullSlotHeight: CGFloat {
        store.nextTopCardHeight ?? slotHeight
    }

    /// Quick-add for Backlog. Sits right after the last card, like the "+" at
    /// the foot of a lane in familiar Kanban tools — but scaled to this
    /// board's quiet chrome instead of a standalone accent button.
    ///
    /// Creating IS editing: the "+" makes the ticket and lifts it straight
    /// into the card editor, where title, notes, date and everything else
    /// live in one place. The earlier bare title row could hold nothing but
    /// a name and made every other field a second trip. A creation abandoned
    /// without any input is removed again on close (see
    /// `RemindersStore.finalizeNewTicket`) — no untitled ghosts.
    private var addTicketButton: some View {
        HStack {
            Spacer()
            Button {
                guard let id = store.createTicketForEditing(undoManager: undoManager) else { return }
                withAnimation(reduceMotion ? nil : Board.cardOpenAnimation) {
                    store.editingCardID = id
                }
            } label: {
                Image(systemName: "plus")
                    // A touch larger than the toolbar's controls: this is the
                    // one creating gesture on the board, and at the foot of a
                    // lane it has to be found without hunting. Presence through
                    // size, not colour.
                    .font(.system(size: 16, weight: .semibold))
                    // Secondary, not a flat black glyph: on the earlier
                    // hand-built material the `.primary` plus sat on top of the
                    // glass instead of in it and read as pasted on. The native
                    // glass effect below composites the symbol into the surface
                    // with its own vibrancy, so a softer weight is all it needs.
                    .foregroundStyle(.secondary)
                    .frame(width: 35, height: 35)
                    .modifier(AddButtonGlass(reduceTransparency: reduceTransparency, contrast: contrast))
                    // On hover the button lifts exactly like a card — same
                    // -1pt rise, same shadow, same animation — so the board
                    // speaks one depth language: flat at rest beneath the
                    // paper, and anything you are about to pick up comes to
                    // the same height. Without this the cards rose on hover
                    // and the button stayed pinned, which read as broken.
                    .shadow(
                        color: Board.cardShadowHover.color.opacity(addHovered ? 1 : 0),
                        radius: Board.cardShadowHover.radius,
                        y: Board.cardShadowHover.y)
                    .offset(y: addHovered && !reduceMotion ? -1 : 0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : Board.hoverAnimation) { addHovered = hovering }
            }
            .accessibilityLabel("Neue Karte anlegen")
            .boardTooltip("Neue Karte anlegen")
            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// The fold line at the foot of a stack lane, and the way back out.
    ///
    /// A bare text line, not a plated button: the board's own rule is that
    /// glass belongs to the chrome and never to the content plane (see
    /// CONCEPT.md, Design-Anspruch) — the earlier `.glass` footer sat inside
    /// the recessed well as a raised plate and broke exactly that. At meta
    /// scale in secondary it reads as the lane's last, quiet line; hover
    /// lifts it to primary, which is all the affordance a link this local
    /// needs. The same line closes the fold again ("Ältere ausblenden"), so
    /// the way back sits precisely where the way in was.
    private var moreButton: some View {
        Button {
            // Folding 15+ cards in or out at once is the largest layout
            // change the board can make, and the one most worth gating on
            // Reduce Motion.
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            Text(moreLabel)
                .font(BoardText.meta)
                // One weight up from meta's regular: the only clickable line
                // at this scale, and it has to read as a link, not as the
                // passive metadata `meta` sets everywhere else.
                .fontWeight(.medium)
                .foregroundStyle(moreHovered ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { moreHovered = hovering }
        }
        .padding(.horizontal, Board.laneMargin)
        .padding(.bottom, 6)
    }

    /// "weitere" for Backlog (more of the same pile), "ältere" for Erledigt
    /// (a look into the past) — the word carries what the click will do.
    private var moreLabel: String {
        switch (status, expanded) {
        case (.done, false): "\(foldedCount) ältere anzeigen"
        case (.done, true): "Ältere ausblenden"
        case (_, false): "\(foldedCount) weitere anzeigen"
        case (_, true): "Weniger anzeigen"
        }
    }

    /// How far the shake may reach past the viewport before the mask cuts
    /// it: pop (+8% of a card) plus tilted corners (~4°) stay well inside.
    private static let shakeHeadroom: CGFloat = 20

    /// Cards fade out at the bottom edge, hinting there is more to scroll
    /// without a hard cut-off.
    private var scrollFade: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 14)
        }
    }

    // MARK: - Recessed lane surface

    private var columnSurface: some View {
        Board.columnShape
            .fill(columnFill)
            .overlay {
                // Accent wash while a drag hovers over the lane.
                Board.columnShape
                    .fill(Color.accentColor.opacity(showsDropFeedback ? 0.07 : 0))
            }
            .overlay {
                // Inner top shadow: the lane is carved into the board.
                Board.columnShape
                    .inset(by: 0.5)
                    .strokeBorder(
                        LinearGradient(colors: [Board.columnInnerShadow, .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 1.5)
                    .blur(radius: 1.5)
            }
            .allowsHitTesting(false)
    }

    private var columnContour: some View {
        Board.columnShape
            .strokeBorder(
                showsDropFeedback ? Color.accentColor.opacity(0.7) : Board.columnBorder(contrast),
                lineWidth: showsDropFeedback ? 1.5 : 1)
    }

    private var columnFill: Color {
        reduceTransparency
            ? Color(nsColor: .underPageBackgroundColor)
            : Board.columnFill(colorScheme)
    }
}

/// The circular glass surface behind the Backlog add button.
///
/// `HUDGlassMaterial`, not SwiftUI's native `.glassEffect`. The native effect
/// composites the "+" into the surface with more vibrancy, but it follows the
/// window's active state and offers no way to pin it: the moment the board
/// loses focus — which, on a second screen, is nearly always — the disc and
/// the glyph on it flatten and brighten, and this button became the one element
/// that receded while nothing around it did. Every other glass surface in the
/// app is already this same `HUDGlassMaterial` pinned to `state = .active`
/// (window back, tooltip, empty notice), so reusing it here keeps the button's
/// focused look whether or not the app is frontmost — the board's rule that no
/// element retreats just because the window is inactive (see CONCEPT.md,
/// "Immer-aktiv"). The trade is the native effect's press/hover vibrancy; the
/// hover lift on the button itself (a -1pt rise with a card shadow) carries the
/// press affordance instead. When "Transparenz reduzieren" is on it degrades to
/// the same solid disc the rest of the board uses in that mode.
private struct AddButtonGlass: ViewModifier {
    let reduceTransparency: Bool
    let contrast: ColorSchemeContrast

    func body(content: Content) -> some View {
        content
            .background(disc)
            .overlay { Circle().strokeBorder(Board.columnBorder(contrast), lineWidth: 1) }
    }

    @ViewBuilder
    private var disc: some View {
        if reduceTransparency {
            Circle().fill(Color(nsColor: .windowBackgroundColor))
        } else {
            HUDGlassMaterial().clipShape(.circle)
        }
    }
}
