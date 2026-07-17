import Foundation

/// Static, local list of motivational sentences. One per calendar day,
/// stable within the day — no server, no analysis of user behavior.
enum Quotes {

    static let all: [String] = [
        "Sichtbare Arbeit ist der erste Schritt zu erledigter Arbeit.",
        "Weniger anfangen, mehr beenden.",
        "Ein Board sagt mehr als tausend Gedanken.",
        "Fortschritt braucht keinen Lärm.",
        "Klarheit ist die halbe Arbeit.",
        "Heute zählt, was fertig wird.",
        "Eine Karte nach der anderen.",
        "Wer den Überblick hat, hat die Ruhe.",
        "Kleine Schritte tragen weiter als große Pläne.",
        "Erledigt schlägt perfekt.",
        "Der Fluss zählt, nicht die Eile.",
        "Ordnung im Board, Ordnung im Kopf.",
        "Jede erledigte Karte ist ein kleiner Feierabend.",
        "Was sichtbar ist, wird machbar.",
        "Konzentration ist die schönste Form von Effizienz.",
        "Morgen dankt dir für heute.",
        "Nicht mehr tun — bewusster tun.",
        "Auch das Backlog ist ein guter Ort für Ideen.",
        "Ein ruhiges Board ist kein leeres Board.",
        "Anfangen ist gut, abschließen ist besser.",
    ]

    static func quote(for date: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        return all[(day + year) % all.count]
    }
}
