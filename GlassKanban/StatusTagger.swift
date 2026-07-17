import Foundation

/// Reads and writes the Kanban status hashtag in reminder notes.
///
/// Rules (see MVP.md):
/// - Reading: a tag is recognized anywhere in the text, case-insensitively,
///   with a word boundary so "#nextlevel" does not count.
/// - If several tags are present, the one appearing last in the text wins
///   (it is the one most recently appended).
/// - Writing: all existing tags are removed, then the new tag is appended
///   as its own last line. Backlog and Done write no tag at all.
enum StatusTagger {

    /// Written tag is "#nächstes"; the umlaut-free spelling "#naechstes"
    /// is accepted when reading (e.g. typed on the go without umlauts).
    static let nextRegex = #/#n(?:ä|ae)chstes\b/#.ignoresCase()
    static let progressRegex = #/#bearbeitung\b/#.ignoresCase()

    /// Legacy English tags from earlier builds. Recognized when reading and
    /// normalized to the German tags by the next hygiene pass.
    static let legacyNextRegex = #/#next\b/#.ignoresCase()
    static let legacyProgressRegex = #/#progress\b/#.ignoresCase()

    private static var nextRegexes: [Regex<Substring>] { [nextRegex, legacyNextRegex] }
    private static var progressRegexes: [Regex<Substring>] { [progressRegex, legacyProgressRegex] }
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

    private static func lastRange(in text: String, of regexes: [Regex<Substring>]) -> Range<String.Index>? {
        regexes
            .flatMap { text.ranges(of: $0) }
            .max { $0.lowerBound < $1.lowerBound }
    }

    static func tagCount(_ notes: String?) -> Int {
        guard let notes else { return 0 }
        return allTagRegexes.reduce(0) { $0 + notes.ranges(of: $1).count }
    }

    static func hasLegacyTag(_ notes: String?) -> Bool {
        guard let notes else { return false }
        return notes.contains(legacyNextRegex) || notes.contains(legacyProgressRegex)
    }

    static func hasStatusTag(_ notes: String?) -> Bool {
        tagCount(notes) > 0
    }

    /// Returns the notes rewritten for the given status. The user's own text
    /// is preserved; only tags are removed/appended. Returns nil when the
    /// result would be empty (EventKit prefers nil over an empty string).
    static func rewrittenNotes(_ notes: String?, for status: KanbanStatus) -> String? {
        var text = removingTags(notes ?? "")
        // Runs of blank lines can appear where a tag-only line was removed.
        text.replace(#/\n{3,}/#, with: "\n\n")
        while let last = text.last, last.isWhitespace {
            text.removeLast()
        }
        if let tag = status.tag {
            text = text.isEmpty ? tag : text + "\n" + tag
        }
        return text.isEmpty ? nil : text
    }

    /// Removes all status tags. Only lines that actually contained a tag are
    /// re-tidied (collapsed double spaces, trimmed) — untouched user lines
    /// are preserved character-for-character.
    private static func removingTags(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in
                var cleaned = line
                for regex in allTagRegexes {
                    cleaned.replace(regex, with: "")
                }
                guard cleaned != line else { return line }
                cleaned.replace(#/[ \t]{2,}/#, with: " ")
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
    }
}
