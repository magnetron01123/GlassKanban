import SwiftUI

/// The board's own tooltip, in the app's glass rather than the system's
/// plain yellow-grey box.
///
/// `.help()` maps to `NSView.toolTip`, a bare string macOS renders itself —
/// there is no hook for material, radius or type, so matching the board meant
/// drawing it. What that costs is spelled out here rather than discovered
/// later: the system tooltip also feeds VoiceOver, so every call site that
/// drops `.help` has to carry the same text as an accessibility hint or value.
///
/// Cards live inside a `ScrollView`, which clips, so a tooltip cannot be an
/// overlay on the thing it describes. Instead each view publishes "I am hovered,
/// here is my text and where I am" upwards, and a single `TooltipHost` at the
/// board's root draws it above everything.
///
/// Toolbar items keep `.help()` on purpose. They are hosted by NSToolbar,
/// outside this hierarchy — and a toolbar tooltip that looks like every other
/// Mac app's is the right answer there, not a deviation worth engineering.
enum BoardTooltipSpace {
    static let name = "boardTooltip"
}

struct BoardTooltipValue: Equatable {
    let text: String
    /// Where the cursor was when the tooltip was raised, in the host's
    /// coordinate space — not the hovered view's frame. Centring on the view
    /// puts the tooltip in the middle of a wide target like a lane header,
    /// which lands it on top of the first card. Every tooltip on the Mac
    /// appears beside the pointer, and that is also the only position that
    /// works for a target of any size.
    let cursor: CGPoint
}

private struct BoardTooltipKey: PreferenceKey {
    static let defaultValue: BoardTooltipValue? = nil

    static func reduce(value: inout BoardTooltipValue?, nextValue: () -> BoardTooltipValue?) {
        if let next = nextValue() { value = next }
    }
}

extension EnvironmentValues {
    /// Set while a card is being dragged. A tooltip fading in under the
    /// cursor mid-drag is noise at exactly the moment the board should be
    /// quiet, and it would sit between the cursor and the lane being aimed at.
    @Entry var boardTooltipsSuppressed: Bool = false
}

// MARK: - Attaching

private struct BoardTooltipModifier: ViewModifier {
    let text: String

    @Environment(\.boardTooltipsSuppressed) private var suppressed
    @State private var isShowing = false
    @State private var cursor: CGPoint = .zero
    @State private var revealTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onContinuousHover(coordinateSpace: .named(BoardTooltipSpace.name)) { phase in
                switch phase {
                case .active(let point):
                    // Tracked only until it appears. A tooltip that follows
                    // the cursor is a cursor decoration; the system's stays
                    // where it was raised, and so does this one.
                    if !isShowing { cursor = point }
                    if revealTask == nil { scheduleReveal() }
                case .ended:
                    dismiss()
                }
            }
            .preference(
                key: BoardTooltipKey.self,
                value: isShowing && !suppressed
                    ? BoardTooltipValue(text: text, cursor: cursor)
                    : nil)
            .onDisappear(perform: dismiss)
            .onChange(of: suppressed) { _, isSuppressed in
                if isSuppressed { dismiss() }
            }
    }

    private func scheduleReveal() {
        revealTask = Task {
            try? await Task.sleep(for: Board.tooltipDelay)
            guard !Task.isCancelled else { return }
            isShowing = true
        }
    }

    private func dismiss() {
        revealTask?.cancel()
        revealTask = nil
        isShowing = false
    }
}

extension View {
    /// Board-styled tooltip. Replaces `.help()` — do not use both, or the
    /// system box appears alongside this one.
    ///
    /// This deliberately does not touch accessibility: `.help()` used to serve
    /// both jobs, and silently folding a hint in here would hide that choice
    /// from the call site. Each site states its own label, value or hint.
    func boardTooltip(_ text: String) -> some View {
        modifier(BoardTooltipModifier(text: text))
    }
}

// MARK: - Hosting

/// Draws whichever tooltip is currently raised, above all board content.
struct TooltipHost<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var value: BoardTooltipValue?
    @State private var size: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .coordinateSpace(.named(BoardTooltipSpace.name))
            .overlay {
                GeometryReader { proxy in
                    if let value {
                        BoardTooltipLabel(text: value.text)
                            .fixedSize()
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                            .position(position(for: value.cursor, in: proxy.size))
                            // Until it has been measured its position is a
                            // guess; showing that frame would be a visible jump.
                            .opacity(size == .zero ? 0 : 1)
                    }
                }
                // A tooltip must never be the thing the cursor hits — that
                // would make it flicker as it steals its own hover.
                .allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: value)
            .onPreferenceChange(BoardTooltipKey.self) { value = $0 }
    }

    /// Below and to the right of the pointer, the way macOS places its own —
    /// flipping to the other side rather than sliding along an edge, so the
    /// tooltip never covers the thing the pointer is resting on.
    private func position(for cursor: CGPoint, in container: CGSize) -> CGPoint {
        let offset = CGSize(width: 12, height: 20)
        let margin: CGFloat = 8

        var left = cursor.x + offset.width
        if left + size.width > container.width - margin {
            left = cursor.x - offset.width - size.width
        }

        var top = cursor.y + offset.height
        if top + size.height > container.height - margin {
            top = cursor.y - offset.height - size.height
        }

        // Only after flipping: clamping first would let a tooltip settle
        // under the pointer at a corner, where it would flicker.
        left = clamp(left, upTo: container.width - size.width - margin, floor: margin)
        top = clamp(top, upTo: container.height - size.height - margin, floor: margin)

        return CGPoint(x: left + size.width / 2, y: top + size.height / 2)
    }

    /// `max` last, so a container too small for the tooltip pins it to the
    /// leading edge instead of producing an inverted range.
    private func clamp(_ value: CGFloat, upTo limit: CGFloat, floor: CGFloat) -> CGFloat {
        max(min(value, limit), floor)
    }
}

// MARK: - Appearance

private struct BoardTooltipLabel: View {
    let text: String

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(text)
            .font(BoardText.meta)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: Board.tooltipMaxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background {
                if reduceTransparency {
                    Board.tooltipShape.fill(Color(nsColor: .controlBackgroundColor))
                } else {
                    // `.withinWindow`, unlike the lane's add button: this
                    // floats *above* the board's own content, so it should
                    // frost the cards behind it rather than punch through to
                    // the desktop.
                    HUDGlassMaterial(blending: .withinWindow)
                        .clipShape(Board.tooltipShape)
                }
            }
            .overlay { Board.tooltipShape.strokeBorder(Board.cardBorder(contrast)) }
            .shadow(
                color: Board.tooltipShadow.color,
                radius: Board.tooltipShadow.radius,
                y: Board.tooltipShadow.y)
    }
}
