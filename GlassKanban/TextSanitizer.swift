import Foundation

/// Cleans reminder text for display only — nothing is ever written back.
/// URLs are always hidden (spec), status tags are internal control tokens
/// and never shown as note content.
enum TextSanitizer {

    private static let urlRegex = #/(?:https?://|www\.)\S+/#.ignoresCase()

    static func displayTitle(_ raw: String?) -> String {
        guard let raw else { return "" }
        var text = raw
        text.replace(urlRegex, with: "")
        text.replace(#/\s{2,}/#, with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First non-empty line of the notes after removing URLs and status tags.
    /// The card shows this in a single line; truncation happens in the view.
    static func notesPreview(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw
            .components(separatedBy: .newlines)
            .map { line in
                var cleaned = line
                cleaned.replace(urlRegex, with: "")
                cleaned.replace(StatusTagger.nextRegex, with: "")
                cleaned.replace(StatusTagger.progressRegex, with: "")
                cleaned.replace(#/\s{2,}/#, with: " ")
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
            .first { !$0.isEmpty } ?? ""
    }
}
