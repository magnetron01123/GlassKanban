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

/// Display model for one card, derived from an `EKReminder`. `status`/
/// `completionDate`/`title`/`notesPreview`/`notesExcerpt`/`dueDate`/
/// `priority` change locally (optimistic update) until the next EventKit
/// refresh confirms them.
struct KanbanCard: Identifiable, Equatable {
    let id: String
    var title: String
    /// One line, for compact rows and tooltips.
    var notesPreview: String
    /// Several lines, for the roomier cards in the working lanes.
    var notesExcerpt: String
    var dueDate: Date?
    var priority: Int
    var status: KanbanStatus
    var listName: String
    var listColor: Color
    var completionDate: Date?
    let isRecurring: Bool
    /// EventKit's last-modified timestamp. Used as an approximation for
    /// "when did this card enter its column": moving a card rewrites its
    /// notes, which bumps this date. Content edits reset it too — an
    /// accepted trade-off for an ambient board.
    let lastModifiedDate: Date?
    /// EventKit's creation timestamp — when the ticket was first made, and
    /// unlike `lastModifiedDate` it never moves. Used as the stable, fair
    /// tie-breaker in the open lanes (oldest-waiting first) before the title.
    let creationDate: Date?

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
    /// earliest due date (undated cards last), then the oldest ticket, and
    /// finally the title so the order never jitters between refreshes.
    ///
    /// Age before title, because alphabetical was never a *meaning* — it was
    /// only ever there to keep equal cards from swapping places between
    /// refreshes. Among cards of the same priority and due date, the one
    /// that has waited in the pile longest goes first: a queue's fair
    /// default (FIFO), and the thing that stops an old ticket from being
    /// quietly buried under everything added after it. Deliberately the
    /// *creation* date and not `lastModifiedDate` — the latter is bumped by
    /// every move and every edit, so it would reshuffle the lane as a side
    /// effect of touching a card. The title stays as the last word, for
    /// cards that share a creation instant or carry no date at all.
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
                if let l = lhs.creationDate, let r = rhs.creationDate, l != r {
                    return l < r
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

/// The Erledigt lane's two time horizons. At rest the lane shows the last
/// `recentDays` — a week of work standing as evidence, not an archive. One
/// click ("N ältere anzeigen") widens it to `keptDays`, and that is where it
/// ends: anything older is the Reminders app's job, which is the actual
/// store of record and already has search and completion dates. Bounding the
/// look back is what lets the lane stay a flat, headingless stack — a list
/// short enough to scan needs no structure.
enum DoneWindow {
    /// Days shown at rest: today plus the previous seven full days.
    static let recentDays = 7
    /// Days one click can bring back.
    static let keptDays = 30

    /// Start of the resting window.
    static func recentCutoff(calendar: Calendar = .current, now: Date = .now) -> Date {
        cutoff(days: recentDays, calendar: calendar, now: now)
    }

    /// Start of the widened window; also how far back `RemindersStore`
    /// builds cards for completed reminders at all.
    static func keptCutoff(calendar: Calendar = .current, now: Date = .now) -> Date {
        cutoff(days: keptDays, calendar: calendar, now: now)
    }

    /// The cards the lane shows at rest.
    static func recent(
        _ cards: [KanbanCard],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [KanbanCard] {
        let cutoff = recentCutoff(calendar: calendar, now: now)
        return cards.filter { ($0.completionDate ?? .distantPast) >= cutoff }
    }

    private static func cutoff(days: Int, calendar: Calendar, now: Date) -> Date {
        calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))!
    }
}

/// What is being typed on the board right now — a card's title, or the
/// new-ticket row at the foot of Backlog.
///
/// Board-wide rather than local to the view doing the editing, because ending
/// an edit is something that happens *elsewhere*: a click on another lane, or
/// starting a second edit. That click never reaches the view holding the field,
/// and handing the job to AppKit's responder chain
/// (`makeFirstResponder(nil)`) did not survive contact with SwiftUI's own
/// focus handling — the field kept its caret and stayed open.
enum BoardEdit: Equatable {
    case renaming(cardID: String)
}

/// Why the whole board is blank. The reasons need different answers, and a
/// wordless empty window reads as a broken app whichever one it is. Nil while
/// anything is visible; individual empty lanes stay silent (see
/// `ColumnView.showsPullSlot`).
enum BoardEmptiness: Equatable {
    /// Nothing to show anywhere: no reminders in the chosen lists.
    case nothingToDo
    /// There is work, but the current find settings hide all of it.
    case filteredAway
    /// Nothing is filtered and yet nothing shows, because everything the board
    /// holds is a recurring card that is not due yet. Its own case rather than
    /// a second `filteredAway`: the honest answer is neither "you are done"
    /// (untrue) nor "reset your filters" (the filters are already at rest —
    /// the way out is to *widen* the recurring rule, not to reset it).
    case recurringOnly

    /// Pure, so the three-way decision can be tested without EventKit.
    static func evaluate(
        hasVisibleCards: Bool,
        isFiltering: Bool,
        recurringHiddenCount: Int
    ) -> BoardEmptiness? {
        guard !hasVisibleCards else { return nil }
        if isFiltering { return .filteredAway }
        return recurringHiddenCount > 0 ? .recurringOnly : .nothingToDo
    }
}
/// Working copy of a reminder's editable content for `TicketEditSheet`.
/// `notes` has the status hashtag already stripped — the sheet never shows
/// or lets the user touch that control token.
struct EditableTicket: Equatable {
    var title: String
    var notes: String
    /// The reminder's URL field, as text.
    ///
    /// Kept as a string rather than a `URL` because that is what the user
    /// types into: a half-finished address is still worth holding on to
    /// while the editor is open, and only the write back to EventKit — which
    /// takes a real `URL?` — has to decide whether it parses.
    var url: String
    var dueDate: Date?
    /// Whether the due date carries a time of day. Reminders distinguishes
    /// an all-day reminder (date components without hour/minute) from one
    /// due at a specific time, and writing hour/minute unconditionally would
    /// silently turn every all-day reminder into a "due at 00:00" one.
    var hasDueTime: Bool
    /// Raw EventKit scale: 0 = none, 1 = high, 5 = medium, 9 = low.
    var priority: Int
    var calendarID: String
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
///
/// Which of the two the board rests at is the user's to set — see
/// `RemindersStore.hideRecurringUntilDue`, the Settings preference this filter
/// starts from on every launch. The popover row then only borrows it for a look.
enum RecurringFilter: String, CaseIterable, Identifiable {
    /// The factory resting state. The card joins Backlog once it reaches the
    /// same due window `DueFilter` already calls Überfällig / Heute.
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
