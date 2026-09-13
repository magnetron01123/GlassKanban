import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox

/// The menu bar item and the panel it opens.
///
/// **Why this is AppKit and not a `MenuBarExtra` scene.** Measured 08.09.2026
/// (plans/menubar-tablett.md, M1): in a `MenuBarExtra` popover with style
/// `.window` a drag *lifts* — the preview follows the cursor and the popover
/// stays open — but the drop never arrives: neither `isTargeted` nor the
/// drop closure fires. The same synthetic drag on the board moves a card
/// between lanes, so it is the popover, not the measurement. A tray whose
/// cards cannot be dragged is not this tray, so the item and its window are
/// built by hand. In a panel of our own the same drag lands (measured the
/// same day).
///
/// The second measurement pushed the same way: `openWindow(id:)` plus
/// `NSApp.activate` brought the board up and left the popover standing open
/// beside it. There is no API to close a `.window` popover; a panel we own
/// closes when we say so.
@MainActor
final class MenuBarTrayController: NSObject {
    static let shared = MenuBarTrayController()

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var escapeMonitor: Any?
    private var keyLossObserver: NSObjectProtocol?
    private var cancellables: Set<AnyCancellable> = []
    private var visibilityObservation: NSKeyValueObservation?
    /// True while this controller is setting `isVisible` itself, so the
    /// observation can tell its own write from the user's ⌘-drag.
    private var isApplyingVisibility = false
    private weak var store: RemindersStore?

    /// Called once from the app delegate. The store comes from there rather
    /// than from a scene: in the menu bar mode there is no window, so nothing
    /// in the SwiftUI hierarchy is alive to hand it over.
    func start(store: RemindersStore) {
        self.store = store
        // The shortcut does exactly what a click on the item does, so it is
        // the same call and not a second path into the panel.
        GlobalHotkey.shared.action = { [weak self] in self?.toggle() }
        TrayShortcutController.shared.applyStored()
        PresenceController.shared.$selection
            .receive(on: RunLoop.main)
            .sink { [weak self] presence in self?.apply(presence) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .glassKanbanTrayFolds)
            .sink { [weak self] note in
                guard let travel = note.userInfo?["travel"] as? CGFloat else { return }
                self?.foldStarted(travel: travel)
            }
            .store(in: &cancellables)
        apply(PresenceController.shared.selection)
    }

    private func apply(_ presence: AppPresence) {
        if presence.showsMenuBarItem {
            installStatusItem()
        } else {
            removeStatusItem()
        }
        // No item, no panel — and then no shortcut either.
        GlobalHotkey.shared.set(enabled: presence.showsMenuBarItem)
    }

    // MARK: - The item

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // The gesture macOS offers on every status item: ⌘-drag it off the
        // bar. Allowed here — but never silently, see the observation below.
        item.behavior = .removalAllowed
        if let button = item.button {
            button.image = Self.boardGlyph
            button.target = self
            button.action = #selector(handleClick)
            // Right-click has to arrive as an event of its own; without this
            // the button only ever reports a left click.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        // macOS remembers a ⌘-drag removal for a `.removalAllowed` item and
        // restores `isVisible = false` on the next launch, under a key of its
        // own that this app never sees. Without this line the item stayed
        // away for good: the app came up, found its item hidden, and the
        // observation below immediately wrote the setting to "Dock" — so the
        // user's choice of "Menüleiste" was silently overwritten by a gesture
        // they had made once, and only a trip through Settings brought it
        // back (seen 12.09.2026). The setting is the authority; if it says
        // there is an item, there is one.
        isApplyingVisibility = true
        item.isVisible = true
        isApplyingVisibility = false
        // ⌘-dragging the item off the bar only sets `isVisible` — the app
        // itself would keep running with no Dock icon and no item, reachable
        // by nothing the user has. The setting follows the gesture instead.
        visibilityObservation = item.observe(\.isVisible, options: [.new]) { [weak self] _, change in
            guard change.newValue == false else { return }
            Task { @MainActor in
                // Not our own write — only the user's gesture changes the
                // setting.
                guard self?.isApplyingVisibility != true else { return }
                let presence = PresenceController.shared.selection
                PresenceController.shared.selection = presence.afterMenuBarItemRemoved
            }
        }
        statusItem = item
    }

