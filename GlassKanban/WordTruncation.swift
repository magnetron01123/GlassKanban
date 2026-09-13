import Foundation

/// Shortens a title to whole words when it does not fit on a line.
///
/// The system truncates by character — "Hausratversicherung abschli…" —
/// which reads as a word torn in half. A menu row that has to lose
/// something loses the last word instead and ends with the ellipsis
/// (13.09.2026, user). Pure so it can be tested without a font: the caller
/// hands in the measurement.
enum WordTruncation {
    static let ellipsis = "…"

    /// The longest prefix of `title`, cut only at spaces, that measures at
    /// most `width` together with the ellipsis — or the whole title if it
    /// fits as it is. When not even the first word fits, that word is
    /// returned unshortened; the line then truncates it by character, which
    /// is the only cut left.
    static func fit(_ title: String, in width: CGFloat, measure: (String) -> CGFloat) -> String {
        guard measure(title) > width else { return title }
        let words = title.split(separator: " ", omittingEmptySubsequences: true)
        var count = words.count - 1
        while count >= 1 {
            let candidate = words[..<count].joined(separator: " ") + ellipsis
            if measure(candidate) <= width { return candidate }
            count -= 1
        }
        return words.first.map(String.init) ?? title
    }
}
