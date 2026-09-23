import Foundation

/// Which screen the board belongs to, and where on it.
///
/// macOS restores a window's frame across launches, but not across a *display*
/// going away: unplug the monitor the board lives on and the window is herded
/// onto the built-in screen; plug it back in and it stays there. For a board
/// whose whole idea is that it stands somewhere and gets looked at, that is
/// the most expensive moment of the day — the one place where "it is always
/// there" quietly stops being true.
///
/// The decision lives here, away from AppKit, so it can be tested without a
/// monitor to unplug. `WindowPlacementController` supplies the screens and
/// applies the answer.
enum WindowPlacement {

    /// A screen as this rule needs it. The identity has to survive unplugging,
    /// so it is the display's UUID rather than its screen number, which macOS
    /// hands out afresh on every reconnect.
    struct Screen: Equatable {
        let id: String
        let frame: CGRect
        let visibleFrame: CGRect

        init(id: String, frame: CGRect, visibleFrame: CGRect? = nil) {
            self.id = id
            self.frame = frame
            self.visibleFrame = visibleFrame ?? frame
        }
    }

    /// Where the window was put, in its screen's own coordinates. Stored
    /// relative to the screen origin so that rearranging the displays in
    /// System Settings — which moves every origin — does not invalidate it.
    struct Memory: Equatable, Codable {
        let screenID: String
        let frame: CGRect
    }

    /// How long after a display change no frame change counts as the user's.
    ///
    /// Long enough for macOS to finish herding windows around after a display
    /// appears or disappears, short enough that a drag right afterwards is
    /// still recorded. Both edges are forgiving: too short and one stray
    /// position is remembered, too long and one deliberate move is not.
    static let settleDelay: TimeInterval = 1.0

    /// Whether a frame change should be written down as where the board now
    /// belongs.
    ///
    /// **This is the hardest rule in the feature, and the one that silently
    /// destroys it when wrong.** AppKit reports two completely different
    /// events identically: the user dragging the window, and macOS herding it
    /// off a display that just vanished. Recording the second overwrites the
    /// exact memory needed to undo it — the board would learn "I live on the
    /// built-in screen now" at the very moment it was being pushed there
    /// against the user's wishes, and nothing about that failure is visible.
    ///
    /// Nothing in AppKit says which is which, so time is the only available
    /// discriminator: a move that lands within `settleDelay` of a display
    /// change is assumed to be the system rearranging, not a person.
    ///
    /// The board's *own* restoring move counts as a rearrangement too — the
    /// caller renews the timestamp before moving the window, so the answer
    /// here stays false for the move it just made.
    static func countsAsDeliberateMove(
        at moment: Date, lastScreenChange: Date?, settleDelay: TimeInterval = settleDelay
    ) -> Bool {
        guard let lastScreenChange else { return true }
        return moment.timeIntervalSince(lastScreenChange) >= settleDelay
    }

    /// The screen a window sits on: the one it overlaps most. A window
    /// straddling two displays belongs to the one showing more of it, which is
    /// also the one AppKit calls its screen.
    static func screen(for window: CGRect, among screens: [Screen]) -> Screen? {
        screens
            .map { ($0, $0.frame.intersection(window)) }
            .filter { !$0.1.isNull && $0.1.width > 0 && $0.1.height > 0 }
            .max { area($0.1) < area($1.1) }?
            .0
    }

    /// What to write down once the user has placed the window themselves.
    static func remember(window: CGRect, screens: [Screen]) -> Memory? {
        guard let screen = screen(for: window, among: screens) else { return nil }
        return Memory(
            screenID: screen.id,
            frame: window.offsetBy(dx: -screen.frame.origin.x, dy: -screen.frame.origin.y))
    }

    /// Where to move the window now that the screens have changed — or `nil`
    /// to leave it exactly where it is, which is the answer to everything
    /// except "its screen is back and the window is not on it".
    ///
    /// Staying put is deliberately the default. A window that jumps for any
    /// other reason is worse than one that stays in the wrong place: the wrong
    /// place is at least where the user last saw it.
    static func restore(_ memory: Memory, window: CGRect, screens: [Screen]) -> CGRect? {
        guard let home = screens.first(where: { $0.id == memory.screenID }) else { return nil }
        guard screen(for: window, among: screens)?.id != home.id else { return nil }
        let target = fit(
            memory.frame.offsetBy(dx: home.frame.origin.x, dy: home.frame.origin.y),
            into: home.visibleFrame)
        return target == window ? nil : target
    }

    /// Keeps the restored frame on the screen it is going to, in case that
    /// screen came back smaller than it left — a projector after a monitor,
    /// or the same display at a different scaled resolution.
    private static func fit(_ rect: CGRect, into bounds: CGRect) -> CGRect {
        let size = CGSize(
            width: min(rect.width, bounds.width),
            height: min(rect.height, bounds.height))
        return CGRect(
            x: min(max(rect.minX, bounds.minX), bounds.maxX - size.width),
            y: min(max(rect.minY, bounds.minY), bounds.maxY - size.height),
            width: size.width,
            height: size.height)
    }

    private static func area(_ rect: CGRect) -> CGFloat { rect.width * rect.height }
}
