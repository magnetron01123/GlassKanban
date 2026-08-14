import Foundation

/// Reads the Kanban status hashtag this board used to keep in reminder notes,
/// and cuts it back out of them.
///
/// **Migration only, since 13.08.2026.** The column moved into the board's own
/// storage (`ColumnState`), so nothing here writes a tag any more. What is
/// left serves the one-off handover: reading the old form once per list, and
/// removing it from the notes afterwards. When that cleanup is eventually
/// dropped — no earlier than a version after 1.0, once no install can still be
/// carrying tags — this type goes with it.
///
/// Until then the standalone rule below stays **safety-critical**: this is the
/// last place in the app that cuts text out of a note somebody else may have
/// written, and it was measured destroying real text once already.
///
/// Rules (see SPEC.md):
/// - A tag is recognized anywhere in the text, case-insensitively, but only
///   where it stands alone — whitespace or the ends of the text on both sides
///   (see `isStandalone`). So neither "#nextlevel" nor the "#next" inside
///   "example.com/guide#next" counts.
/// - If several tags are present, the one appearing last in the text wins
///   (it is the one most recently appended).
enum StatusTagger {

    /// Canonical tags as of the DE+EN localization (2026): `#next`/`#inprogress`.
    /// English is the app's source language for 1.0, so the visible data
    /// format — a hashtag typed into notes on any device, in any locale —
    /// moves with it.
    static let nextRegex = #/#next\b/#.ignoresCase()
    static let progressRegex = #/#inprogress\b/#.ignoresCase()

    /// Tags from earlier builds — the pre-localization German forms
    /// (`#alsnächstes`/`#inbearbeitung` and their older, shorter cousins),
    /// plus `#progress` from a build that briefly used it without the "in".
    /// Recognized when reading, so a tag from any build this board ever had
    /// still reaches the right lane during the handover.
    static let legacyNextRegexes: [Regex<Substring>] = [
        #/#alsn(?:ä|ae)chstes\b/#.ignoresCase(),
        #/#n(?:ä|ae)chstes\b/#.ignoresCase(),
    ]
    static let legacyProgressRegexes: [Regex<Substring>] = [
        #/#inbearbeitung\b/#.ignoresCase(),
        #/#bearbeitung\b/#.ignoresCase(),
        #/#progress\b/#.ignoresCase(),
    ]

    private static var nextRegexes: [Regex<Substring>] { [nextRegex] + legacyNextRegexes }
    private static var progressRegexes: [Regex<Substring>] { [progressRegex] + legacyProgressRegexes }
    /// Private on purpose: applying these raw, without `isStandalone`, is how
    /// text that merely looks like a tag gets deleted. Everything that needs
    /// to find or remove a tag goes through `tagRanges` / `removingTags`, so
    /// reading, counting and removing can never disagree about what a tag is.
    private static var allTagRegexes: [Regex<Substring>] { nextRegexes + progressRegexes }

    static func status(fromNotes notes: String?, isCompleted: Bool) -> KanbanStatus {
        if isCompleted { return .done }
        guard let notes, !notes.isEmpty else { return .backlog }
        let lastNext = lastRange(in: notes, of: nextRegexes)
        let lastProgress = lastRange(in: notes, of: progressRegexes)
        switch (lastNext, lastProgress) {
        case (nil, nil):
            return .backlog
        case (.some, nil):
            return .next
        case (nil, .some):
            return .inProgress
        case let (.some(next), .some(progress)):
            return next.lowerBound > progress.lowerBound ? .next : .inProgress
        }
    }

    /// Whether a match is the whole word and not a piece of a longer one.
    ///
    /// The patterns above carry `\b` on their right, which stops
    /// `#inbearbeitungszeit` — but a regex boundary sits between *any* word
    /// and non-word character, so `#next` was also found inside
    /// `https://example.com/guide#next` (a URL fragment), inside `#next-steps`
    /// and inside `ABC#NEXT!`. Every one of those made the tag hygiene rewrite
    /// the note: the anchor came off the link, the card jumped to another
    /// lane, and no undo was registered because the user never acted.
    ///
    /// So a tag counts only when it stands alone — whitespace or the ends of
    /// the text on both sides. That is exactly the shape this app writes
    /// (`rewrittenNotes` puts the tag on its own last line) and the shape
    /// someone types on the go. The rule deliberately fails *closed*: a tag
    /// written as `#alsnächstes.` is no longer recognised, so the card stays
    /// in Backlog with its text intact. Not seeing a tag costs a drag; seeing
    /// one that is not there costs the user's words.
    ///
    /// Checked here rather than in the pattern because Swift's regex engine
    /// has no lookbehind ("lookbehind is not currently supported").
    private static func isStandalone(_ range: Range<String.Index>, in text: String) -> Bool {
        let leftIsClear = range.lowerBound == text.startIndex
            || text[text.index(before: range.lowerBound)].isWhitespace
        let rightIsClear = range.upperBound == text.endIndex
            || text[range.upperBound].isWhitespace
        return leftIsClear && rightIsClear
    }

