import SwiftUI

/// The four fixed board columns. Raw values are stable identifiers,
/// display names are the German column titles from the spec.
enum KanbanStatus: String, CaseIterable, Identifiable {
    case backlog
    case next
    case inProgress
    case done

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backlog: "Backlog"
        case .next: "Als Nächstes"
        case .inProgress: "In Bearbeitung"
        case .done: "Erledigt"
        }
    }

    /// The hashtag written into the reminder notes for this status.
    /// Backlog and Done deliberately have no tag: Backlog means "no tag",
    /// Done is expressed via `isCompleted`.
    var tag: String? {
        switch self {
        case .next: "#alsnächstes"
        case .inProgress: "#inbearbeitung"
        case .backlog, .done: nil
        }
    }

    /// How much a card in this lane reveals. The information gradient is the
    /// board's focus mechanism: the working lanes carry everything, the
    /// backlog carries what you need to decide, and finished work carries
    /// nothing but its name.
    var cardDensity: CardDensity {
        switch self {
        case .next, .inProgress: .full
        case .backlog: .compact
        case .done: .minimal
        }
    }

    /// Lanes that can carry a WIP limit: the two working lanes. Backlog and
    /// Erledigt are deliberately unbounded — one is the standing stack, the
    /// other only grows.
    var supportsWIPLimit: Bool {
        switch self {
        case .next, .inProgress: true
        case .backlog, .done: false
        }
    }

    /// Whether crossing the limit interrupts with a question. Only "In
    /// Bearbeitung": Kanban limits work *in progress*, not what is merely
    /// planned. A full queue is normal planning; too many things started at
    /// once is the expensive mistake. Keeping the interruption to one lane
    /// also keeps the app's only modal nag to a single, justified spot.
    var asksBeforeExceedingLimit: Bool { self == .inProgress }

    /// Default limit for a fresh install. Personal Kanban's rule of thumb for
    /// one person: 2–3 things actually in progress, a slightly roomier queue
    /// that must not become a second backlog.
    var defaultWIPLimit: Int {
        switch self {
        case .inProgress: 3
        case .next: 5
        case .backlog, .done: 0
        }
    }
}

/// Information density of a card, derived from its lane.
enum CardDensity {
    /// Working lanes: title, notes, due date, recurrence, source list.
    case full
    /// Backlog: one line with what you need to triage — priority, date,
    /// recurrence.
    case compact
    /// Erledigt: the title alone. It is done; nothing else matters.
    case minimal

    var isSingleLine: Bool { self != .full }
}

/// Immutable display model for one card, derived from an `EKReminder`.
/// The board never edits content — only `status`/`completionDate` change
/// locally (optimistic update) until the next EventKit refresh.
struct KanbanCard: Identifiable, Equatable {
    let id: String
    let title: String
    /// One line, for compact rows and tooltips.
    let notesPreview: String
    /// Several lines, for the roomier cards in the working lanes.
    let notesExcerpt: String
    let dueDate: Date?
    let priority: Int
    var status: KanbanStatus
    let listName: String
    let listColor: Color
    var completionDate: Date?
    let isRecurring: Bool
    /// EventKit's last-modified timestamp. Used as an approximation for
    /// "when did this card enter its column": moving a card rewrites its
    /// notes, which bumps this date. Content edits reset it too — an
    /// accepted trade-off for an ambient board.
    let lastModifiedDate: Date?

    /// Everything the search looks at, in one place: the title plus whatever
    /// notes the board itself would show. Built once per card rather than
    /// stitched together on every keystroke.
    var searchHaystack: String { "\(title)\n\(notesExcerpt)" }

    /// Whether this card matches a search term. Case- and diacritic-insensitive
    /// like the Reminders app, and forgiving about word order: every word has
    /// to appear somewhere, not as one contiguous phrase.
    func matches(search term: String) -> Bool {
        let words = term.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = searchHaystack
        return words.allSatisfy { haystack.localizedStandardContains($0) }
    }

    /// Reminders-style priority marks: high = "!!!", medium = "!!", low = "!"
    /// (EventKit convention: 1–4 high, 5 medium, 6–9 low, 0 none).
    var priorityMarks: String? {
        switch priority {
        case 1...4: "!!!"
        case 5: "!!"
        case 6...9: "!"
        default: nil
        }
    }

    /// Sort rank for priority. EventKit numbers priorities the other way
    /// round (1 = highest) and uses 0 for "none", which has to sort last.
    var priorityRank: Int {
        switch priority {
        case 1...4: 0
        case 5: 1
        case 6...9: 2
        default: 3
        }
    }

