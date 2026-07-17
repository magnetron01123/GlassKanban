import SwiftUI

// Platzhalter-Ansicht — die eigentliche Implementierung (EventKit-Datenschicht,
// Hashtag-Status, Drag & Drop, Filter, Motivation) folgt gemäß MVP.md.
struct ContentView: View {
    private let columnNames = ["Backlog", "Als Nächstes", "In Bearbeitung", "Erledigt"]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(columnNames, id: \.self) { name in
                VStack {
                    Text(name)
                        .font(.headline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
