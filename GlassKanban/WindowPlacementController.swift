import AppKit
import SwiftUI

/// Applies `WindowPlacement` to the real window: remembers where the user puts
/// the board, and puts it back there when its display returns.
///
/// The whole difficulty is telling two frame changes apart, because AppKit
/// reports them identically: the user dragging the window, and macOS herding
/// it off a display that just vanished. Only the first may be written down —
/// recording the second would overwrite the very memory needed to undo it.
/// Nothing in AppKit says which is which, so the arrangement being in flux is
/// treated as a short window of time in which no move counts as the user's.


final class WindowPlacementController: NSObject {
    static let shared = WindowPlacementController()

    private static let storageKey = "windowPlacement"

    /// Long enough for macOS to finish moving windows around after a display
    /// appears or disappears, short enough that a user drag right afterwards
    /// is still recorded. Both edges are forgiving: too short and one stray
    /// position is remembered, too long and one deliberate move is not.
    private static let settleDelay: TimeInterval = 1.0

    private weak var window: NSWindow?

    var isAttached: Bool { window != nil }
    private var isRearranging = false
    private var settle: DispatchWorkItem?

    private override init() { super.init() }

    /// Called from the view side once the window exists. Safe to call again:
    /// SwiftUI updates its representables often, and only the first call for a
    /// given window does anything.
    func attach(to window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window

        let center = NotificationCenter.default
        center.removeObserver(self)
        center.addObserver(
            self, selector: #selector(windowFrameChanged),
            name: NSWindow.didMoveNotification, object: window)
        center.addObserver(
            self, selector: #selector(windowFrameChanged),
            name: NSWindow.didEndLiveResizeNotification, object: window)
        center.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Nothing is restored at attach time. macOS has already placed the
        // window by now, and moving it out from under a launch would be the
        // jump this rule exists to avoid. The display coming back is the only
        // moment that justifies one.
        if stored == nil { record() }
    }

    @objc private func windowFrameChanged() {
        guard !isRearranging else { return }
        record()
    }

    @objc private func screensChanged() {
        isRearranging = true
        settle?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.restore()
            self?.isRearranging = false
        }
        settle = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay, execute: work)
    }

    private func record() {
        guard let window, !window.isMiniaturized,
              let memory = WindowPlacement.remember(window: window.frame, screens: screens)
        else { return }
        stored = memory
    }

    private func restore() {
        guard let window, let memory = stored,
              let frame = WindowPlacement.restore(memory, window: window.frame, screens: screens)
        else { return }
        window.setFrame(frame, display: true, animate: false)
    }

    private var screens: [WindowPlacement.Screen] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.displayUUID else { return nil }
            return WindowPlacement.Screen(
                id: id, frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }

    private var stored: WindowPlacement.Memory? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return nil }
            return try? JSONDecoder().decode(WindowPlacement.Memory.self, from: data)
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

private extension NSScreen {
    /// The display's UUID — stable across unplugging, unlike `NSScreenNumber`,
    /// which macOS reassigns on reconnect. A screen without one (rare, and
    /// virtual displays are the usual cause) is simply left out: the feature
    /// then does nothing rather than guessing.
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

/// Finds the board window and stays out of SwiftUI's way.
///
/// A representable placed in `ContentView`'s background looked like the
/// obvious hook and never ran: SwiftUI did not put the view into the window
/// hierarchy at all, so `viewDidMoveToWindow` never fired and the controller
/// silently never attached — a failure the build, the tests and a launched app
/// all looked healthy through. The app delegate asks instead, and the window
/// is recognised by the autosave name SwiftUI gives its `Window(id: "board")`.
extension WindowPlacementController {
    static let boardWindowName = "board"

    func start() {
        attachToBoardWindow()
        // The scene may not have built its window yet at launch. The first
        // window to take focus is the board's, and by then it exists.
        NotificationCenter.default.addObserver(
            self, selector: #selector(boardWindowMayExist),
            name: NSWindow.didBecomeKeyNotification, object: nil)
    }

    @objc fileprivate func boardWindowMayExist() { attachToBoardWindow() }

    fileprivate func attachToBoardWindow() {
        guard !isAttached,
              let board = NSApp.windows.first(where: {
                  $0.frameAutosaveName == Self.boardWindowName
              })
        else { return }
        attach(to: board)
    }
}
