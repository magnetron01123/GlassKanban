import Foundation

/// Reads and writes the Kanban status hashtag in reminder notes.
///
/// Rules (see SPEC.md):
/// - Reading: a tag is recognized anywhere in the text, case-insensitively,
///   but only where it stands alone — whitespace or the ends of the text on
///   both sides (see `isStandalone`). So neither "#nextlevel" nor the "#next"
///   inside "example.com/guide#next" counts.
/// - If several tags are present, the one appearing last in the text wins
///   (it is the one most recently appended).
/// - Writing: all existing tags are removed, then the new tag is appended
///   as its own last line. Backlog and Done write no tag at all.
enum StatusTagger {

    /// Written tag is "#alsnächstes"; the umlaut-free spelling "#alsnaechstes"
    /// is accepted when reading (e.g. typed on the go without umlauts).
    static let nextRegex = #/#alsn(?:ä|ae)chstes\b/#.ignoresCase()
    static let progressRegex = #/#inbearbeitung\b/#.ignoresCase()

    /// Tags from earlier builds (English, then a shorter German form).
    /// Recognized when reading and normalized to the current tags above by
    /// the next hygiene pass.
    static let legacyNextRegexes: [Regex<Substring>] = [
        #/#n(?:ä|ae)chstes\b/#.ignoresCase(),
        #/#next\b/#.ignoresCase(),
    ]
    static let legacyProgressRegexes: [Regex<Substring>] = [
        #/#bearbeitung\b/#.ignoresCase(),
        #/#progress\b/#.ignoresCase(),
    ]

    private static var nextRegexes: [Regex<Substring>] { [nextRegex] + legacyNextRegexes }
    private static var progressRegexes: [Regex<Substring>] { [progressRegex] + legacyProgressRegexes }
    static var allTagRegexes: [Regex<Substring>] { nextRegexes + progressRegexes }

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

    static func tagCount(_ notes: String?) -> Int {
        guard let notes else { return 0 }
        return tagRanges(in: notes, of: allTagRegexes).count
    }

    static func hasLegacyTag(_ notes: String?) -> Bool {
        guard let notes else { return false }
        return !tagRanges(in: notes, of: legacyNextRegexes + legacyProgressRegexes).isEmpty
    }

    static func hasStatusTag(_ notes: String?) -> Bool {
        tagCount(notes) > 0
    }

    /// Whether these notes need a hygiene rewrite: a completed reminder still
    /// carrying a status tag, several tags at once, or a tag in a legacy
    /// spelling. Pure, so the rule the sync loop runs on every reminder can be
    /// tested without EventKit.
    static func needsHygiene(notes: String?, isCompleted: Bool) -> Bool {
        (isCompleted && hasStatusTag(notes))
            || tagCount(notes) > 1
            || hasLegacyTag(notes)
    }

    /// Returns the notes rewritten for the given status. The user's own text
    /// is preserved; only tags are removed/appended. Returns nil when the
    /// result would be empty (EventKit prefers nil over an empty string).
    static func rewrittenNotes(_ notes: String?, for status: KanbanStatus) -> String? {
        let original = notes ?? ""
        var text = removingTags(original)
        // Trailing whitespace is tidied only when this call touches the end of
        // the text anyway — a tag line came out, or one is about to go on.
        // An earlier version collapsed every run of blank lines in the whole
        // note on every single move, which quietly ate the paragraph breaks of
        // anyone who writes their notes with them.
        if text != original || status.tag != nil {
            while let last = text.last, last.isWhitespace {
                text.removeLast()
            }
        }
        if let tag = status.tag {
            text = text.isEmpty ? tag : text + "\n" + tag
        }
        return text.isEmpty ? nil : text
    }

    /// Removes all status tags. Only lines that actually contained a tag are
    /// re-tidied (collapsed double spaces, trimmed) — untouched user lines are
    /// preserved character-for-character. A line that held nothing but a tag
    /// disappears with it instead of leaving a blank line where it stood.
    /// Also used by `TicketEditSheet` to show notes without the hidden
    /// hashtag; unlike `TextSanitizer`, URLs are left alone since here
    /// they're real, editable content.
    static func removingTags(_ text: String) -> String {
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            // Only standalone tags come out — see `isStandalone`. Removed back
            // to front so the earlier ranges keep their indices, and skipping
            // anything that overlaps what was just cut, since two patterns
            // could in principle land on the same run of characters.
            let ranges = tagRanges(in: line, of: allTagRegexes).reversed()
            var cleaned = line
            var cutFrom: String.Index?
            for range in ranges where cutFrom.map({ range.upperBound <= $0 }) ?? true {
                cleaned.removeSubrange(range)
                cutFrom = range.lowerBound
            }
            guard cleaned != line else {
                lines.append(line)
                continue
            }
            cleaned.replace(#/[ \t]{2,}/#, with: " ")
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty else { continue }
            lines.append(cleaned)
        }
        return lines.joined(separator: "\n")
    }
}