    private func removeStatusItem() {
        close()
        visibilityObservation = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    // MARK: - The panel

    /// Left opens the panel, right opens the menu — the two gestures every
    /// menu bar item on this system offers.
    @objc private func handleClick() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            showMenu()
        } else {
            toggle()
        }
    }

    /// The item's own menu.
    ///
    /// Three entries and no more: the way to the board, the way to the
    /// settings, and the way out. Every one of them is a route the panel
    /// itself cannot always offer — the panel needs Reminders access to draw
    /// anything at all, and in the menu bar mode there is no Dock icon and no
    /// app menu, so without this an app that had been refused access was
    /// running with no way to quit it and no way into its settings
    /// (12.09.2026). Nothing about the board's *content* belongs here: that
    /// is what the panel is for.
    private func showMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false

        let board = NSMenuItem(
            title: String(localized: "Open Board"),
            action: #selector(openBoardFromMenu), keyEquivalent: "")
        board.keyEquivalentModifierMask = []
        board.target = self
        menu.addItem(board)

        let settings = NSMenuItem(
            title: String(localized: "Settings…"),
            action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settings.keyEquivalentModifierMask = []
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: String(localized: "Quit Glass Kanban"),
            // No key equivalents anywhere in this menu: in the menu bar mode
            // the app has no menu bar of its own, so a printed ⌘Q would be a
            // shortcut that does nothing.
            action: #selector(quitFromMenu), keyEquivalent: "")
        // Cleared explicitly: an item with an empty key equivalent still
        // carries ⌘ in its modifier mask, and AppKit draws a placeholder
        // glyph for it — a mark in the menu that means nothing.
        quit.keyEquivalentModifierMask = []
        quit.target = self
        menu.addItem(quit)

        // The panel and the menu must not stand at once — they hang from the
        // same item.
        close()
        // Handed to the item rather than popped up by hand, so macOS places
        // it under the item and highlights the item while it is open. Taken
        // away again immediately: while an item carries a menu, a left click
        // opens that menu instead of reaching the action.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    @objc private func openBoardFromMenu() {
        openBoard()
    }

    /// Brings the board up, creating it if this launch never had one.
    ///
    /// `AppearanceDelegate.showBoardWindow` can only order an existing window
    /// front, and in the menu bar mode the scene is suppressed at launch — so
    /// on a run where the board was never opened there is no window to order.
    /// Only SwiftUI can make one, through `openWindow(id:)`, which lives in
    /// the panel's view; the panel is loaded first so that the view is alive
    /// to hear the request even if the user has never opened it.
    private func openBoard() {
        if NSApp.windows.contains(where: { $0.identifier?.rawValue == "board" }) {
            AppearanceDelegate.showBoardWindow()
            NSApp.activate()
            return
        }
        loadPanelIfNeeded()
        NotificationCenter.default.post(name: .glassKanbanOpenBoard, object: nil)
    }

    /// Builds the panel and lays it out once, without showing it — enough for
    /// SwiftUI to instantiate the view hierarchy behind it.
    private func loadPanelIfNeeded() {
        guard panel == nil, let store else { return }
        let panel = makePanel(store: store)
        self.panel = panel
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
    }

    @objc private func openSettingsFromMenu() {
        // Only Settings, not the board with it: the user asked for one
        // window. Active first, or the window opens behind whatever is in
        // front — this app does not own the menu bar while it is clicked.
        loadPanelIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .glassKanbanOpenSettings, object: nil)
    }

    @objc func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            open()
        }
    }

    /// Where the tray hangs from, taken at the click and kept for the
    /// panel's lifetime on screen: a resize repositions against *this*, not
    /// against wherever the pointer has wandered to since.
    private var anchor: TrayAnchor?

    private func open() {
        guard let store else { return }
        let panel = self.panel ?? makePanel(store: store)
        self.panel = panel
        anchor = TrayAnchor.atClick(statusItem: statusItem)
        // Back to rest *before* the content is measured, so the height read
        // below is the resting one. Posted after the measurement, as it was,
        // a panel closed with a section unfolded reopened at the tall height
        // and then folded shut in front of the user (review, 12.09.2026). The
        // same reset runs in `close()`; this one is the backstop.
        NotificationCenter.default.post(name: .glassKanbanTrayResets, object: nil)
        // Lay the content out *before* placing the panel. Positioned first,
        // the panel still had its placeholder height, hung too low, and then
        // jumped into place once SwiftUI had measured — the "strange
        // positioning" of the first build (11.09.2026).
        if let glass = panel.contentViewController as? TrayGlassController {
            // The content's own report wins. The measurement below only
            // exists to make the content lay out and report before the
            // panel is shown: its return value is the scroll view's, which
            // answers a zero proposal with zero — the panel opened 10 pt tall
            // (13.09.2026). The report it triggers is the real height.
            let measured = naturalHeight == nil ? glass.naturalContentHeight : 0
            let natural = naturalHeight ?? measured
            let target = clamped(natural)
            panel.setContentSize(NSSize(width: Board.trayWidth, height: target))
        }
        position(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        // And once more on the next turn: a report that arrived while the
        // panel was not yet visible was stored but not applied, and nothing
        // reports again until the content changes.
        DispatchQueue.main.async { [weak self] in
            guard let self, let natural = self.naturalHeight else { return }
            self.contentHeightChanged(natural)
        }
        // The shadow is cached against whatever outline the window had
        // before its first display; redone once the glass has drawn.
        DispatchQueue.main.async { panel.invalidateShadow() }
        startWatchingForClicksOutside()
    }

    /// The content reports its own height (see `MenuBarTrayView.body`); the
    /// panel takes it while it is on screen. The resize notification in
    /// `makePanel` then keeps the top edge under the menu bar.
    func contentHeightChanged(_ height: CGFloat) {
        guard height > 0 else { return }
        naturalHeight = height
        guard let panel, panel.isVisible else { return }
        let target = clamped(height)
        guard abs(panel.contentView!.frame.height - target) > 0.5 else { return }
        if isClosing { stopTravel() }
        // While a fold is travelling, `foldStarted` owns the frame; the
        // content's report (which arrives once, near the end of the rows'
        // animation — measured 13.09.2026, not per frame) is reconciled when
        // the travel ends. Everything else — a row changing section, a
        // notice appearing, the reset on closing — sets the height in one
        // step, as a menu would.
        guard !isTravelling else { return }
        var frame = panel.frame
        // The top edge stays under the menu bar; the bottom edge is what
        // moves (`position(_:)` holds the same rule on every resize).
        frame.origin.y = frame.maxY - target
        frame.size.height = target
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    /// A section has just begun to fold on `Board.foldAnimation`, by
    /// `travel` points. The edge goes with it — same curve, same half
    /// second, started in the same turn — driven by hand, one whole-point
    /// frame per display refresh. Not `animator()`: AppKit's own window
    /// animation raced the content's report to a 131 pt jump and a creep
    /// (13.09.2026). One writer of the frame for the duration; the
    /// content's report is applied afterwards only if the two disagree.
    func foldStarted(travel: CGFloat) {
        guard let panel, panel.isVisible, travel != 0 else { return }
        // From where the edge is *going*, if it is still on its way: the
        // content only reports near the end of a travel, so a second fold
        // started during the first read a stale height, travelled to the
        // wrong place and snapped at the end (review, 13.09.2026).
        let base = isTravelling ? travelTo : (naturalHeight ?? panel.frame.height)
        let target = clamped(base + travel)
        guard abs(panel.frame.height - target) > 0.5 else { return }
        stopTravel()
        // Reduce Motion: the rows do not animate on the board either, and
        // an edge that travelled alone would be the one motion left.
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            var frame = panel.frame
            frame.origin.y = frame.maxY - target
            frame.size.height = target
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
            return
        }
        travelStart = CACurrentMediaTime()
        travelFrom = panel.frame.height
        travelTo = target
        travelTop = panel.frame.maxY
        isTravelling = true
        let link = panel.displayLink(target: self, selector: #selector(travelTick))
        travelLink = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func travelTick() {
        guard let panel else { return }
        let progress = min(1, (CACurrentMediaTime() - travelStart) / Board.foldDuration)
        let height = (travelFrom + (travelTo - travelFrom) * Self.easeInOut(progress)).rounded()
        panel.setFrame(
            NSRect(x: panel.frame.minX, y: travelTop - height, width: panel.frame.width, height: height),
            display: true)
        guard progress >= 1 else { return }
        stopTravel()
        panel.invalidateShadow()
        if let natural = naturalHeight { contentHeightChanged(natural) }
    }

    private func stopTravel() {
        travelLink?.invalidate()
        travelLink = nil
        isTravelling = false
    }

    /// The curve SwiftUI's `.easeInOut` is — the cubic Bézier (0.42, 0,
    /// 0.58, 1) — so the edge and the rows are on one curve, not two that
    /// merely share a name. Solved for x by bisection; it runs sixty times
    /// a second for half a second.
    private static func easeInOut(_ x: Double) -> Double {
        func bezier(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t
        }
        var low = 0.0, high = 1.0
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if bezier(mid, 0.42, 0.58) < x { low = mid } else { high = mid }
        }
        return bezier((low + high) / 2, 0, 1)
    }

    private var isTravelling = false
    private var travelLink: CADisplayLink?
    private var travelStart: CFTimeInterval = 0
    private var travelFrom: CGFloat = 0
    private var travelTo: CGFloat = 0
    private var travelTop: CGFloat = 0

    /// What the panel's SwiftUI root needs to know about the window it sits
    /// in (`MenuBarTrayView.body`).
    final class TrayFit: ObservableObject {
        /// The hosting view's height right now — the panel's, frame by
        /// frame while the edge travels — so the SwiftUI root can be exactly
        /// that tall (`MenuBarTrayView.body`).
        @Published var hostHeight: CGFloat = 0
    }
    let fit = TrayFit()

    /// Set while `close()` puts the panel to rest, so the shrink back to the
    /// resting height is applied in one step and not seen — the panel is
    /// ordered out in the same turn.
    private var isClosing = false

    /// The height the content asked for last — the panel opens at it next
    /// time without a first frame at the wrong size.
    private var naturalHeight: CGFloat?

    /// Never taller than the screen it hangs on. The panel grows downward
    /// with its content (12.09.2026, user: no section scrolls in itself);
    /// only a screen too short for it cuts it off, and then the whole panel
    /// scrolls (see `MenuBarTrayView.body`).
    private func clamped(_ height: CGFloat) -> CGFloat {
        guard let screen = anchor?.screen ?? NSScreen.main else { return height }
        let limit = screen.visibleFrame.height - Board.trayEdgeClearance
        return min(height, limit)
    }

    /// Also the way out of the tray for everything that opens the board: the
    /// panel is ours, so it goes when we say (measured M1 — a `MenuBarExtra`
    /// popover would have stayed open beside the window it just opened).
    func close() {
        stopWatchingForClicksOutside()
        // Every closing leaves the panel at rest — no draft, no open fold.
        // Posted while the panel is still up so the content reports its
        // resting height now; the receivers apply it without animation, and
        // the panel is ordered out in the same turn, so nothing is seen to
        // shrink.
        isClosing = true
        NotificationCenter.default.post(name: .glassKanbanTrayResets, object: nil)
        isClosing = false
        panel?.orderOut(nil)
        anchor = nil
    }

    private func makePanel(store: RemindersStore) -> NSPanel {
        // Borderless, not `.titled` with a hidden bar. The hidden title bar
        // still drew its own separator and shadow across the top of the
        // content — the "shadow over the shadow" of the first build. With no
        // border at all, the corner and the edge are the content's own
        // (`MenuBarTrayView`), and the window shadow follows that shape.
        let panel = TrayPanel(
            contentRect: NSRect(x: 0, y: 0, width: Board.trayWidth, height: 100),
            // `.nonactivatingPanel` so opening the tray does not pull the
            // whole app forward — a menu bar item is a glance, not a context
            // switch.
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false)
        panel.isMovable = false
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        // The tray outlives losing focus on purpose: an unanswered WIP
        // question has to still be there when the user comes back to it.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        // The glass is the panel's own body and the content its child — not
        // a SwiftUI background beside the content. Only as a child does the
        // text sit *in* the material rather than printed on it.
        panel.contentViewController = TrayGlassController(
            content: MenuBarTrayView().environmentObject(store))
        // A window grows upward from its bottom-left origin, so every resize
        // would walk the tray away from the menu bar without this. The
        // shadow is cached against the old outline and has to be redone too.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in
            // The shadow is redone by whoever changed the height, once it is
            // at rest — not here, sixty times a second during a fold.
            MainActor.assumeIsolated { self?.position(panel) }
        }
        return panel
    }

    /// Hangs the panel under the status item on the screen the user clicked
    /// on, clamped so it never runs off the edge.
    private func position(_ panel: NSPanel) {
        guard let anchor else { return }
        // Hung the way the system hangs a status item's menu: left-aligned
        // to the item, a hair below the bar (see the tokens' note).
        var origin = NSPoint(
            x: anchor.itemMinX - Board.trayMenuEdgeInset,
            y: anchor.menuBarBottom - Board.trayMenuTopGap - panel.frame.height)
        let visible = anchor.screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + Board.trayEdgeClearance),
                       visible.maxX - panel.frame.width - Board.trayEdgeClearance)
        panel.setFrameOrigin(origin)
    }

    // MARK: - Closing

    private func startWatchingForClicksOutside() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        // The global monitor never sees this app's own clicks, so a click on
        // the board behind the tray would leave it hanging there.
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            // Not for a click on the status item itself: that one reaches
            // `toggle()` right after this, and a close here would turn it
            // into close-then-open — the item could never shut the panel
            // (12.09.2026, user).
            if event.window !== self?.panel, !Self.isStatusBarWindow(event.window) {
                Task { @MainActor in self?.close() }
            }
            return event
        }
        // Escape closes the panel, as it closes every menu. The panel is key
        // while open (`makeKey()` in `open()`), so the key arrives here. Not
        // while the capture field holds a draft: there Escape gives up the
        // draft first (`BacklogCaptureRow.onExitCommand`), and the next one
        // closes — Spotlight's own two steps.
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === panel, event.keyCode == kVK_Escape,
                  !(panel?.firstResponder is NSTextView) else { return event }
            Task { @MainActor in self.close() }
            return nil
        }
        // And when the key status goes elsewhere without a click — ⌘-Tab to
        // another app, a hot key that opens another window. A menu closes
        // then; a panel that stayed would also be one Escape can no longer
        // reach, because the key now goes where the focus went (review,
        // 13.09.2026). Menus and drags do not take key status, so a row's
        // context menu and a lifted row are unaffected (measured the same
        // day).
        keyLossObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    /// The item's glyph: the board — four lanes in one frame. Drawn here
    /// because SF Symbols stops at `rectangle.split.3x1`, and three lanes
    /// for a four-column board read as a different app (13.09.2026, user).
    /// The geometry is the symbol's own, measured at 4× (13.09.2026): a
    /// 19 × 14 pt canvas, a 1 pt stroke, 1.5 pt corners, dividers at equal
    /// parts. One point wider than the symbol's 15 × 12 frame so that four
    /// lanes keep whole-point widths and every line sits on a half-point —
    /// on a 1× display that is the difference between a crisp line and a
    /// grey smear two pixels wide (seen on the first draw).
    static let boardGlyph: NSImage = {
        let image = NSImage(size: NSSize(width: 19, height: 14), flipped: false) { _ in
            let frame = NSRect(x: 1.5, y: 1.5, width: 16, height: 11)
            let path = NSBezierPath(roundedRect: frame, xRadius: 1.5, yRadius: 1.5)
            for lane in 1...3 {
                let x = frame.minX + frame.width * CGFloat(lane) / 4
                path.move(to: NSPoint(x: x, y: frame.minY))
                path.line(to: NSPoint(x: x, y: frame.maxY))
            }
            path.lineWidth = 1
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = String(localized: "Glass Kanban")
        return image
    }()

    /// The status bar's own windows — the item's button lives in one per
    /// display, so the class is checked rather than one window identity.
    private static func isStatusBarWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return String(describing: type(of: window)).contains("StatusBar")
    }

    private func stopWatchingForClicksOutside() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let keyLossObserver { NotificationCenter.default.removeObserver(keyLossObserver) }
        outsideClickMonitor = nil
        localClickMonitor = nil
        escapeMonitor = nil
        keyLossObserver = nil
    }
}