    /// Whole days this card has been sitting in its column (approximated via
    /// `lastModifiedDate`). The card shows it only from `agingThresholdDays`
    /// on — fresh is normal and needs no label; only lingering is a signal.
    func daysInColumn(calendar: Calendar = .current, now: Date = .now) -> Int? {
        guard let lastModifiedDate else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastModifiedDate),
            to: calendar.startOfDay(for: now)).day
    }

    /// Overdue or due today. These float to the top of their lane whatever
    /// their priority: what is due now must not hide beneath work that is
    /// merely important. Matches exactly when the card shows a tinted date
    /// badge, so the rule is visible on the board.
    func isUrgent(calendar: Calendar = .current, now: Date = .now) -> Bool {
        guard let dueDate else { return false }
        return calendar.isDate(dueDate, inSameDayAs: now) || dueDate < calendar.startOfDay(for: now)
    }

    /// Order for the open lanes: urgency first, then priority, then the
    /// earliest due date (undated cards last), then title so the order
    /// never jitters between refreshes.
    static func openLaneOrder(
        calendar: Calendar = .current,
        now: Date = .now
    ) -> (KanbanCard, KanbanCard) -> Bool {
        { lhs, rhs in
            let lhsUrgent = lhs.isUrgent(calendar: calendar, now: now)
            let rhsUrgent = rhs.isUrgent(calendar: calendar, now: now)
            if lhsUrgent != rhsUrgent {
                return lhsUrgent
            }
            if lhs.priorityRank != rhs.priorityRank {
                return lhs.priorityRank < rhs.priorityRank
            }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(l), .some(r)) where l != r:
                return l < r
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

/// Priority filter groups following the EventKit convention:
/// 0 = none, 1–4 = high, 5 = medium, 6–9 = low.
enum PriorityFilter: String, CaseIterable, Identifiable {
    case all
    case high
    case medium
    case low
    case unset

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "Alle"
        case .high: "Hoch"
        case .medium: "Mittel"
        case .low: "Niedrig"
        case .unset: "Keine"
        }
    }

    func matches(_ priority: Int) -> Bool {
        switch self {
        case .all: true
        case .high: (1...4).contains(priority)
        case .medium: priority == 5
        case .low: (6...9).contains(priority)
        case .unset: priority == 0
        }
    }
}

/// Due date filter groups from the spec.
enum DueFilter: String, CaseIterable, Identifiable {
    case all
    case overdue
    case today
    case thisWeek
    case noDate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "Alle"
        case .overdue: "Überfällig"
        case .today: "Heute"
        case .thisWeek: "Diese Woche"
        case .noDate: "Ohne Datum"
        }
    }

    func matches(_ dueDate: Date?, calendar: Calendar = .current, now: Date = .now) -> Bool {
        switch self {
        case .all:
            return true
        case .noDate:
            return dueDate == nil
        case .overdue:
            guard let dueDate else { return false }
            return dueDate < calendar.startOfDay(for: now) && !calendar.isDate(dueDate, inSameDayAs: now)
        case .today:
            guard let dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: now)
        case .thisWeek:
            guard let dueDate else { return false }
            return calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear)
        }
    }
}

/// Whether recurring reminders that are not due yet take up space in Backlog.
///
/// A recurring reminder always carries a *next* due date, so a monthly chore
/// would otherwise sit in Backlog every single day of the month. Backlog is
/// meant to hold what could be pulled next; something that comes back on its
/// own in three weeks is not a decision, it is background noise — and every
/// card that is not a real option makes the ones that are harder to see.
///
/// Unlike the other two filters this one does not rest at "show everything":
/// `hiddenUntilDue` is the board's normal operating mode and `alwaysVisible`
/// is the deviation. It is still a visible row rather than a silent rule,
/// for the same reason the WIP limit rides along in the lane count: a board
/// must be able to say what it is not showing ("make policies explicit").
enum RecurringFilter: String, CaseIterable, Identifiable {
    /// Default. The card joins Backlog once it reaches the same due window
    /// `DueFilter` already calls Überfällig / Heute / Diese Woche.
    case hiddenUntilDue
    case alwaysVisible

    var id: String { rawValue }

    /// Kept short because this row carries the board's longest label:
    /// "Wiederkehrende" plus a wordy value is what pushed the row past the
    /// popover's width twice over (first wrapping the label into a column one
    /// letter wide, then running the menu off the popover's edge).
    var displayName: String {
        switch self {
        case .hiddenUntilDue: "Wenn fällig"
        case .alwaysVisible: "Immer"
        }
    }

    /// The due window a recurring card has to reach before it appears — due
    /// today, or already overdue. Composed from `DueFilter` rather than
    /// restated, so each of those words means one thing in this app.
    ///
    /// This first included the whole calendar week, on the idea that the
    /// week's chores should arrive together on Monday morning. That made the
    /// row lie: a card due Wednesday appeared on Monday, under a filter
    /// labelled "Wenn fällig", and its lead time swung between nought and six
    /// days depending on the weekday. Due means due.
    private static let visibleWindow: [DueFilter] = [.overdue, .today]

    /// Only Backlog ever hides anything. A recurring card the user has
    /// already pulled into a working lane is a decision they made, and a
    /// completed one is a record of work done — neither is ours to hide.
    func matches(_ card: KanbanCard, calendar: Calendar = .current, now: Date = .now) -> Bool {
        switch self {
        case .alwaysVisible:
            return true
        case .hiddenUntilDue:
            guard card.isRecurring, card.status == .backlog else { return true }
            // Without a due date there is no way to tell when it comes round
            // again, so it stays visible rather than disappearing for good.
            guard let dueDate = card.dueDate else { return true }
            return Self.visibleWindow.contains {
                $0.matches(dueDate, calendar: calendar, now: now)
            }
        }
    }
}
