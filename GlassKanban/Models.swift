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
