import SwiftUI
import AppKit
import Combine

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
            button.image = NSImage(
                systemSymbolName: "rectangle.split.3x1",
                accessibilityDescription: String(localized: "Glass Kanban"))
            button.image?.isTemplate = true
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
        // The board first, and active: the Settings scene opens against the
        // app's own menu bar, which in the menu bar mode exists only while a
        // window of ours is frontmost. Without this the pane opened behind
        // everything, or not at all.
        openBoard()
        NSApp.activate()
        // The action AppKit installs for a SwiftUI `Settings` scene. Sent by
        // name because it is not a declared selector; if a future system
        // renames it, the menu item simply does nothing rather than crashing,
        // and the board is up by then either way.
        DispatchQueue.main.async {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
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
        // Lay the content out *before* placing the panel. Positioned first,
        // the panel still had its placeholder height, hung too low, and then
        // jumped into place once SwiftUI had measured — the "strange
        // positioning" of the first build (11.09.2026).
        if let hosting = panel.contentViewController {
            hosting.view.layoutSubtreeIfNeeded()
            // The content's own height once it has reported one; the
            // fitting size only for the very first opening, before it has.
            let natural = naturalHeight ?? hosting.view.fittingSize.height
            panel.setContentSize(NSSize(width: Board.trayWidth, height: clamped(natural)))
        }
        position(panel)
        // Before it is on screen: the capture row goes back to rest, so the
        // panel opens the same way every time (see `BacklogCaptureRow`).
        NotificationCenter.default.post(name: .glassKanbanTrayWillOpen, object: nil)
        panel.orderFrontRegardless()
        panel.makeKey()
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
        panel.setContentSize(NSSize(width: Board.trayWidth, height: target))
    }

    /// The height the content asked for last — the panel opens at it next
    /// time without a first frame at the wrong size.
    private var naturalHeight: CGFloat?

    /// Never taller than the screen it hangs on. The panel grows downward
    /// with its content (12.09.2026, user: no section scrolls in itself);
    /// only a screen too short for it cuts it off, and then the whole panel
    /// scrolls (see `MenuBarTrayView.body`).
    private func clamped(_ height: CGFloat) -> CGFloat {
        guard let screen = anchor?.screen ?? NSScreen.main else { return height }
        return min(height, screen.visibleFrame.height - Board.trayEdgeClearance)
    }

    /// Also the way out of the tray for everything that opens the board: the
    /// panel is ours, so it goes when we say (measured M1 — a `MenuBarExtra`
    /// popover would have stayed open beside the window it just opened).
    func close() {
        stopWatchingForClicksOutside()
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
            MainActor.assumeIsolated {
                self?.position(panel)
                panel.invalidateShadow()
            }
        }
        return panel
    }

    /// Hangs the panel under the status item on the screen the user clicked
    /// on, clamped so it never runs off the edge.
    private func position(_ panel: NSPanel) {
        guard let anchor else { return }
        // Flush against the menu bar, like every menu the system opens
        // from it — no gap (12.09.2026). The clearance token only keeps the
        // panel off the screen's side edges.
        var origin = NSPoint(
            x: anchor.midX - panel.frame.width / 2,
            y: anchor.menuBarBottom - panel.frame.height)
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
    }

    /// The status bar's own windows — the item's button lives in one per
    /// display, so the class is checked rather than one window identity.
    private static func isStatusBarWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return String(describing: type(of: window)).contains("StatusBar")
    }

    private func stopWatchingForClicksOutside() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        outsideClickMonitor = nil
        localClickMonitor = nil
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

    init<Content: View>(content: Content) {
        hosting = NSHostingController(rootView: AnyView(content))
        hosting.sizingOptions = [.preferredContentSize]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        let glass = NSGlassEffectView()
        glass.cornerRadius = Board.trayRadius
        glass.contentView = hosting.view
        addChild(hosting)
        // A masked container around the glass, not the glass itself as the
        // window's content view. Seen 12.09.2026: the glass rounded its
        // fill, but the window still carried a square outline at the top
        // corners — a rectangular shadow contour behind the round edge. The
        // mask makes everything outside the radius transparent, and the
        // window shadow follows the shape that is left.
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = Board.trayRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = .clear
        glass.frame = container.bounds
        glass.autoresizingMask = [.width, .height]
        container.addSubview(glass)
        view = container
        preferredContentSize = hosting.view.fittingSize
    }

    /// The panel follows its content while it is open. `open()` sizes it
    /// once from `fittingSize`, but a window does not track its content
    /// controller's `preferredContentSize` by itself — the Backlog unfolding
    /// grew the content and left the panel at its old height, with the head
    /// pushed out of the top (12.09.2026). The resize notification in
    /// `MenuBarTrayController.makePanel` then keeps the top edge where it is.
    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        preferredContentSize = viewController.preferredContentSize
        guard let window = view.window, window.isVisible else { return }
        window.setContentSize(viewController.preferredContentSize)
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
    let midX: CGFloat
    /// The bottom edge of the menu bar on that screen.
    let menuBarBottom: CGFloat

    @MainActor
    static func atClick(statusItem: NSStatusItem?) -> TrayAnchor? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main else { return nil }
        var midX = mouse.x
        if let button = statusItem?.button, let window = button.window,
           let itemScreen = window.screen {
            let rightOffset = itemScreen.frame.maxX - window.frame.midX
            midX = screen.frame.maxX - rightOffset
        }
        return TrayAnchor(screen: screen, midX: midX, menuBarBottom: screen.visibleFrame.maxY)
    }
}