// MARK: - Support

/// The panel's body: Liquid Glass, with the SwiftUI tray as its content.
///
/// `NSGlassEffectView` is the material the system's own menu bar panels are
/// made of — refraction at the edge, the light rim, the shadow. The board
/// itself cannot use native glass: it follows the window's active state and
/// cannot be pinned (CONCEPT.md, "Immer-aktiv"), and the board stands
/// inactive all day. The tray is the other case: it exists only while it is
/// being used, and is the key window then. Measured 12.09.2026 with another
/// app frontmost — see the note at `material`.
///
/// Sizing: the hosting controller reports its ideal size through
/// `preferredContentSize`; this controller passes it up, and the panel
/// follows (see `MenuBarTrayController.makePanel`).
private final class TrayGlassController: NSViewController {
    private let hosting: NSHostingController<AnyView>
    private let glass = NSGlassEffectView()

    /// The height the content wants, before it has ever reported one.
    /// Proposed at height *zero*: the root fills whatever it is offered
    /// (asked with "infinite" it answered ten billion), but a `ZStack` is as
    /// tall as its tallest child, and at zero the filler is nothing and the
    /// content is itself. `sizeThatFits` also lays the hierarchy out at the
    /// proposal and leaves it there (probe, 13.09.2026), so everything is
    /// put back afterwards.
    var naturalContentHeight: CGFloat {
        let frame = view.frame, hostingFrame = hosting.view.frame, windowFrame = view.window?.frame
        let height = hosting.sizeThatFits(in: NSSize(width: Board.trayWidth, height: 0)).height
        if let windowFrame { view.window?.setFrame(windowFrame, display: false) }
        view.frame = frame
        hosting.view.frame = hostingFrame
        return height
    }

