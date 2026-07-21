import EventKit
import SwiftUI
import AppKit

/// The single data layer of the app. Reads reminders via EventKit, derives
/// `KanbanCard`s, and performs every write the app has: moving a card
/// between columns (rewriting the status hashtag and/or `isCompleted`),
/// editing a ticket's title/notes/due date/priority, tag hygiene, and
/// ticket creation/deletion. All app data lives in Reminders.
@MainActor
final class RemindersStore: ObservableObject {

    enum AccessState {
        case unknown
        case requesting
        case granted
        case denied
    }

    @Published private(set) var accessState: AccessState = .unknown
    @Published private(set) var cards: [KanbanCard] = []
    @Published private(set) var reminderCalendars: [EKCalendar] = []
    @Published private(set) var streakStats = StreakStats()
    /// Cards that were just completed, for the brief "settle" animation —
    /// whether completed here or elsewhere (a shared list on someone else's
    /// device). Cleared automatically shortly after.
    @Published private(set) var recentlyCompletedIDs: Set<String> = []
    /// Card currently being dragged. Observed alongside the drag — the drop
    /// payload is not readable while merely hovering — so a lane can tell
    /// whether a drop would actually move anything.
    @Published private(set) var draggingCardID: String?
    @Published var priorityFilter: PriorityFilter = .all
    @Published var dueFilter: DueFilter = .all
    /// The per-session view of recurring cards. Not persisted itself: it starts
    /// each launch at `defaultRecurringFilter` — the saved preference — and can
    /// be nudged from the find popover for a quick look, falling back to that
    /// preference on the next launch.
    @Published var recurringFilter: RecurringFilter = .hiddenUntilDue
    @Published var searchText: String = ""
    /// Set when a move pushed a limited lane past its WIP limit. Lives here
    /// rather than in the lane view so every route into `move` — drag & drop,
    /// the card's context menu, the VoiceOver action — raises the same
    /// question. A limit that only applies to mouse users is not a limit.
    @Published var pendingOverflow: PendingOverflow?

    /// A card that just pushed its lane past the limit, awaiting an answer.
    struct PendingOverflow: Identifiable {
        let cardID: String
        let origin: KanbanStatus
        let status: KanbanStatus
        var id: String { cardID }
    }

    var streak: Int { streakStats.current }

