import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RemindersStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            switch store.accessState {
            case .granted:
                BoardView()
            case .denied:
                AccessDeniedView()
            case .unknown, .requesting:
                ProgressView("Zugriff auf Erinnerungen…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background { windowBackground.ignoresSafeArea() }
        .task {
            await store.start()
        }
    }

    @ViewBuilder
    private var windowBackground: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            WindowGlass()
        }
    }
}

/// The window's glass, pinned to its active appearance.
///
/// A SwiftUI `Material` becomes an `NSVisualEffectView` whose state defaults to
/// `.followsWindowActiveState`: the moment the window stops being key, macOS
/// desaturates it into flat grey. That default assumes a window you work *in*
/// and want to recede while you look elsewhere. This board is the opposite — it
/// sits open on a second screen to be looked at all day, so it spends nearly
/// all its life inactive, and following the active state would show the glass
/// the app is named for only in the rare moments it has focus.
///
/// `.containerBackground(for: .window)` gives no access to that state, so the
/// effect view is created here instead. It reaches under the title bar (the
/// view ignores the safe area and the title bar is made transparent), which is
/// what `containerBackground` otherwise handled.
private struct WindowGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // `.hudWindow`, not `.underWindowBackground`. Apple's guidance is to
        // pick a material by semantic role, and by that rule a window root
        // takes `.underWindowBackground` — which is what this was. But that
        // material is nearly opaque: it is designed for the plate *beneath* a
        // window, not for a surface you are meant to see through, and it left
        // an app named "Glass Kanban" with no readable glass at its normal
        // window size.
        //
        // The semantic role here genuinely is the HUD one: this is not a
        // document window you work inside, it is an ambient panel that sits on
        // the desktop all day and is meant to belong to the wallpaper behind
        // it. `.hudWindow` is the material for exactly that, and the board
        // stays legible because no text sits on bare glass — lane headers ride
        // the lane wash, and every card is opaque paper.
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.state = .active
        // The title bar has to stop painting its own strip, or it cuts a flat
        // band across the glass below it. The window keeps its own background:
        // clearing that leaves nothing opaque behind the effect view and the
        // whole window renders invisible.
        guard let window = view.window, !window.titlebarAppearsTransparent else { return }
        window.titlebarAppearsTransparent = true
    }
}

struct AccessDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Kein Zugriff auf Erinnerungen")
                .font(.headline)
            Text("Glass Kanban benötigt Vollzugriff auf deine Erinnerungen, um das Board anzuzeigen. Erlaube den Zugriff in den Systemeinstellungen unter Datenschutz & Sicherheit → Erinnerungen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
            Button("Systemeinstellungen öffnen") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
