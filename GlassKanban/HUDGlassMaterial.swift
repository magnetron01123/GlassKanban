import SwiftUI
import AppKit

/// The window's own glass material (see `ContentView.WindowGlass`), as a
/// reusable background. `.behindWindow` blending samples what's behind the
/// *window*, not behind this view in the hierarchy — so a small shape using
/// this material reads as "the same glass visible beside the columns"
/// wherever it sits, rather than a new surface stacked on top of the lane.
struct HUDGlassMaterial: NSViewRepresentable {
    /// Defaults to `.behindWindow` — the reading above. Surfaces that float
    /// *above* the board's own content (the tooltip) pass `.withinWindow`
    /// instead, so they frost the cards beneath rather than appearing to cut
    /// a hole through the app to the desktop.
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.blendingMode = blending
        view.state = .active
    }
}
