import SwiftUI
import AppKit

/// The window's own glass material (see `ContentView.WindowGlass`), as a
/// reusable background. `.behindWindow` blending samples what's behind the
/// *window*, not behind this view in the hierarchy — so a small shape using
/// this material reads as "the same glass visible beside the columns"
/// wherever it sits, rather than a new surface stacked on top of the lane.
struct HUDGlassMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.state = .active
    }
}