    init<Content: View>(content: Content) {
        hosting = NSHostingController(rootView: AnyView(content))
        // No sizing options: with them the hosting view sizes itself to the
        // content's ideal, and the window's height is pinned to that by
        // constraint — the edge's travel set 25 frames that the window never
        // took (probe, 13.09.2026). The panel decides its height; the
        // hosting view is laid out to it in `viewDidLayout`.
        hosting.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// The masked container, and the one place the frames inside it are
    /// set. The glass does not lay its content view out — it keeps whatever
    /// frame it was given, anchored at AppKit's bottom-left, and a view
    /// controller's `viewDidLayout` never fired for it. Every earlier form
    /// of the fold suffered from exactly that (13.09.2026): the content hung
    /// from the bottom while the edge travelled, or was centred by the
    /// hosting view, or vanished. `layout()` runs on every size change of a
    /// layer-backed view, so glass and hosting view are sized to the
    /// container here, and the SwiftUI root fills the hosting view and pins
    /// its content to the top (`MenuBarTrayView.body`).
    private final class TrayContainerView: NSView {
        var glass: NSView?
        var hosting: NSView?
        override func layout() {
            super.layout()
            glass?.frame = bounds
            hosting?.frame = bounds
            let fit = MenuBarTrayController.shared.fit
            if fit.hostHeight != bounds.height { fit.hostHeight = bounds.height }
        }
    }

    override func loadView() {
        glass.cornerRadius = Board.trayRadius
        // Not the glass's `contentView`: the glass sizes that by its
        // intrinsic size and anchors it at the bottom — the content hung
        // from the panel's bottom edge while the edge travelled, and with no
        // intrinsic size it was not drawn at all (13.09.2026). As a sibling
        // over the glass, the hosting view is laid out by the container.
        // The hosting view lives by constraints unless told otherwise, and
        // with no sizing options it has none — its frame stayed at zero and
        // nothing was drawn (13.09.2026). Frames it is, set by the container.
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        hosting.view.autoresizingMask = [.width, .height]
        addChild(hosting)
        // A masked container around the glass, not the glass itself as the
        // window's content view. Seen 12.09.2026: the glass rounded its
        // fill, but the window still carried a square outline at the top
        // corners — a rectangular shadow contour behind the round edge. The
        // mask makes everything outside the radius transparent, and the
        // window shadow follows the shape that is left.
        let container = TrayContainerView()
        container.glass = glass
        container.hosting = hosting.view
        container.wantsLayer = true
        container.layer?.cornerRadius = Board.trayRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = .clear
        glass.frame = container.bounds
        glass.autoresizingMask = [.width, .height]
        container.addSubview(glass)
        hosting.view.frame = container.bounds
        container.addSubview(hosting.view)
        view = container
    }


    /// The panel follows its content while it is open. `open()` sizes it
    /// once from `fittingSize`, but a window does not track its content
    /// controller's `preferredContentSize` by itself — the Backlog unfolding
    /// grew the content and left the panel at its old height, with the head
    /// pushed out of the top (12.09.2026). The resize notification in
    /// `MenuBarTrayController.makePanel` then keeps the top edge where it is.
    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        // Passed up for the first opening only. While the panel is on
        // screen, `MenuBarTrayController.contentHeightChanged` is the one
        // writer of its frame: this hook also setting the size raced the
        // fold to a 131 pt jump at an intermediate value, and held the old
        // height for 0.4 s on the way back (measured 13.09.2026).
        preferredContentSize = viewController.preferredContentSize
    }
}

