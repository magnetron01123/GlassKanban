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
                        // No `.fixedSize()`: the panel already measures its
                        // own text and states an exact width. Wrapping it in
                        // fixedSize is what made SwiftUI lay the text out
                        // unbounded and then clip it.
                        BoardTooltipLabel(text: value.text)
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                            .position(position(for: value.cursor, in: proxy.size))
                            // Until it has been measured its position is a
                            // guess; showing that frame would be a visible jump.
                            .opacity(size == .zero ? 0 : 1)
                            // Moving to a different target replaces the panel
                            // instead of animating one across the board — a
                            // tooltip sliding between cards would be the most
                            // distracting motion on a deliberately quiet board.
                            .id(value.text)
                            .transition(
                                .opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
                    }
                }
                // A tooltip must never be the thing the cursor hits — that
                // would make it flicker as it steals its own hover.
                .allowsHitTesting(false)
            }
            // Keyed on the text, not the whole value: animating the value
            // would animate the position too, sliding the panel whenever the
            // pointer raised it somewhere new.
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: value?.text)
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

/// The panel itself.
///
/// Tooltip text arrives as lines, and they are not equal: the first says what
/// the thing is, the rest qualify it ("Gemeinsame Aufgaben" over "Doppelklick
/// öffnet Erinnerungen"). Setting both in one weight was what made this read
/// as dumped text rather than a composed surface, so the first line leads and
/// the remainder steps back.
private struct BoardTooltipLabel: View {
    let text: String

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    /// Measured with the very fonts used to draw, so wrapping can never
    /// disagree with layout. Built from NSFont for exactly that reason:
    /// `.frame(maxWidth:)` under an outer `.fixedSize()` lays the text out at
    /// its ideal single-line width and *then* clips it to the cap — which is
    /// what truncated these tooltips. Measuring first removes the guesswork.
    private static let leadFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
    private static let detailFont = NSFont.systemFont(ofSize: 11)

    private var lines: [String] {
        text.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    private var width: CGFloat {
        let widest = lines.enumerated().reduce(CGFloat.zero) { widest, entry in
            let font = entry.offset == 0 ? Self.leadFont : Self.detailFont
            let line = (entry.element as NSString).size(withAttributes: [.font: font]).width
            return max(widest, line)
        }
        // Rounded up: a fractional shortfall costs a whole wrapped line.
        return min(widest.rounded(.up) + 1, Board.tooltipMaxWidth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(Font(index == 0 ? Self.leadFont : Self.detailFont))
                    .foregroundStyle(index == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: width, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background { surface }
        .overlay { edge }
        .overlay { topHighlight }
        .shadow(
            color: Board.tooltipShadowContact.color,
            radius: Board.tooltipShadowContact.radius,
            y: Board.tooltipShadowContact.y)
        .shadow(
            color: Board.tooltipShadowAmbient.color,
            radius: Board.tooltipShadowAmbient.radius,
            y: Board.tooltipShadowAmbient.y)
    }

    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            Board.tooltipShape.fill(Color(nsColor: .controlBackgroundColor))
        } else {
            // `.withinWindow`, unlike the lane's add button: this floats
            // *above* the board's own content, so it should frost the cards
            // behind it rather than punch through to the desktop.
            HUDGlassMaterial(blending: .withinWindow)
                .clipShape(Board.tooltipShape)
        }
    }

    /// Half a point, not a full one. At this size a full hairline is what
    /// makes a glass panel read as a bordered box.
    private var edge: some View {
        Board.tooltipShape
            .strokeBorder(Board.cardBorder(contrast), lineWidth: 0.5)
    }

    /// The same lit top edge the cards carry, for the same reason and with
    /// the same limit: on a light surface a white highlight is invisible, so
    /// it would be pure render cost outside dark mode.
    @ViewBuilder
    private var topHighlight: some View {
        if colorScheme == .dark {
            Board.tooltipShape
                .strokeBorder(
                    LinearGradient(colors: [Board.cardTopHighlight, .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }
}
