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

    private func open() {
        guard let store else { return }
        let panel = self.panel ?? makePanel(store: store)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        startWatchingForClicksOutside()
    }

    /// Also the way out of the tray for everything that opens the board: the
    /// panel is ours, so it goes when we say (measured M1 — a `MenuBarExtra`
    /// popover would have stayed open beside the window it just opened).
    func close() {
        stopWatchingForClicksOutside()
        panel?.orderOut(nil)
    }

    private func makePanel(store: RemindersStore) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Board.trayWidth, height: 100),
            // `.nonactivatingPanel` so opening the tray does not pull the
            // whole app forward — a menu bar item is a glance, not a context
            // switch. `.titled` + `.fullSizeContentView` for the system's own
            // rounded corners and shadow, with the bar itself hidden below.
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovable = false
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        // The tray outlives losing focus on purpose: an unanswered WIP
        // question has to still be there when the user comes back to it.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear

        let hosting = NSHostingController(
            rootView: MenuBarTrayView().environmentObject(store))
        // The tray grows and shrinks with its lanes, so the panel follows the
        // content rather than a constant that would drift away from it.
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting
        // A window grows upward from its bottom-left origin, so every resize
        // would walk the tray away from the menu bar without this.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.position(panel) }
        }
        return panel
    }

    /// Hangs the panel under its own status item, on the screen that item
    /// lives on, clamped so it never runs off the edge.
    private func position(_ panel: NSPanel) {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let anchor = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main
        var origin = NSPoint(
            x: anchor.midX - panel.frame.width / 2,
            y: anchor.minY - panel.frame.height - Board.trayGap)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + Board.trayGap),
                           visible.maxX - panel.frame.width - Board.trayGap)
        }
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
