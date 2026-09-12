import AppKit
import Carbon.HIToolbox

/// The one global key combination this app owns, and the setting behind it.
///
/// **Why Carbon, in 2026.** `RegisterEventHotKey` is the only way to a
/// system-wide shortcut that needs no Accessibility permission and no third
/// party package — an `NSEvent` global monitor would demand the user hand this
/// app the right to watch every keystroke they ever type, for one key
/// combination. Measured 12.09.2026 (plans/menubar-panel-erweiterungen.md,
/// M2): in this sandboxed app it registers with `noErr` and fires from the
/// background in both activation policies.
///
/// **What it cannot do**, measured the same day: ⌘Space and ⌘Tab register
/// without complaint and then never fire, because the system keeps them. So a
/// clash is only reported when the API reports one (`eventHotKeyExistsErr`);
/// a combination another app or the system already holds simply stays with
/// them, and the settings pane says so.
@MainActor
final class GlobalHotkey {
    static let shared = GlobalHotkey()

    enum Failure: Error {
        /// The API said the combination is taken. The only clash that can be
        /// detected — see the note above.
        case alreadyInUse
        case refused(OSStatus)
    }

    /// What a press does. Set once by `MenuBarTrayController`.
    var action: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var current: TrayShortcut?
    /// Whether a shortcut may be live at all — the panel's own presence
    /// (see `set(enabled:)`).
    private var isEnabled = true

    private init() {}

    /// Registers `shortcut`, replacing whatever was registered before. `nil`
    /// clears it. Throws only when the system refuses.
    func set(_ shortcut: TrayShortcut?) throws {
        current = shortcut
        unregister()
        guard isEnabled, let shortcut, shortcut.isValid else { return }
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(shortcut.modifiers),
            EventHotKeyID(signature: Self.signature, id: 1),
            GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr else {
            current = nil
            throw status == OSStatus(eventHotKeyExistsErr) ? Failure.alreadyInUse : Failure.refused(status)
        }
        hotKeyRef = ref
    }

    /// Without a menu bar item there is no panel to open, so the shortcut
    /// goes with it — a key combination that answers with nothing is worse
    /// than none. Comes back when the item does, with the same shortcut.
    func set(enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        // A shortcut the system refuses on the way back is not worth an
        // error here: the user is not in the settings pane, and the pane
        // reports it the next time they are.
        try? set(current)
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, _ in
                // The handler is a C function pointer and can carry no
                // context, so it hops back to the one owner there is.
                Task { @MainActor in GlobalHotkey.shared.action?() }
                return noErr
            }, 1, &spec, nil, &handlerRef)
    }

    private func carbonModifiers(_ modifiers: TrayShortcut.Modifiers) -> UInt32 {
        var carbon = 0
        if modifiers.contains(.command) { carbon |= cmdKey }
        if modifiers.contains(.option) { carbon |= optionKey }
        if modifiers.contains(.control) { carbon |= controlKey }
        if modifiers.contains(.shift) { carbon |= shiftKey }
        return UInt32(carbon)
    }

    /// "GKNB" — the four-character code every hot key carries. Only ever
    /// compared against our own.
    private static let signature = OSType(0x474B_4E42)
}

/// The stored shortcut, and the one object the settings pane and the tray
/// controller both talk to.
///
/// Shaped like `PresenceController`: the value persists and takes effect in
/// the same step, so there is no state that is saved but not applied.
@MainActor
final class TrayShortcutController: ObservableObject {
    static let shared = TrayShortcutController()

    /// The recorded combination, or none. Setting it stores and registers it
    /// in one move.
    @Published private(set) var shortcut: TrayShortcut?

    /// Set when the system refused the last combination the user recorded.
    /// Cleared by the next one that works, and by clearing the shortcut.
    @Published private(set) var isTaken = false

    private init() {}

    /// Reads what was stored and registers it. A stored value this version
    /// cannot parse leaves the user with no shortcut rather than a wrong one
    /// (`TrayShortcut.parse`).
    func applyStored() {
        shortcut = UserDefaults.standard.string(forKey: StoredSetting.trayShortcut.key)
            .flatMap(TrayShortcut.parse)
        try? GlobalHotkey.shared.set(shortcut)
    }

    /// Records a new combination. Returns false when the system refused it —
    /// then nothing is stored and the previous shortcut stays gone, because
    /// the user has already replaced it in their head.
    @discardableResult
    func record(_ new: TrayShortcut?) -> Bool {
        do {
            try GlobalHotkey.shared.set(new)
        } catch {
            isTaken = true
            shortcut = nil
            UserDefaults.standard.removeObject(forKey: StoredSetting.trayShortcut.key)
            return false
        }
        isTaken = false
        shortcut = new
        if let new {
            UserDefaults.standard.set(new.stored, forKey: StoredSetting.trayShortcut.key)
        } else {
            UserDefaults.standard.removeObject(forKey: StoredSetting.trayShortcut.key)
        }
        return true
    }
}