    /// Calendar identifiers the user excluded in Settings (e.g. a shopping
    /// list). Persisted in UserDefaults; everything else is included.
    @Published var excludedCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(excludedCalendarIDs), forKey: Self.excludedKey)
            scheduleRefresh()
        }
    }

    /// WIP limits per working lane, keyed by `KanbanStatus.rawValue`.
    /// 0 means "no limit" — no separate on/off switch needed. Persisted in
    /// UserDefaults like the excluded lists.
    @Published var wipLimits: [String: Int] {
        didSet {
            UserDefaults.standard.set(wipLimits, forKey: Self.wipLimitsKey)
        }
    }

    /// Whether Backlog hides recurring reminders until they come due — the
    /// board's long-standing default, now a saved preference. `recurringFilter`
    /// starts each launch from this and resets to it, so the board's resting
    /// state stays one thing rather than two. Persisted like the settings above.
    @Published var hideRecurringUntilDue: Bool {
        didSet {
            UserDefaults.standard.set(hideRecurringUntilDue, forKey: Self.hideRecurringKey)
            // A preference change belongs on the board now, not next launch —
            // even if that overrides a look the find popover is currently taking.
            recurringFilter = defaultRecurringFilter
        }
    }

    /// Backlog's resting state for recurring cards, from the saved preference.
    var defaultRecurringFilter: RecurringFilter {
        hideRecurringUntilDue ? .hiddenUntilDue : .alwaysVisible
    }

    private static let excludedKey = "excludedCalendarIDs"
    private static let wipLimitsKey = "wipLimits"
    private static let hideRecurringKey = "hideRecurringUntilDue"

    /// Completed reminders are shown in "Erledigt" for this many days.
    private static let doneWindowDays = 14
    /// How far back completions are fetched for the streak calculation.
    private static let streakWindowDays = 400

    private let eventStore = EKEventStore()
    private var refreshTask: Task<Void, Never>?
    private var midnightTimer: Timer?
    private var hasLoadedOnce = false

    init() {
        excludedCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: Self.excludedKey) ?? [])
        // First launch starts with the recommended limits rather than none:
        // the feature should work without visiting Settings once.
        wipLimits = UserDefaults.standard.dictionary(forKey: Self.wipLimitsKey) as? [String: Int]
            ?? Dictionary(
                uniqueKeysWithValues: KanbanStatus.allCases
                    .filter(\.supportsWIPLimit)
                    .map { ($0.rawValue, $0.defaultWIPLimit) })
        // Hiding unless the user turned it off in Settings on an earlier launch.
        // Assigning in init does not fire the didSet, so seed the session filter
        // here rather than relying on the property's declared placeholder.
        hideRecurringUntilDue = UserDefaults.standard.object(forKey: Self.hideRecurringKey) as? Bool ?? true
        recurringFilter = hideRecurringUntilDue ? .hiddenUntilDue : .alwaysVisible
    }

    // MARK: - WIP limits

    /// The configured limit for a lane, or nil if the lane has none (either
    /// unsupported or explicitly set to 0).
    func wipLimit(for status: KanbanStatus) -> Int? {
        guard status.supportsWIPLimit, let limit = wipLimits[status.rawValue], limit > 0 else {
            return nil
        }
        return limit
    }

    func setWIPLimit(_ limit: Int, for status: KanbanStatus) {
        wipLimits[status.rawValue] = max(0, limit)
    }

    /// Whether a lane currently holds more cards than its limit allows.
    /// Counts what the board actually shows (filters included) so the number
    /// on screen and the rule always agree.
    func isOverWIPLimit(_ status: KanbanStatus) -> Bool {
        guard let limit = wipLimit(for: status) else { return false }
        return cards(for: status).count > limit
    }

    // MARK: - Access & lifecycle

    func start() async {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            accessState = .granted
        case .notDetermined:
            accessState = .requesting
            let granted = (try? await eventStore.requestFullAccessToReminders()) ?? false
            accessState = granted ? .granted : .denied
        default:
            accessState = .denied
        }
        guard accessState == .granted else { return }
        observeChanges()
        observeDayBoundary()
        await refresh()
    }

    /// "Heute", "Überfällig", the sort order and the flame are all relative
    /// to now — but they are only recomputed when data changes. On a board
    /// that stays open for days, that means waking up to yesterday's world,
    /// so the day boundary and returning from sleep force a refresh.
    private func observeDayBoundary() {
        scheduleMidnightRefresh()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleMidnightRefresh()
                self?.scheduleRefresh()
            }
        }
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        // A few seconds past midnight, so the new day has definitely begun.
        guard let nextMidnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime) else { return }

        let timer = Timer(fire: nextMidnight, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleMidnightRefresh()
                await self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: eventStore, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
    }

    /// Debounced refresh — EKEventStoreChanged can fire in bursts.
    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    // MARK: - Reading

    func refresh() async {
        guard accessState == .granted else { return }
        let calendar = Calendar.current

        reminderCalendars = eventStore.calendars(for: .reminder)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let included = reminderCalendars.filter { !excludedCalendarIDs.contains($0.calendarIdentifier) }
        guard !included.isEmpty else {
            cards = []
            streakStats = StreakStats()
            return
        }

        let incompletePredicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: included)
        let completedStart = calendar.date(byAdding: .day, value: -Self.streakWindowDays, to: .now)
        let completedPredicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: completedStart, ending: nil, calendars: included)

        let incomplete = await fetchReminders(matching: incompletePredicate)
        let completed = await fetchReminders(matching: completedPredicate)

        performTagHygiene(on: incomplete + completed)

        streakStats = StreakCalculator.stats(completionDates: completed.compactMap(\.completionDate))

        let doneWindowStart = calendar.date(
            byAdding: .day, value: -Self.doneWindowDays, to: calendar.startOfDay(for: .now))!
        let visibleCompleted = completed.filter { ($0.completionDate ?? .distantPast) >= doneWindowStart }

        let refreshed = (incomplete + visibleCompleted).compactMap(Self.card(from:))

        // Work finished elsewhere (a shared list on another device) gets the
        // same settle animation as our own. Skipped on the very first load,
        // where every completed card would look brand new.
        if hasLoadedOnce {
            let wasDone = Set(cards.filter { $0.status == .done }.map(\.id))
            let isDone = Set(refreshed.filter { $0.status == .done }.map(\.id))
            flagRecentlyCompleted(isDone.subtracting(wasDone))
        }
        cards = refreshed
        hasLoadedOnce = true
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private static func card(from reminder: EKReminder) -> KanbanCard? {
        guard let calendar = reminder.calendar else { return nil }
        return KanbanCard(
            id: reminder.calendarItemIdentifier,
            title: TextSanitizer.displayTitle(reminder.title),
            notesPreview: TextSanitizer.notesPreview(reminder.notes),
            notesExcerpt: TextSanitizer.notesExcerpt(reminder.notes),
            dueDate: reminder.dueDateComponents.flatMap { Foundation.Calendar.current.date(from: $0) },
            priority: reminder.priority,
            status: StatusTagger.status(fromNotes: reminder.notes, isCompleted: reminder.isCompleted),
            listName: calendar.title,
            listColor: Color(nsColor: calendar.color ?? .controlAccentColor),
            completionDate: reminder.completionDate,
            isRecurring: reminder.hasRecurrenceRules,
            lastModifiedDate: reminder.lastModifiedDate)
    }

    /// Data hygiene from the spec: completed reminders keep no stale status
    /// tag, multiple tags are normalized to a single one (last tag wins),
    /// and legacy English tags are migrated to the German ones.
    /// Converges: after one rewrite there is exactly one current-format tag
    /// (or none), so this never causes a save loop via EKEventStoreChanged.
    private func performTagHygiene(on reminders: [EKReminder]) {
        var dirty = false
        for reminder in reminders {
            let needsCleanup = (reminder.isCompleted && StatusTagger.hasStatusTag(reminder.notes))
                || StatusTagger.tagCount(reminder.notes) > 1
                || StatusTagger.hasLegacyTag(reminder.notes)
            guard needsCleanup else { continue }
            let status = StatusTagger.status(fromNotes: reminder.notes, isCompleted: reminder.isCompleted)
            reminder.notes = StatusTagger.rewrittenNotes(reminder.notes, for: status)
            if (try? eventStore.save(reminder, commit: false)) != nil {
                dirty = true
            }
        }
        if dirty {
            try? eventStore.commit()
        }
    }

    // MARK: - Writing

    /// Moves a card to another column. Returns the column it came from if
    /// anything actually changed, so the UI can give feedback (haptics) only
    /// on a real move — and can offer to put the card back.
    @discardableResult
    func move(cardID: String, to status: KanbanStatus) -> KanbanStatus? {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return nil }
        let origin = StatusTagger.status(fromNotes: reminder.notes, isCompleted: reminder.isCompleted)
        guard origin != status else { return nil }

        reminder.notes = StatusTagger.rewrittenNotes(reminder.notes, for: status)
        reminder.isCompleted = (status == .done)
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return nil
        }

        // Optimistic UI update; the EventKit change notification will
        // confirm it with a full refresh shortly after.
        if let index = cards.firstIndex(where: { $0.id == cardID }) {
            cards[index].status = status
            cards[index].completionDate = (status == .done) ? .now : nil
        }
        if status == .done {
            flagRecentlyCompleted([cardID])
        }
        // Asked after the move, never before it: the board does not block a
        // drop, it lets the work land and then offers to put it back.
        if status.asksBeforeExceedingLimit, isOverWIPLimit(status) {
            pendingOverflow = PendingOverflow(cardID: cardID, origin: origin, status: status)
        }
        scheduleRefresh()
        return origin
    }

    /// Creates a content-empty reminder — no title, no notes, hence no status
    /// hashtag — so it appears in Backlog immediately, then hands off editing
    /// to the Reminders app itself (Glass Kanban never authors real content).
    func createBacklogTicket() {
        guard let calendar = targetCalendarForNewTicket() else { return }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return
        }

        scheduleRefresh()

        // Mirrors CardView.openInReminders(): try the deep link, fall back to
        // simply bringing Reminders to the front so the user isn't stranded.
        if let url = ReminderDeepLink.url(for: reminder), NSWorkspace.shared.open(url) {
            return
        }
        openRemindersApp()
    }

    /// `defaultCalendarForNewReminders()`, unless that list is excluded from
    /// the board — then the first included calendar, so the new ticket is
    /// visible immediately. Nil only if there are no reminder calendars at all.
    private func targetCalendarForNewTicket() -> EKCalendar? {
        let includedIDs = reminderCalendars
            .filter { !excludedCalendarIDs.contains($0.calendarIdentifier) }
            .map(\.calendarIdentifier)
        guard let targetID = BacklogTicketTargeting.targetCalendarIdentifier(
            defaultCalendarID: eventStore.defaultCalendarForNewReminders()?.calendarIdentifier,
            excludedIDs: excludedCalendarIDs,
            includedCalendarIDsInDisplayOrder: includedIDs
        ) else { return nil }
        return reminderCalendars.first { $0.calendarIdentifier == targetID }
    }

    /// Deletes a reminder outright, no confirmation — recoverable from
    /// Reminders' own "Zuletzt gelöscht" for a while, same as deleting it
    /// there directly.
    func deleteTicket(cardID: String) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return
        }
        cards.removeAll { $0.id == cardID }
        scheduleRefresh()
    }

    /// Renames a ticket in place. The one piece of content Glass Kanban
    /// writes directly rather than handing off to Reminders — the title is
    /// short, has no formatting, and the round trip via a deep link for a
    /// single-line edit was worse than just doing it.
    func renameTicket(cardID: String, title: String) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        reminder.title = title
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return
        }
        if let index = cards.firstIndex(where: { $0.id == cardID }) {
            cards[index].title = title
        }
        scheduleRefresh()
    }

    /// Working copy for `TicketEditSheet`, read fresh from EventKit rather
    /// than carried on `KanbanCard` — the full notes text is only ever
    /// needed while a sheet is open, not for every card on the board.
    func loadEditableTicket(cardID: String) -> EditableTicket? {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return nil }
        let components = reminder.dueDateComponents
        return EditableTicket(
            title: reminder.title ?? "",
            notes: StatusTagger.removingTags(reminder.notes ?? ""),
            dueDate: components.flatMap { Foundation.Calendar.current.date(from: $0) },
            hasDueTime: components?.hour != nil,
            priority: reminder.priority,
            calendarID: reminder.calendar?.calendarIdentifier ?? "")
    }

    /// Lists a card can be moved to from the edit sheet: writable, and not
    /// hidden from the board — moving a card into an excluded list would
    /// make it vanish, which is not what picking a list should mean.
    var selectableCalendars: [EKCalendar] {
        reminderCalendars.filter {
            $0.allowsContentModifications && !excludedCalendarIDs.contains($0.calendarIdentifier)
        }
    }

    /// Writes back the fields `TicketEditSheet` lets the user touch. The
    /// status hashtag is reapplied for the card's current column — this
    /// method never changes status, `move` does that — so a content edit
    /// can never accidentally relocate the card.
    func updateTicket(
        cardID: String,
        title: String,
        notes: String,
        dueDate: Date?,
        hasDueTime: Bool,
        priority: Int,
        calendarID: String
    ) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder,
              let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        let status = cards[index].status
        let rewrittenNotes = StatusTagger.rewrittenNotes(notes, for: status)
        // Without a time of day the reminder stays all-day, the way Reminders
        // itself models it (see `EditableTicket.hasDueTime`).
        let dueFields: Set<Foundation.Calendar.Component> =
            hasDueTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        let newCalendar = eventStore.calendar(withIdentifier: calendarID)
        reminder.title = title
        reminder.notes = rewrittenNotes
        reminder.dueDateComponents = dueDate.map {
            Foundation.Calendar.current.dateComponents(dueFields, from: $0)
        }
        reminder.priority = priority
        if let newCalendar, newCalendar.calendarIdentifier != reminder.calendar?.calendarIdentifier {
            reminder.calendar = newCalendar
        }
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return
        }
        cards[index].title = title
        cards[index].notesPreview = TextSanitizer.notesPreview(rewrittenNotes)
        cards[index].notesExcerpt = TextSanitizer.notesExcerpt(rewrittenNotes)
        cards[index].dueDate = dueDate
        cards[index].priority = priority
        if let newCalendar {
            cards[index].listName = newCalendar.title
            cards[index].listColor = Color(nsColor: newCalendar.color ?? .controlAccentColor)
        }
        scheduleRefresh()
    }

    /// Marks cards as just-completed for ~0.7 s so their views can play the
    /// settle animation, then clears the flags.
    private func flagRecentlyCompleted(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        recentlyCompletedIDs.formUnion(ids)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            self?.recentlyCompletedIDs.subtract(ids)
        }
    }

    func beginDrag(cardID: String) {
        guard draggingCardID != cardID else { return }
        draggingCardID = cardID
    }

    /// A drag that ends outside any lane leaves this set; that is harmless,
    /// because lanes only read it while a drag is hovering, and the next
    /// drag overwrites it.
    func endDrag() {
        draggingCardID = nil
    }

    /// Opens one reminder in the Reminders app, for everything the board's
    /// own editor deliberately leaves out — recurrence, subtasks,
    /// attachments, location alerts. Deep-links straight to it where that
    /// resolves; local lists have no public identifier to link to (see
    /// `ReminderDeepLink`), so those simply bring the app forward.
    func openInReminders(cardID: String) {
        if let url = deepLinkURL(forCardID: cardID), NSWorkspace.shared.open(url) { return }
        openRemindersApp()
    }

    /// Opens the Reminders app — the fallback when a deep link can't resolve
    /// a specific reminder (e.g. local, non-synced lists), and still the
    /// place list/calendar assignment is managed since the board doesn't
    /// offer that.
    func openRemindersApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Board queries

    func cards(for status: KanbanStatus) -> [KanbanCard] {
        let filtered = cards.filter {
            $0.status == status
                && priorityFilter.matches($0.priority)
                && dueFilter.matches($0.dueDate)
                && recurringFilter.matches($0)
                && $0.matches(search: searchText)
        }
        if status == .done {
            // Finished work reads newest first; priority no longer matters.
            return filtered.sorted { ($0.completionDate ?? .distantPast) > ($1.completionDate ?? .distantPast) }
        }
        return filtered.sorted(by: KanbanCard.openLaneOrder())
    }

    /// Cards this lane holds that only the recurring rule is keeping out of
    /// sight. The lane count states what is visible, so without this the
    /// number would quietly disagree with what the lane actually contains —
    /// and the WIP limit already establishes that a rule affecting a lane
    /// belongs on the board, not only in a popover ("make policies explicit").
    /// Counted against the other filters so a hidden card is only reported
    /// when relaxing *this* rule would really bring it back.
    func recurringHiddenCount(for status: KanbanStatus) -> Int {
        guard recurringFilter == .hiddenUntilDue else { return 0 }
        return cards.filter {
            $0.status == status
                && priorityFilter.matches($0.priority)
                && dueFilter.matches($0.dueDate)
                && $0.matches(search: searchText)
                && !recurringFilter.matches($0)
        }.count
    }

    func resetFilters() {
        priorityFilter = .all
        dueFilter = .all
        recurringFilter = defaultRecurringFilter
        searchText = ""
    }

    // MARK: - Find field

    /// True while the board shows less than everything. The find control wears
    /// this: a board must never be filtered without saying so, or cards look
    /// lost rather than hidden.
    ///
    /// `recurringFilter` deliberately never counts here. Its default hides
    /// cards, but as the board's normal state — badging that would leave the
    /// find control permanently lit, which is precisely the standing
    /// attention-grab this feature exists to avoid. Its other value shows
    /// *more* than the default and is not a restriction either.
    var isFiltering: Bool {
        priorityFilter != .all || dueFilter != .all || !searchText.isEmpty
    }

    /// Active restrictions, for the badge on the collapsed find control.
    var activeRestrictionCount: Int {
        (priorityFilter != .all ? 1 : 0)
            + (dueFilter != .all ? 1 : 0)
            + (searchText.isEmpty ? 0 : 1)
    }

    /// Whether anything in the find popover sits away from its default —
    /// which is a wider question than `isFiltering`, because a recurring value
    /// away from the saved preference is a departure worth being able to undo
    /// without being a restriction. Measured against that preference, so the
    /// reset is not offered for a value that is already the resting one.
    var canResetFindSettings: Bool {
        isFiltering || recurringFilter != defaultRecurringFilter
    }

    // MARK: - Empty board

    /// Why the whole board is blank — the two reasons need different answers,
    /// and a wordless empty window reads as a broken app either way. Nil while
    /// anything is visible; individual empty lanes stay silent (see
    /// ColumnView.showsPullSlot).
    enum Emptiness {
        /// Nothing to show anywhere: no reminders in the chosen lists.
        case nothingToDo
        /// There is work, but the current find settings hide all of it.
        case filteredAway
    }

    var emptiness: Emptiness? {
        guard KanbanStatus.allCases.allSatisfy({ cards(for: $0).isEmpty }) else { return nil }
        return isFiltering ? .filteredAway : .nothingToDo
    }


    /// URL that opens this card's reminder directly in the Reminders app,
    /// or nil if no deep link could be resolved.
    func deepLinkURL(forCardID id: String) -> URL? {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        return ReminderDeepLink.url(for: reminder)
    }
}
