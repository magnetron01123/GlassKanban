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
        cleanedNoteLines(raw).first ?? ""
    }

    /// Up to `maxLines` cleaned note lines, joined for display on the roomier
    /// cards in the working lanes. Truncation still happens in the view.
    static func notesExcerpt(_ raw: String?, maxLines: Int = 3) -> String {
        cleanedNoteLines(raw).prefix(maxLines).joined(separator: "\n")
    }

    /// Note lines with URLs and status tags stripped, blanks dropped.
    private static func cleanedNoteLines(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .components(separatedBy: .newlines)
            .map { line in
                var cleaned = line
                cleaned.replace(urlRegex, with: "")
                for regex in StatusTagger.allTagRegexes {
                    cleaned.replace(regex, with: "")
                }
                cleaned.replace(#/\s{2,}/#, with: " ")
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }
}
