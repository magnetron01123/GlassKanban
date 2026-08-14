import Foundation

/// Cleans reminder text for display only — nothing is ever written back.
/// URLs are always hidden (spec). Status tags were hidden too until
/// 13.08.2026, back when the board wrote them; it writes none now, so
/// anything that looks like one is the user's own word and stays.
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

    /// Note lines with URLs stripped, blanks dropped.
    ///
    /// Status tags were stripped here too until 13.08.2026, back when the
    /// board wrote them: hiding its own control token was the honest thing to
    /// do. The board writes no tags any more, so anything that looks like one
    /// is the user's own text — and quietly hiding a word somebody typed is
    /// the opposite of honest.
    private static func cleanedNoteLines(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .components(separatedBy: .newlines)
            .map { line in
                var cleaned = line
                cleaned.replace(urlRegex, with: "")
                cleaned.replace(#/\s{2,}/#, with: " ")
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }
}
