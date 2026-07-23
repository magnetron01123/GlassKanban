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
    /// The rest of the stats popover. Derived from the same completed
    /// reminders as `streakStats`, in the same pass — statistics never cost
    /// an extra EventKit fetch.
    @Published private(set) var wrappedStats = WrappedStats()
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
    /// The inline edit currently open anywhere on the board (see `BoardEdit`).
    /// Setting it to nil, or to a different edit, ends the previous one.
    @Published var activeEdit: BoardEdit?
    /// Set when a move pushed a limited lane past its WIP limit. Lives here
    /// rather than in the lane view so every route into `move` — drag & drop,
    /// the card's context menu, the VoiceOver action — raises the same
    /// question. A limit that only applies to mouse users is not a limit.
    @Published var pendingOverflow: PendingOverflow?

    /// The card currently open in the editor, if any.
    ///
    /// Here rather than in `CardView`'s own state so exactly one editor can
    /// be open at a time: opening a second card closes the first, instead of
    /// two popovers arguing over the same reminder.
    @Published var editingCardID: String?

    /// A card that just pushed its lane past the limit, awaiting an answer.
    struct PendingOverflow: Identifiable {
        let cardID: String
        let origin: KanbanStatus
        let status: KanbanStatus
        var id: String { cardID }
    }

    /// Set when `updateTicket` fails to save. Board-level like `pendingOverflow`,
    /// not sheet-level: the failure is only known once `eventStore.save` throws,
    /// which happens inside the sheet's own `onDisappear` — by the time this is
    /// set, the sheet that made the edit is already gone. Silently discarding a
    /// multi-field edit (title, notes, due date, priority, list) was fine for
    /// the single-field `renameTicket` this pattern started with; it isn't once
    /// the sheet lets a whole card's content be lost the same quiet way — e.g.
    /// editing a card whose list turned out to be read-only, which `TicketEditSheet`
    /// deliberately keeps reachable rather than hiding.
    @Published var pendingSaveFailure: SaveFailure?

    struct SaveFailure: Identifiable {
        let cardID: String
        let message: String
        var id: String { cardID }
    }

    /// Cards in a lane regardless of search or filters. The lane header counts
    /// what is *visible* (documented intent), but the statistics window states
    /// facts about the system — a Little's-Law estimate fed a filtered load
    /// against an unfiltered throughput would quietly mix two worlds.
    func totalCount(for status: KanbanStatus) -> Int {
        cards.filter { $0.status == status }.count
    }

    /// Calendar identifiers the user excluded in Settings (e.g. a shopping
    /// list). Persisted in UserDefaults; everything else is included.
    ///
    /// Keyed on `calendarIdentifier`, which Apple documents as stable only
    /// within an account's lifetime — a list can come back with a new
    /// identifier after the account is removed and re-added, and would then be
    /// on the board again. Accepted rather than worked around: the alternative
    /// is matching on titles, which change far more often than accounts get
    /// rebuilt, and the recovery here is one toggle in Settings.
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

    /// How far back completions are fetched for the streak calculation. A
    /// streak longer than this would be reported short — deliberately far
    /// beyond any plausible run for a personal board, and the cost of asking
    /// EventKit for more history on every refresh is real.
    private static let streakWindowDays = 400

    private let eventStore = EKEventStore()
    private var refreshTask: Task<Void, Never>?
    private var midnightTimer: Timer?
    private var hasLoadedOnce = false
    private var hasStarted = false
    private var observers: [NSObjectProtocol] = []
    /// Guards against two refreshes interleaving at their `await` points: each
    /// run takes a number, and only the newest one is allowed to publish. Two
    /// runs writing in the order they happen to finish would otherwise be able
    /// to put stale cards on the board.
    private var refreshGeneration = 0

    deinit {
        // Block-based observers are only removed by their token. Without this
        // a store that goes away leaves live blocks behind holding it.
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

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

    /// Runs once per launch, however often the view's `.task` fires (closing
    /// and reopening the window runs it again). Without the guard each run
    /// added another set of notification observers.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        observeActivation()
        await evaluateAccess()
    }

    private func evaluateAccess() async {
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

    /// Access granted in System Settings while the app is already running has
    /// to reach the board. The permission dialog sends the user out of the app
    /// and macOS never tells an app it has been granted access, so coming back
    /// to the window is the moment to look again — otherwise the board sits on
    /// its "no access" screen until the next launch, and the button that sent
    /// the user to System Settings leads nowhere.
    private func observeActivation() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.accessState == .denied else { return }
                guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return }
                await self.evaluateAccess()
            }
        }
        observers.append(observer)
    }

    /// "Heute", "Überfällig", the sort order and the flame are all relative
    /// to now — but they are only recomputed when data changes. On a board
    /// that stays open for days, that means waking up to yesterday's world,
    /// so the day boundary and returning from sleep force a refresh.
    private func observeDayBoundary() {
        scheduleMidnightRefresh()
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleMidnightRefresh()
                self?.scheduleRefresh()
            }
        }
        observers.append(observer)
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
        let observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: eventStore, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
        observers.append(observer)
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
        refreshGeneration += 1
        let generation = refreshGeneration
        let calendar = Calendar.current

        let calendars = eventStore.calendars(for: .reminder)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        // Only publish a genuinely different list. EventKit hands back fresh
        // EKCalendar instances on every call, so assigning unconditionally
        // republished identical data on every refresh — and refresh runs after
        // every write, every EventKit notification, every wake. Each of those
        // relaid out every view observing the store, which is what made the
        // Settings window flicker while it was open.
        if Self.identity(of: calendars) != Self.identity(of: reminderCalendars) {
            reminderCalendars = calendars
        }
        let included = reminderCalendars.filter { !excludedCalendarIDs.contains($0.calendarIdentifier) }
        guard !included.isEmpty else {
            cards = []
            streakStats = StreakStats()
            wrappedStats = WrappedStats()
            return
        }

        let incompletePredicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: included)
        let completedStart = calendar.date(byAdding: .day, value: -Self.streakWindowDays, to: .now)
        let completedPredicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: completedStart, ending: nil, calendars: included)

        let incomplete = await fetchReminders(matching: incompletePredicate)
        let completed = await fetchReminders(matching: completedPredicate)

        // A newer refresh started while these fetches were in flight; it is
        // reading fresher data, so this run stops rather than writing over it.
        guard generation == refreshGeneration else { return }

        performTagHygiene(on: incomplete + completed)

        // The list a finished task came from is thrown away everywhere else —
        // a completed card only needs its title. The stats view is the one
        // place that reads it, so it is captured here rather than fetched again.
        let completionRecords: [CompletionRecord] = completed.compactMap { reminder in
            guard let date = reminder.completionDate, let calendar = reminder.calendar else { return nil }
            return CompletionRecord(
                date: date,
                listName: calendar.title,
                listColor: Color(nsColor: calendar.color ?? .controlAccentColor))
        }
        streakStats = StreakCalculator.stats(completionDates: completionRecords.map(\.date))
        wrappedStats = WrappedStats.stats(records: completionRecords)

        // Cards exist for the widened window; the lane itself rests at the
        // last week and only shows the rest on request (see `DoneWindow`).
        let doneWindowStart = DoneWindow.keptCutoff(calendar: calendar)
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

    /// Everything the UI actually renders from a calendar list: which lists
    /// exist, in which order, under which name and colour. Comparing this
    /// rather than the `EKCalendar` objects themselves is what makes the
    /// equality check above meaningful — the objects are never equal across
    /// two EventKit calls, but a renamed or recoloured list must still reach
    /// the board.
    private static func identity(of calendars: [EKCalendar]) -> [String] {
        calendars.map { calendar in
            let color = calendar.color.map { "\($0.redComponent),\($0.greenComponent),\($0.blueComponent)" } ?? "-"
            return "\(calendar.calendarIdentifier)|\(calendar.title)|\(color)"
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
            guard StatusTagger.needsHygiene(
                notes: reminder.notes, isCompleted: reminder.isCompleted) else { continue }
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
    func move(cardID: String, to status: KanbanStatus, undoManager: UndoManager? = nil) -> KanbanStatus? {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return nil }
        let origin = StatusTagger.status(fromNotes: reminder.notes, isCompleted: reminder.isCompleted)
        guard origin != status else { return nil }
        register(undoManager, name: "Verschieben") { store in
            store.move(cardID: cardID, to: origin, undoManager: undoManager)
        }

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

    /// Creates a Backlog ticket from a title typed on the board.
    ///
    /// The title is the whole of it — everything else (notes, date, priority)
    /// still belongs to Reminders, one click away on the finished card. An
    /// earlier version wrote an *empty* reminder immediately and jumped to
    /// Reminders for the title, which meant abandoning that edit left an
    /// untitled ghost on the board, and the app switch swallowed anything
    /// typed before Reminders had finished coming forward.
    /// The card the "+" just created, still open in the editor. If the editor
    /// closes with the ticket still completely empty, `finalizeNewTicket`
    /// removes it again — abandoning a creation must not leave an untitled
    /// ghost on the board (the failure mode of both earlier creation flows).
    private(set) var newlyCreatedCardID: String?

    /// Creates an empty Backlog ticket and hands its ID to the caller, which
    /// opens the editor on it — creation *is* editing, the same card at
    /// reading size, instead of a bare title row that could hold nothing else.
    func createTicketForEditing(undoManager: UndoManager? = nil) -> String? {
        guard let calendar = targetCalendarForNewTicket() else { return nil }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = ""

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return nil
        }

        let cardID = reminder.calendarItemIdentifier
        newlyCreatedCardID = cardID
        register(undoManager, name: "Ticket anlegen") { store in
            store.deleteTicket(cardID: cardID, undoManager: undoManager)
        }
        // Optimistic, like `move`: the editor opens on this card immediately,
        // it cannot wait out the debounced refresh.
        if let card = Self.card(from: reminder) {
            cards.append(card)
        }
        scheduleRefresh()
        return cardID
    }

    /// Called by the editor as it closes. A brand-new ticket that is still
    /// empty in every field was a creation that got abandoned — it is removed
    /// silently, no undo entry: there is nothing to restore. `keep` is passed
    /// when the close is a jump to Reminders, where the user is clearly about
    /// to fill the ticket in over there.
    func finalizeNewTicket(cardID: String, keep: Bool = false) {
        guard newlyCreatedCardID == cardID else { return }
        newlyCreatedCardID = nil
        guard !keep, let ticket = loadEditableTicket(cardID: cardID) else { return }
        let isEmpty = ticket.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ticket.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ticket.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ticket.dueDate == nil
            && ticket.priority == 0
        guard isEmpty else { return }
        removeNewTicket(cardID: cardID)
    }

    /// Called instead of `finalizeNewTicket` when the editor was left with
    /// Escape. Cancelling the edit of a ticket the "+" just made cancels the
    /// creation itself: whatever was typed was never written (the editor
    /// skips its save on this route), so the reminder is still the empty
    /// placeholder creation left behind — it goes, regardless of what stood in
    /// the fields. For every other card this does nothing: discarding is
    /// simply not saving, and there is nothing to undo.
    func cancelNewTicket(cardID: String) {
        guard newlyCreatedCardID == cardID else { return }
        newlyCreatedCardID = nil
        removeNewTicket(cardID: cardID)
    }

    /// Takes back a creation, silently and with no undo entry — there is
    /// nothing to restore that the user ever put in.
    private func removeNewTicket(cardID: String) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        try? eventStore.remove(reminder, commit: true)
        cards.removeAll { $0.id == cardID }
        scheduleRefresh()
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

    /// Everything needed to put a deleted ticket back. EventKit has no
    /// undelete, so restoring writes a fresh reminder carrying the same
    /// content — which is what Reminders' own "Zuletzt gelöscht" does too.
    /// The new reminder gets a new identifier; nothing on the board depends on
    /// the old one surviving.
    struct DeletedTicket {
        let calendarID: String
        let title: String?
        let notes: String?
        let url: URL?
        let location: String?
        let priority: Int
        let dueDateComponents: DateComponents?
        let startDateComponents: DateComponents?
        let isCompleted: Bool
        let completionDate: Date?
        let recurrenceRules: [EKRecurrenceRule]?
        let alarms: [EKAlarm]?
    }

    /// Deletes a ticket without asking, and registers the undo that puts it
    /// back. A confirmation sheet would tax every deletion to guard against
    /// the rare wrong one; ⌘Z charges only the person who actually made the
    /// mistake, and is what a Mac user reaches for anyway.
    func deleteTicket(cardID: String, undoManager: UndoManager? = nil) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        let snapshot = DeletedTicket(
            calendarID: reminder.calendar.calendarIdentifier,
            title: reminder.title,
            notes: reminder.notes,
            url: reminder.url,
            location: reminder.location,
            priority: reminder.priority,
            dueDateComponents: reminder.dueDateComponents,
            startDateComponents: reminder.startDateComponents,
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate,
            recurrenceRules: reminder.recurrenceRules,
            alarms: reminder.alarms)
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return
        }
        register(undoManager, name: "Ticket löschen") { store in
            store.restoreTicket(snapshot, undoManager: undoManager)
        }
        cards.removeAll { $0.id == cardID }
        scheduleRefresh()
    }

    /// Writes a deleted ticket back, and registers the redo that removes it
    /// again — so ⌘Z / ⇧⌘Z can be pressed as often as the user likes.
    @discardableResult
    func restoreTicket(_ snapshot: DeletedTicket, undoManager: UndoManager? = nil) -> String? {
        guard let calendar = reminderCalendars.first(where: { $0.calendarIdentifier == snapshot.calendarID })
                ?? eventStore.defaultCalendarForNewReminders() else { return nil }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = snapshot.title ?? ""
        reminder.notes = snapshot.notes
        reminder.url = snapshot.url
        reminder.location = snapshot.location
        reminder.priority = snapshot.priority
        reminder.dueDateComponents = snapshot.dueDateComponents
        reminder.startDateComponents = snapshot.startDateComponents
        reminder.recurrenceRules = snapshot.recurrenceRules
        reminder.alarms = snapshot.alarms
        // Order matters: setting `isCompleted` stamps `completionDate` with
        // now, so the original date has to be restored after it — the streak
        // counts those dates, and a restored card must not claim today.
        reminder.isCompleted = snapshot.isCompleted
        if snapshot.isCompleted {
            reminder.completionDate = snapshot.completionDate
        }

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return nil
        }

        let cardID = reminder.calendarItemIdentifier
        register(undoManager, name: "Ticket löschen") { store in
            store.deleteTicket(cardID: cardID, undoManager: undoManager)
        }
        scheduleRefresh()
        return cardID
    }

    /// The title exactly as stored in Reminders — what an edit has to start
    /// from. `KanbanCard.title` is the display form with URLs stripped, and
    /// committing that back would delete them (see `TicketRename`).
    func storedTitle(forCardID id: String) -> String? {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        return reminder.title
    }

    /// Renames a ticket in place. The one piece of content Glass Kanban
    /// writes directly rather than handing off to Reminders — the title is
    /// short, has no formatting, and the round trip via a deep link for a
    /// single-line edit was worse than just doing it.
    func renameTicket(cardID: String, title: String, undoManager: UndoManager? = nil) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        let previousTitle = reminder.title ?? ""
        reminder.title = title
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return
        }
        register(undoManager, name: "Umbenennen") { store in
            store.renameTicket(cardID: cardID, title: previousTitle, undoManager: undoManager)
        }
        if let index = cards.firstIndex(where: { $0.id == cardID }) {
            // The card carries the display form, so the optimistic update has
            // to go through the same sanitizer the refresh would apply.
            cards[index].title = TextSanitizer.displayTitle(title)
        }
        scheduleRefresh()
    }

    /// Registers the inverse of a write with the window's undo manager.
    ///
    /// Every board write goes through here, so ⌘Z means the same thing
    /// wherever it is pressed. The handler runs on the main thread — that is
    /// where the undo manager posted from — which is what lets it call back
    /// into this main-actor store.
    private func register(
        _ undoManager: UndoManager?,
        name: String,
        _ undo: @escaping (RemindersStore) -> Void
    ) {
        guard let undoManager else { return }
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated { undo(store) }
        }
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
            url: reminder.url?.absoluteString ?? "",
            dueDate: components.flatMap { Foundation.Calendar.current.date(from: $0) },
            hasDueTime: components?.hour != nil,
            priority: reminder.priority,
            calendarID: reminder.calendar?.calendarIdentifier ?? "")
    }

    /// Turns what was typed in the URL field into what EventKit stores.
    ///
    /// `URL(string:)` is permissive enough for the way people actually write
    /// addresses — "example.com" parses and round-trips unchanged, so a
    /// scheme is not forced onto text the user did not write one into. An
    /// empty field clears the reminder's URL rather than leaving a stale one
    /// behind. Text that is not an address at all (anything with a space)
    /// does not parse and therefore is not stored; the field is labelled URL
    /// and Reminders has nowhere else to put it.
    private static func parsedURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
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
        url: String,
        dueDate: Date?,
        hasDueTime: Bool,
        priority: Int,
        calendarID: String,
        undoManager: UndoManager? = nil
    ) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder,
              let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        // The inverse write, captured before anything is touched — the same
        // shape the editor itself reads, so ⌘Z is one updateTicket back.
        if let previous = loadEditableTicket(cardID: cardID) {
            register(undoManager, name: "Bearbeiten") { store in
                store.updateTicket(
                    cardID: cardID,
                    title: previous.title,
                    notes: previous.notes,
                    url: previous.url,
                    dueDate: previous.dueDate,
                    hasDueTime: previous.hasDueTime,
                    priority: previous.priority,
                    calendarID: previous.calendarID,
                    undoManager: undoManager)
            }
        }
        // Read from the reminder itself, not the cached `cards[index].status`:
        // the sheet can sit open long enough for an external change (another
        // device, a direct edit in Reminders.app) to move the card before
        // this save runs. Using the stale cache here would silently reapply
        // the old column's tag over whatever the live state already is.
        let status = StatusTagger.status(fromNotes: reminder.notes, isCompleted: reminder.isCompleted)
        let rewrittenNotes = StatusTagger.rewrittenNotes(notes, for: status)
        // Without a time of day the reminder stays all-day, the way Reminders
        // itself models it (see `EditableTicket.hasDueTime`).
        let dueFields: Set<Foundation.Calendar.Component> =
            hasDueTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        let newCalendar = eventStore.calendar(withIdentifier: calendarID)
        reminder.title = title
        reminder.notes = rewrittenNotes
        reminder.url = Self.parsedURL(url)
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
            pendingSaveFailure = SaveFailure(cardID: cardID, message: error.localizedDescription)
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

    var emptiness: BoardEmptiness? {
        BoardEmptiness.evaluate(
            hasVisibleCards: KanbanStatus.allCases.contains { !cards(for: $0).isEmpty },
            isFiltering: isFiltering,
            recurringHiddenCount: KanbanStatus.allCases.reduce(0) { $0 + recurringHiddenCount(for: $1) })
    }

    /// Shows the recurring cards the default is holding back — the action the
    /// board offers when that rule is the only thing between it and its cards.
    func showRecurringCards() {
        recurringFilter = .alwaysVisible
    }


    /// URL that opens this card's reminder directly in the Reminders app,
    /// or nil if no deep link could be resolved.
    func deepLinkURL(forCardID id: String) -> URL? {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        return ReminderDeepLink.url(for: reminder)
    }
}