    /// Every standalone tag in `text`, in the order it appears. The one place
    /// the boundary rule is applied, so reading, counting and removing can
    /// never disagree about what a tag is.
    private static func tagRanges(
        in text: String, of regexes: [Regex<Substring>]
    ) -> [Range<String.Index>] {
        regexes
            .flatMap { text.ranges(of: $0) }
            .filter { isStandalone($0, in: text) }
            .sorted { $0.lowerBound < $1.lowerBound }
    }

    private static func lastRange(in text: String, of regexes: [Regex<Substring>]) -> Range<String.Index>? {
        tagRanges(in: text, of: regexes).last
    }

    private static func tagCount(_ notes: String?) -> Int {
        guard let notes else { return 0 }
        return tagRanges(in: notes, of: allTagRegexes).count
    }

    static func hasStatusTag(_ notes: String?) -> Bool {
        tagCount(notes) > 0
    }

    /// Removes all status tags. Only lines that actually contained a tag are
    /// re-tidied (collapsed double spaces, trimmed) — untouched user lines are
    /// preserved character-for-character. A line that held nothing but a tag
    /// disappears with it instead of leaving a blank line where it stood.
    /// The one remaining writer of note text in this app, and only during the
    /// migration described above.
    static func removingTags(_ text: String) -> String {
        // Every kind of line break splits, and each one is carried along so it
        // can be put back exactly as it was. Splitting on "\n" alone let a
        // note separated by U+2028 (what a paste from a PDF or a web page
        // gives) or by a lone "\r" count as one single line, so the tidy pass
        // below ran across the whole note and ate the user's double spaces on
        // lines that never held a tag. Replacing those separators with "\n"
        // instead would be a smaller edit of someone else's text, but still an
        // edit — and untouched lines are promised through character for
        // character (SPEC.md).
        var kept: [(text: String, separator: String)] = []
        var rawLines: [String] = []
        var separators: [String] = []
        var current = ""
        for character in text {
            // CRLF is one Character in Swift, so it stays one separator
            // rather than being torn in two.
            if character.isNewline {
                rawLines.append(current)
                separators.append(String(character))
                current = ""
                continue
            }
            current.append(character)
        }
        rawLines.append(current)
        for (index, rawLine) in rawLines.enumerated() {
            // Only standalone tags come out — see `isStandalone`. Removed back
            // to front so the earlier ranges keep their indices, and skipping
            // anything that overlaps what was just cut, since two patterns
            // could in principle land on the same run of characters.
            let ranges = tagRanges(in: rawLine, of: allTagRegexes).reversed()
            var cleaned = rawLine
            var cutFrom: String.Index?
            for range in ranges where cutFrom.map({ range.upperBound <= $0 }) ?? true {
                cleaned.removeSubrange(range)
                cutFrom = range.lowerBound
            }
            let separator = index < separators.count ? separators[index] : ""
            guard cleaned != rawLine else {
                kept.append((rawLine, separator))
                continue
            }
            cleaned.replace(#/[ \t]{2,}/#, with: " ")
            // `.whitespaces` is space and tab only, so a lone carriage return
            // survived it — notes pasted from a Windows source kept a "\r"
            // where the tag line had been, and the line counted as non-empty
            // and stayed as a blank one. `.whitespacesAndNewlines` covers it.
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            kept.append((cleaned, separator))
        }
        // The last surviving line carries no separator: a line that came out
        // took its own break with it, and a note must not end in a dangling
        // one.
        var result = ""
        for (index, entry) in kept.enumerated() {
            result += entry.text
            if index < kept.count - 1 {
                result += entry.separator
            }
        }
        return result
    }
}
