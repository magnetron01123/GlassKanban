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
        .containerBackground(windowBackground, for: .window)
        .task {
            await store.start()
        }
    }

    private var windowBackground: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
            : AnyShapeStyle(.ultraThinMaterial)
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
