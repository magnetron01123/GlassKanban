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
        case .backlog: String(localized: "Backlog")
        case .next: String(localized: "Next Up")
        case .inProgress: String(localized: "In Progress")
        case .done: String(localized: "Done")
        }
    }

    /// The hashtag written into the reminder notes for this status.
    /// Backlog and Done deliberately have no tag: Backlog means "no tag",
    /// Done is expressed via `isCompleted`.
    var tag: String? {
        switch self {
        case .next: "#next"
        case .inProgress: "#inprogress"
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
    /// Everything about this card that Find should be able to match:
    /// the whole note, not the first three lines the card happens to show,
    /// plus the link. Searching a word that is provably in a reminder and
    /// being told there is no such card is the one thing Find must not do.
    var searchText: String = ""
    var dueDate: Date?
    var priority: Int
    var status: KanbanStatus
    /// Which list this card lives in. The name is what the card shows; the
    /// identifier is what the list filter matches on, because two accounts
    /// may each have a list called "Erinnerungen".
    var listID: String
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
    /// notes the board itself would show. Computed per call — on a personal
    /// board that is a handful of string joins per keystroke, and keeping it
    /// derived means it can never disagree with the fields it comes from.
    var searchHaystack: String { "\(title)\n\(notesExcerpt)\n\(searchText)" }

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

    /// A recurring Backlog card whose next turn has not come round yet.
    ///
    /// Backlog is the pool of options this board could pull from, and a chore
    /// that comes back on its own in three weeks is a weaker option than
    /// anything due now — but it is still an option. It sinks to the foot of
    /// the lane (see `openLaneOrder`) and the lane's fold rests on that line
    /// (see `ColumnView.restingCut`), so it stays one click away at all times.
    ///
    /// This replaced a rule that *hid* such cards until their due date. Kanban
    /// limits how much is in progress, not what may be looked at; a date that
    /// removes a card from the board is a schedule pushing work at you, and it
    /// blocked the one thing the board exists to allow — pulling something
    /// forward because you have capacity today.
    ///
    /// Deliberately only recurring cards. A one-off with a date in October is
    /// a commitment somebody made on purpose, and the due-date sort already
    /// puts it behind nearer work; a recurring one regenerates for ever, which
    /// is what made the pile grow in the first place. Only Backlog, too: a
    /// card already pulled into a working lane is a decision, not an option.
    func isNotYetDue(calendar: Calendar = .current, now: Date = .now) -> Bool {
        guard isRecurring, status == .backlog, dueDate != nil else { return false }
        return !isUrgent(calendar: calendar, now: now)
    }

    /// Order for the open lanes: cards whose turn has not come yet sink to the
    /// bottom, then urgency, then priority, then the earliest due date
    /// (undated cards last), then the oldest ticket, and finally the title so
    /// the order never jitters between refreshes.
    ///
    /// Ripeness outranks priority, and it has to: priority used to win, so a
    /// high-priority monthly chore sat above the errand that was actually due
    /// today. "Important" is not "now", and the foot of the lane is where the
    /// not-yet-now belongs.
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
            let lhsLater = lhs.isNotYetDue(calendar: calendar, now: now)
            let rhsLater = rhs.isNotYetDue(calendar: calendar, now: now)
            if lhsLater != rhsLater {
                return rhsLater
            }
            // Below the ripeness line the calendar ranks alone — urgency and
            // priority are skipped. Nothing down there is urgent by
            // definition, and priority is a way of choosing between things you
            // could start now, which is exactly what these are not. Ranking
            // them by it produced a fold that opened on 1. Dez. above 1. Aug.
            // and read as no order at all; what the reader of a fold labelled
            // "noch nicht fällig" wants is the next turn first.
            if !lhsLater {
                let lhsUrgent = lhs.isUrgent(calendar: calendar, now: now)
                let rhsUrgent = rhs.isUrgent(calendar: calendar, now: now)
                if lhsUrgent != rhsUrgent {
                    return lhsUrgent
                }
                if lhs.priorityRank != rhs.priorityRank {
                    return lhs.priorityRank < rhs.priorityRank
                }
            }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(l), .some(r)) where l != r:
                return l < r
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                // Each side gets a value of its own rather than the pair
                // deciding: comparing only when *both* dates exist made the
                // order intransitive (A before B by title, B before C by
                // date, yet C before A), and an intransitive comparison lets
                // the same cards come out in a different order on every
                // refresh — the very reshuffling the title tie-break exists
                // to prevent. A missing creation date sorts last, where a
                // card of unknown age belongs.
                let lhsCreated = lhs.creationDate ?? .distantFuture
                let rhsCreated = rhs.creationDate ?? .distantFuture
                if lhsCreated != rhsCreated {
                    return lhsCreated < rhsCreated
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

/// The Backlog lane's fold: which cards its resting cut shows, and whether
/// the line hiding the rest may name a single reason for that or must fall
/// back to a plain count.
///
/// Pulled out of `ColumnView` (and unit-testable here, unlike a View's private
/// properties) because getting this wrong is not a cosmetic slip: the fold's
/// whole point is to say what it holds back, and there are two different
/// things it can be holding back — cards not yet due, and ripe cards that
/// simply did not fit under `BacklogFold.collapsedLimit`. A pile long enough
/// to hit both at once must not tell the reader "not due yet" while a ripe
/// card sits in there unmentioned.
enum BacklogFold {
    /// Backlog shows this many cards before offering "N weitere anzeigen".
    ///
    /// Lives here rather than among `Board`'s display constants (like
    /// `DoneWindow.recentDays` before it): `Models.swift` is compiled
    /// standalone into the test bundle, with no app host and no dependency
    /// on `DesignSystem.swift`, and this number gates real behavior that
    /// needs testing (see `BacklogFoldTests`), not just a visual default.
    static let collapsedLimit = 15

    /// Two reasons to fold, in the order they matter. First the meaningful
    /// line: a recurring chore whose turn has not come is not something this
    /// board could pull today, so the resting lane stops there (see
    /// `KanbanCard.isNotYetDue`, which `cards` must already be sorted by —
    /// see `KanbanCard.openLaneOrder`). Then the count cap, for a pile of
    /// ripe cards long enough to be a wall on its own.
    ///
    /// `foldsNotYetDue` switches the first cut off — see
    /// `RemindersStore.foldNotYetDue`, the preference behind it. The count cap
    /// is not optional: it is what keeps a lane from becoming a wall, and it
    /// has no opinion about the work, only about the height of the pile.
    ///
    /// Note that with the first cut off, the tail can still happen to be all
    /// not-yet-due cards (they sort last either way, so a pile just over the
    /// limit spills exactly those). `canNameNotYetDue` then still names them,
    /// and rightly: it describes what the fold actually holds, never why the
    /// cut landed where it did.
    /// The clock is injectable for the same reason `canNameNotYetDue`'s is:
    /// ripeness is a question about *today*, so a test that fixes a date has
    /// to be able to fix this one too. Left on the real `.now` it read the
    /// wall clock, and fixtures written against a fixed date silently began
    /// to fail as actual time moved past them.
    static func restingCut(
        _ cards: [KanbanCard],
        limit: Int = collapsedLimit,
        foldsNotYetDue: Bool = true,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [KanbanCard] {
        // `prefix(while:)` rather than a filter, because the not-yet-due
        // cards really are a tail: `openLaneOrder` sinks them there before
        // anything else it sorts on.
        let ripe = foldsNotYetDue
            ? Array(cards.prefix { !$0.isNotYetDue(calendar: calendar, now: now) })
            : cards
        return Array(ripe.prefix(limit))
    }

    /// Whether every card the fold is holding back is there for the same
    /// reason (not yet due), so the line can name it. False for an empty
    /// fold too — there is nothing to name — and false the moment a single
    /// ripe card is mixed in, which is exactly the case a count cap
    /// introduces: naming only one of two reasons there would misreport
    /// the rest.
    static func canNameNotYetDue(
        folded: [KanbanCard],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Bool {
        !folded.isEmpty && folded.allSatisfy { $0.isNotYetDue(calendar: calendar, now: now) }
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
/// anything is visible; a single empty lane speaks for itself instead (see
/// `ColumnView.showsEmptySlot`, which stands down while this is non-nil).
enum BoardEmptiness: Equatable {
    /// Nothing to show anywhere: no reminders in the chosen lists.
    case nothingToDo
    /// There is work, but the current find settings hide all of it.
    case filteredAway
    /// No list is switched on in Settings, so the board has no source at all.
    /// Distinct from `nothingToDo`: an empty board that means "you chose no
    /// lists" must not be read as "you are finished". Excluding every list
    /// left the board congratulating someone on work it could not see.
    case noListsSelected
    /// There is no reminder list at all on this Mac. Distinct from
    /// `noListsSelected`: telling someone they chose no lists, when there was
    /// never anything to choose, sends them into a settings pane that can
    /// only repeat the bad news.
    case noListsAtAll
    /// The first fetch has not come back yet. Saying anything before then —
    /// "Nichts zu tun", of all things — flashed a verdict on every launch,
    /// and on a large or freshly syncing database it stood for a second.
    case loading

    /// Pure, so the decision can be tested without EventKit.
    ///
    /// There used to be a fourth case, `recurringOnly`, for a board holding
    /// nothing but recurring cards that were not due yet. It went with the
    /// rule that hid them: a card that is only folded away still counts as
    /// visible work, so a board in that state is no longer empty and has
    /// nothing to explain.
    static func evaluate(
        hasVisibleCards: Bool,
        isFiltering: Bool,
        hasSelectedLists: Bool = true,
        hasAnyList: Bool = true,
        hasLoaded: Bool = true
    ) -> BoardEmptiness? {
        guard !hasVisibleCards else { return nil }
        // Before every verdict: an unanswered question is not an answer.
        guard hasLoaded else { return .loading }
        // Ahead of "you chose none": if there is nothing to choose from,
        // the settings pane has nothing to offer either.
        if !hasAnyList { return .noListsAtAll }
        // Ahead of the filter check: with no source, a filter cannot be what
        // is hiding anything.
        if !hasSelectedLists { return .noListsSelected }
        return isFiltering ? .filteredAway : .nothingToDo
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
        case .all: String(localized: "All")
        case .high: String(localized: "High")
        case .medium: String(localized: "Medium")
        case .low: String(localized: "Low")
        case .unset: String(localized: "None")
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
        case .all: String(localized: "All")
        case .overdue: String(localized: "Overdue")
        case .today: String(localized: "Today")
        case .thisWeek: String(localized: "This Week")
        case .noDate: String(localized: "No Date")
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

/// Which lists the board is showing right now — the third filter, and the
/// only one that is a choice of many rather than one of a few.
///
/// It holds what is switched *off*, not what is switched on: the board starts
/// with every list ticked and lists are taken away one at a time. That is what
/// the row is for — "everything except the shared list, just now" — and it
/// keeps the default state empty, so nothing has to be seeded when a list
/// appears in Reminders or is switched on in the settings.
///
/// Its candidates are exactly the lists the settings let onto the board
/// (`RemindersStore.boardCalendars`); the settings decide what belongs here at
/// all, permanently, and this decides what to look at now. It resets with the
/// other two filters and is never saved.
struct ListFilter: Equatable {
    /// Lists the board is currently not showing. Empty — the default — means
    /// every list is ticked.
    private(set) var hiddenIDs: Set<String> = []

    var isUnrestricted: Bool { hiddenIDs.isEmpty }

    /// Whether this list's tick is set.
    func shows(_ listID: String) -> Bool { !hiddenIDs.contains(listID) }

    func matches(_ listID: String) -> Bool { shows(listID) }

    mutating func toggle(_ listID: String) {
        if hiddenIDs.contains(listID) {
            hiddenIDs.remove(listID)
        } else {
            hiddenIDs.insert(listID)
        }
    }

    /// Every list ticked again — the row's way back, and what a reset does.
    mutating func showAll() {
        hiddenIDs.removeAll()
    }

    /// Forgets lists the board no longer draws from — one switched off in the
    /// settings, or gone from Reminders altogether. Without this the filter
    /// would keep a tick-less entry for a list nothing in the UI still offers,
    /// and the row would claim a restriction that hides nothing.
    mutating func retain(_ availableIDs: Set<String>) {
        hiddenIDs.formIntersection(availableIDs)
    }
}
