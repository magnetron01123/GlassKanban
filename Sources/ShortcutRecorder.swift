import SwiftUI
import AppKit
import Carbon.HIToolbox

/// The field in the settings pane that records the panel's global shortcut.
///
/// AppKit, because SwiftUI has no way to read a raw key press: every route it
/// offers (`onKeyPress`, `keyboardShortcut`) is about *reacting* to a
/// combination, and this control has to catch one without acting on it — ⌘Q
/// pressed in here must be recorded, not quit the app. Only a first responder
/// that overrides `performKeyEquivalent` sees it before the menu does.
struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: TrayShortcut?
    /// Returns false when the system refused the combination.
    let record: (TrayShortcut?) -> Bool

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = record
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.onRecord = record
        button.shortcut = shortcut
        button.isEnabled = context.environment.isEnabled
    }
}

/// A button that turns into a listener when it is pressed.
final class RecorderButton: NSButton {
    var onRecord: ((TrayShortcut?) -> Bool)?

    var shortcut: TrayShortcut? {
        didSet { if !isRecording { refreshTitle() } }
    }

    private var isRecording = false {
        didSet { refreshTitle() }
    }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { isEnabled }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        // Wide enough that "⌥⌘K" and the recording prompt do not change the
        // width of the row as the user works in it.
        size.width = max(size.width, 150)
        return size
    }

    @objc private func beginRecording() {
        guard isEnabled else { return }
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    // A plain key while recording.
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handle(event)
    }

    /// Anything with a modifier arrives here first — before the menus get it,
    /// which is the whole point of recording in an AppKit control.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        handle(event)
        return true
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            // Gives up on recording and keeps whatever was set before, the
            // same as Escape does in every field of this app.
            isRecording = false
            return
        case kVK_Delete, kVK_ForwardDelete:
            isRecording = false
            _ = onRecord?(nil)
            shortcut = nil
            refreshTitle()
            return
        default:
            break
        }
        guard let label = Self.label(for: event) else { return }
        let candidate = TrayShortcut(
            keyCode: event.keyCode,
            modifiers: TrayShortcut.Modifiers(event.modifierFlags),
            label: label)
        // Not yet usable — ⇧ alone, or a bare letter. Stay in recording
        // rather than storing something that would swallow that key
        // everywhere; the user is mid-combination and has not finished.
        guard candidate.isValid else { return }
        isRecording = false
        shortcut = onRecord?(candidate) == true ? candidate : nil
        refreshTitle()
    }

    private func refreshTitle() {
        if isRecording {
            title = String(localized: "Recording…")
        } else if let shortcut {
            title = shortcut.displayString
        } else {
            title = String(localized: "No Shortcut")
        }
        invalidateIntrinsicContentSize()
    }

    /// What to print for the key that was pressed.
    ///
    /// `charactersIgnoringModifiers` is the layout's own answer — "K" for the
    /// K key wherever it sits — but it gives a control character for keys
    /// that type nothing. Those get the sign a macOS menu uses; everything
    /// still unprintable is refused, because a shortcut that cannot be shown
    /// cannot be taken back either.
    private static func label(for event: NSEvent) -> String? {
        if let special = specialLabels[Int(event.keyCode)] { return special }
        guard let typed = event.charactersIgnoringModifiers, !typed.isEmpty else { return nil }
        let label = typed.uppercased()
        guard label.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
        else { return nil }
        return label
    }

    private static let specialLabels: [Int: String] = [
        kVK_Space: "␣",
        kVK_Return: "↩",
        kVK_ANSI_KeypadEnter: "⌤",
        kVK_Tab: "⇥",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_UpArrow: "↑",
        kVK_DownArrow: "↓",
        kVK_Home: "↖",
        kVK_End: "↘",
        kVK_PageUp: "⇞",
        kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

extension TrayShortcut.Modifiers {
    /// Only the four that a hot key can carry; everything else in the event
    /// (Caps Lock, Fn, the numeric-pad flag) says nothing about the
    /// combination the user meant.
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: TrayShortcut.Modifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        self = modifiers
    }
}
