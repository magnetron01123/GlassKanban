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

    /// The host of the first link in a title — "example.com" for
    /// "https://www.example.com/a/b?c". Display only, and only for a title
    /// that is nothing *but* links: stripped, such a card had no name left
    /// and two different tickets both read "Ohne Titel" (measured
    /// 02.10.2026). The host says which one it is without bringing the link
    /// itself back onto the card.
    ///
    /// Kept apart from `displayTitle` on purpose. That value is what rename
    /// and the optimistic updates compare against; a host slipped in there
    /// would one day be written back into the reminder as its title.
    static func firstLinkHost(_ raw: String?) -> String? {
        guard let raw, let match = raw.firstMatch(of: urlRegex) else { return nil }
        var link = String(match.output).lowercased()
        for scheme in ["https://", "http://"] where link.hasPrefix(scheme) {
            link.removeFirst(scheme.count)
        }
        // The authority is everything up to the path. Whatever stands in
        // front of an "@" is a name or a secret and never reaches the card:
        // "https://token@github.com/x" was hidden whole while links were
        // only stripped, and must not come back as "token@github.com".
        var authority = String(link.prefix { !"/?#".contains($0) })
        if let at = authority.lastIndex(of: "@") {
            authority = String(authority[authority.index(after: at)...])
        }
        // An address literal ("[::1]") names no place a reader recognises.
        guard !authority.hasPrefix("[") else { return nil }
        if authority.hasPrefix("www.") { authority.removeFirst(4) }
        let host = authority.prefix { $0 != ":" }
        return host.isEmpty ? nil : String(host)
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