/// A borderless panel that can still take key status. `NSWindow` refuses it
/// for borderless windows, and without it the rows' hover tracking and the
/// context menu are unreliable while the app itself stays in the background.
private final class TrayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Where the tray hangs from.
///
/// With two displays each menu bar mirrors the status items, but the item's
/// `button.window` lives on one of them — so anchoring to that frame put the
/// tray on the wrong screen when the click came from the other (seen
/// 08.09.2026). The screen is the one under the pointer at the click; the
/// item's x is carried over as its offset from the *right* edge, which is the
/// one thing a right-aligned status item keeps across screens of different
/// widths.
private struct TrayAnchor {
    let screen: NSScreen
    /// The status item's left edge, carried over to the clicked screen.
    let itemMinX: CGFloat
    /// The bottom edge of the menu bar on that screen.
    let menuBarBottom: CGFloat

    @MainActor
    static func atClick(statusItem: NSStatusItem?) -> TrayAnchor? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main else { return nil }
        var itemMinX = mouse.x
        if let button = statusItem?.button, let window = button.window,
           let itemScreen = window.screen {
            let rightOffset = itemScreen.frame.maxX - window.frame.minX
            itemMinX = screen.frame.maxX - rightOffset
        }
        return TrayAnchor(screen: screen, itemMinX: itemMinX, menuBarBottom: screen.visibleFrame.maxY)
    }
}
