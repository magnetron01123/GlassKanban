import Foundation

/// What a finished inline title edit should actually write.
///
/// Pulled out of the view because this is the one place on the board where an
/// edit can destroy data. A card shows the *sanitized* title — URLs stripped,
/// runs of whitespace collapsed (see `TextSanitizer.displayTitle`) — so an edit
/// has to start from the stored title and be compared against the stored title.
/// Starting from what is on screen silently rewrites "Angebot von
/// https://example.com prüfen" to "Angebot von prüfen" the moment the field
/// loses focus.
enum TicketRename {

    enum Outcome: Equatable {
        /// Write nothing: the edit changed nothing, or emptied the title out.
        case discard
        case save(String)
    }

    static func outcome(original: String, edited: String) -> Outcome {
        let trimmed = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty field is not a rename to "nothing" — it is a card whose name
        // has been wiped, which Reminders shows as an unnamed row and the board
        // as "Ohne Titel". Nobody types that on purpose.
        guard !trimmed.isEmpty else { return .discard }
        // An unchanged title is not free to save: every write bumps
        // `lastModifiedDate`, which is exactly what the card reads as "how long
        // has this been sitting in this column", and pushes a no-op change
        // through iCloud to every other device.
        guard trimmed != original else { return .discard }
        return .save(trimmed)
    }
}
