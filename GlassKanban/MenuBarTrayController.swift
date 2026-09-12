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
    private weak var store: RemindersStore?

    /// Called once from the app delegate. The store comes from there rather
    /// than from a scene: in the menu bar mode there is no window, so nothing
    /// in the SwiftUI hierarchy is alive to hand it over.
    func start(store: RemindersStore) {
        self.store = store
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
            button.action = #selector(toggle)
        }
        // ⌘-dragging the item off the bar only sets `isVisible` — the app
        // itself would keep running with no Dock icon and no item, reachable
        // by nothing the user has. The setting follows the gesture instead.
        visibilityObservation = item.observe(\.isVisible, options: [.new]) { _, change in
            guard change.newValue == false else { return }
            Task { @MainActor in
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

    @objc private func toggle() {
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
            panel.setContentSize(hosting.view.fittingSize)
        }
        position(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        // The shadow is cached against whatever outline the window had
        // before its first display; redone once the glass has drawn.
        DispatchQueue.main.async { panel.invalidateShadow() }
        startWatchingForClicksOutside()
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
        var origin = NSPoint(
            x: anchor.midX - panel.frame.width / 2,
            y: anchor.menuBarBottom - panel.frame.height - Board.trayGap)
        let visible = anchor.screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + Board.trayGap),
                       visible.maxX - panel.frame.width - Board.trayGap)
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
            if event.window !== self?.panel {
                Task { @MainActor in self?.close() }
            }
            return event
        }
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

    override func preferredContentSizeDidChange(for viewController: NSViewController) {
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
