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

    /// Backlog and Done are storage lanes that can hold many items, so their
    /// cards are shown as compact rows. The two working lanes (Als Nächstes,
    /// In Bearbeitung) keep full sticky-note cards and stay the focus — a
    /// card visibly grows when pulled into the work in progress.
    var usesCompactCards: Bool {
        self == .backlog || self == .done
    }
}

/// Immutable display model for one card, derived from an `EKReminder`.
/// The board never edits content — only `status`/`completionDate` change
/// locally (optimistic update) until the next EventKit refresh.
struct KanbanCard: Identifiable, Equatable {
    let id: String
    let title: String
    let notesPreview: String
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
