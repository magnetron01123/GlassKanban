import EventKit
import SwiftUI
import AppKit
import os

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
    /// Cards just pulled into "In Bearbeitung" — the quieter cousin of
    /// `recentlyCompletedIDs`, for the small snap-into-the-slot settle.
    /// Local pulls only: completing is *the* event and echoes even from
    /// other devices, but a pull is feedback on this hand's own gesture.
    @Published private(set) var recentlyPulledIDs: Set<String> = []
    /// Card currently being dragged. Observed alongside the drag — the drop
    /// payload is not readable while merely hovering — so a lane can tell
    /// whether a drop would actually move anything.
    @Published private(set) var draggingCardID: String?

    /// The card the user last placed by hand, so the lane it landed in can
    /// make sure it is actually visible there (see `ColumnView`). Cleared
    /// right after, because it marks an event, not a state.
    @Published private(set) var lastLandedCardID: String?
    /// Measured height of the top card in "Als Nächstes", reported by that
    /// lane as it lays out. The empty "In Bearbeitung" lane sizes its pull
    /// slot with it, so the promised spot is exactly as tall as the ticket
    /// it is inviting — both lanes render cards at the same full density,
    /// so the ticket keeps this height when it lands. Nil while "Als
    /// Nächstes" is empty; the slot then falls back to the standard card
    /// metrics.
    @Published var nextTopCardHeight: CGFloat?
    @Published var priorityFilter: PriorityFilter = .all
    @Published var dueFilter: DueFilter = .all
    /// Which lists the board is narrowed to right now — empty means all of
    /// them (see `ListFilter`). Not persisted, like the two above it.
    @Published var listFilter = ListFilter()
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

    /// Open reminders that carry a recurrence rule, captured by the last
    /// refresh. Used to recognise the series behind a completed occurrence
    /// (see `liveRecurringSibling`); not published, because nothing draws it.
    private var openRecurringReminders: [EKReminder] = []

    /// Card ids that stopped meaning what the undo stack thinks they mean,
    /// because a repeating card was completed through them (see
    /// `RecurringHandoff`). Not published: it changes nothing that is drawn,
    /// it only decides which replayed writes are allowed to land.
    private var recurringHandoff = RecurringHandoff()

    /// Position of the newest board write, handed to undo entries and to the
    /// handoff so both speak of the same order (see `RecurringHandoff`).
    private var writeOrder = RecurringHandoff.Generation.first

    /// Identifiers the user moved themselves since the last completed
    /// refresh. A pull made in the window between an external completion
    /// syncing in and the refresh seeing it must stay a pull (see
    /// `RecurringTagRelease`, condition 5). Working-lane pulls additionally
    /// land in the persisted release memory (see `move`), which is what
    /// protects them across restarts.
    private var deliberatelyMovedSinceRefresh: Set<String> = []

    /// How many cards may be answered in one refresh. The measured attack
    /// touched six records in thirty hours; a restored preferences file could
    /// match hundreds at once. The rest simply wait for the next refresh.
    private static let maxAnsweredCardsPerRefresh = 5

    /// One line per automatic write — field, card, reason. Invisible to the
    /// user (Console only), and the only way a false positive could ever be
    /// proven rather than argued about.
    private static let correctionLog = Logger(
        subsystem: "com.davidtrogemann.GlassKanban", category: "corrections")

    /// What the board wrote over what, per field. Every write it makes on its
    /// own initiative asks this first — see `CorrectionLedger` for the rule
    /// and the measurement behind it.
    private var corrections = CorrectionLedger.load()

    /// What was last written to disk, so an unchanged ledger is not rewritten
    /// on every single refresh.
    private var lastSavedCorrections = CorrectionLedger.load()

    /// The release rule's persisted memory: when each series was last pulled
    /// on this board, and since when the standing rule has been counting.
    /// Written when the user pulls (see `move`) and pinned once on the first
    /// refresh, so a completion during downtime is still weighed correctly
    /// after a cold start.
    private var releaseMemory = RecurringTagRelease.Memory.load()

    /// Which card sits in which working lane — the board's own record, in the
    /// board's own file (see `ColumnState`). Since 13.08.2026 this, and not
    /// the hashtag in the reminder's notes, is what puts a card in a column.
    private var columns = ColumnState.loadFromKnownLocations()

    /// What was last written to disk, so an unchanged state is not rewritten
    /// on every refresh — the same guard `lastSavedCorrections` provides.
    ///
    /// Read from wherever the state came from, not from where it will be
    /// written: on the launch that moves the file, both are the same value,
    /// and the first change writes it to the new place.
    private var lastSavedColumns = ColumnState.loadFromKnownLocations()

    private let columnsURL = ColumnState.defaultFileURL()

    /// One line per failed write to the column file. There is deliberately no
    /// dialog: the pull the user just made is already live on screen, and this
    /// board may never put a message about its own storage in front of
    /// somebody who dragged a card. The next write tries again.
    private static let storageLog = Logger(
        subsystem: "com.davidtrogemann.GlassKanban", category: "storage")

    /// Writes the column state if it changed. The single place that touches
    /// the file, and always *after* any EventKit save it belongs to: a
    /// completion that failed to save must not leave the lane cleared.
    private func persistColumns() {
        guard columns != lastSavedColumns else { return }
        if columns.save(to: columnsURL) {
            lastSavedColumns = columns
        } else {
            Self.storageLog.error("column state not written — retrying on the next change")
        }
    }

    struct SaveFailure: Identifiable {
        let cardID: String
        /// What did not happen, in the user's words — "Not Moved" for
        /// a refused move, not the blanket "Not Saved" that only fits
        /// an edit. A read-only shared list refuses every write the same way;
        /// the alert has to say which one it was.
        let title: String
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

    /// Whether completing a task makes the quiet tick (see `MoveFeedback`).
    /// On by default — it is the reward the completion moment is for — and
    /// switchable in Settings, because an ambient board that suddenly makes
    /// noise must offer the off switch in the obvious place.
    @Published var completionSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(completionSoundEnabled, forKey: Self.completionSoundKey)
        }
    }

    /// Whether Backlog's fold rests at the ripeness line — i.e. whether a
    /// recurring card whose next turn has not come sits behind the fold line
    /// rather than in the resting pile (see `BacklogFold.restingCut`).
    ///
    /// On by default. Backlog is the pool of options this board could pull
    /// *now*, and a chore that comes round in three weeks is not one of them;
    /// a resting board that shows what is actually pullable is both the
    /// calmer and the more Kanban-honest one. The switch exists because the
    /// backlog is where people's workflows differ most — some want the whole
    /// pool in view and do their own triage — and unlike the rule this
    /// replaced, *neither* position hides anything: both fold, both count,
    /// both are one click from the full pile.
    ///
    /// Off, only the count cap folds. That cap is not switchable: it has no
    /// opinion about the work, only about a lane tall enough to become a wall.
    @Published var foldNotYetDue: Bool {
        didSet {
            UserDefaults.standard.set(foldNotYetDue, forKey: Self.foldNotYetDueKey)
        }
    }

    private static let excludedKey = "excludedCalendarIDs"
    private static let wipLimitsKey = "wipLimits"
    private static let completionSoundKey = "completionSoundEnabled"
    private static let foldNotYetDueKey = "foldNotYetDue"

    /// How far back completions are fetched for the streak calculation. A
    /// streak longer than this would be reported short — deliberately far
    /// beyond any plausible run for a personal board, and the cost of asking
    /// EventKit for more history on every refresh is real.
    private static let streakWindowDays = 400

    private let eventStore = EKEventStore()
    private var refreshTask: Task<Void, Never>?

    /// Wakes the store when an answer the cooldown deferred comes due (see
    /// `scheduleCooldownWakeUp`). Nothing else would: a state that stays
    /// wrong produces no change notification.
    private var cooldownTask: Task<Void, Never>?
    private var midnightTimer: Timer?
    private var hasLoadedOnce = false
    private var hasStarted = false
    private var observers: [NSObjectProtocol] = []
    /// Guards against two refreshes interleaving at their `await` points: each
    /// run takes a number, and only the newest one is allowed to publish. Two
    /// runs writing in the order they happen to finish would otherwise be able
    /// to put stale cards on the board.
    private var refreshGeneration = 0

    /// Counts every write the board makes. A refresh reads it before its
    /// fetches and discards its result if it changed in the meantime: those
    /// fetches then predate the write and would publish a board without it,
    /// undoing the optimistic update. Visible as a card that jumps back to
    /// where it came from and forward again a moment later — or, for a new
    /// ticket, as the editor closing by itself mid-typing.
    private var writeGeneration = 0

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
        completionSoundEnabled = UserDefaults.standard.object(forKey: Self.completionSoundKey) as? Bool ?? true
        foldNotYetDue = UserDefaults.standard.object(forKey: Self.foldNotYetDueKey) as? Bool ?? true
        copyColumnsToCurrentLocationIfNeeded()
    }

    /// Writes the column state to where it now belongs, when it was read from
    /// somewhere older (see `ColumnState.knownFileURLs`).
    ///
    /// On launch rather than on the first drag: a separate process that reads
    /// this file — the planned widget, an App Intent — would otherwise find
    /// nothing until the user happens to move a card.
    ///
    /// The old file is left exactly where it is. Nothing here deletes; that is
    /// a later, separate step (BACKLOG.md, "Aufräumen der alten Speicherorte")
    /// so that a build going back to the old location still finds its board,
    /// and so that a move that goes wrong costs nothing.
    private func copyColumnsToCurrentLocationIfNeeded() {
        guard let target = columnsURL,
              !FileManager.default.fileExists(atPath: target.path),
              columns != ColumnState()
        else { return }
        if columns.save(to: target) {
            Self.storageLog.notice("column state copied to its current location")
        } else {
            // Not fatal: the old file is still there and still readable, so
            // the board works. The next write tries again.
            Self.storageLog.error("column state could not be copied to its current location")
        }
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
    ///
    /// Counts the whole lane, not the filtered view. Begun work is begun
    /// whether or not a filter happens to be hiding it, and a limit that a
    /// view setting can switch off is not a limit — with a list filtered out,
    /// a lane at 3/3 silently accepted a fourth and fifth card. The lane
    /// header keeps showing the filtered figure, since that is what is on
    /// screen; when the two disagree, the rule follows the board, not the
    /// view (decision 10.08.2026, see SPEC.md).
    func isOverWIPLimit(_ status: KanbanStatus) -> Bool {
        guard let limit = wipLimit(for: status) else { return false }
        return totalCount(for: status) > limit
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
                guard let self else { return }
                let isAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
                switch (self.accessState, isAuthorized) {
                case (.denied, true):
                    await self.evaluateAccess()
                case (.granted, false):
                    // The other direction, which used to be unreachable: the
                    // guard only ever looked for access being *given*, so a
                    // permission taken away in System Settings while the app
                    // ran left `accessState` on `.granted` forever. EventKit
                    // then simply returned no lists, the board emptied, and it
                    // announced "Nichts zu tun" — telling someone their work
                    // is finished because the app was locked out of it.
                    self.accessState = .denied
                    self.cards = []
                default:
                    break
                }
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

    /// Records that the board just wrote, then schedules the refresh that
    /// confirms it. The counter is what lets a refresh whose fetches predate
    /// the write recognise itself as stale (see `writeGeneration`).
    private func scheduleRefreshAfterWrite() {
        writeGeneration += 1
        scheduleRefresh()
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
        let writesBefore = writeGeneration
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
        let included = boardCalendars
        // A list the board no longer draws from cannot stay in the filter —
        // it would go on hiding cards with nothing left in the popover to
        // switch it off again.
        let includedIDs = Set(included.map(\.calendarIdentifier))
        if !listFilter.isUnrestricted {
            listFilter.retain(includedIDs)
        }
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
        // A write landed while these fetches were in flight, so they are
        // older than the board. The write scheduled its own refresh; this one
        // steps aside rather than publishing a state the user already changed.
        guard writesBefore == writeGeneration else { return }

        // One read-only pass that books, one pure decision, one writing pass
        // with a single save per card. De-duplicated first: the two fetches
        // are timed independently, so a reminder ticked off between them
        // appears in both — and a write pass over the raw list could save the
        // stale open instance over the completed record and take a
        // completion away.
        let fetched = Self.deduplicated(incomplete + completed)
        // Before anything reads a column: lists whose old hashtags have not
        // been taken over yet hand them over now. Runs before the cards are
        // built, or the board would flash entirely in Backlog once.
        importColumnsFromTags(fetched, lists: included)
        // A card that got finished anywhere gives its lane back. Completion is
        // the one column EventKit owns, so the board's own record must not go
        // on claiming a pull beside it — otherwise un-ticking the task in
        // Reminders would return it to a working lane nobody pulled it into.
        // This is what the tag hygiene used to do by refusing to leave a tag
        // on a completed reminder.
        for reminder in fetched where reminder.isCompleted {
            columns.release(reminder.calendarItemIdentifier, at: .now)
        }
        // A pull the series has already spent gives its lane back — the same
        // standing rule as before, now written into the board's own record
        // instead of into somebody's notes. No pacing, no undo fence, no
        // regard for write permissions: nothing outside this app is touched.
        for seriesID in releasedSeriesIDs(incomplete: incomplete, completed: completed) {
            columns.release(seriesID, at: .now)
        }
        applyCorrections(fetched)

        // The list a finished task came from is thrown away everywhere else —
        // a completed card only needs its title. The stats view is the one
        // place that reads it, so it is captured here rather than fetched again.
        //
        // Recurrence needs a detour, measured on a real board: completing a
        // repeating reminder detaches the finished occurrence from its
        // series, so `hasRecurrenceRules` is false on exactly the records
        // fetched here — while `creationDate` still points at the day the
        // *series* was set up, years ago for a standing chore. The series
        // itself, though, lives on in the incomplete fetch, and the detached
        // copy carries that series' `creationDate` bit for bit (measured
        // 10.08.2026, see CONCEPT.md) — which is how an occurrence is told from
        // an ordinary task that merely shares its name, and what keeps those
        // series creation dates out of the lead-time median (see
        // `CompletionRecord.isRecurring` and `RecurringSeriesMatch`).
        let openRecurring = incomplete.filter(\.hasRecurrenceRules)
        openRecurringReminders = openRecurring
        let openRecurringRecords = openRecurring.map(Self.matchRecord)
        let completionRecords: [CompletionRecord] = completed.compactMap { reminder in
            guard let date = reminder.completionDate, let calendar = reminder.calendar else { return nil }
            return CompletionRecord(
                date: date,
                created: reminder.creationDate,
                isRecurring: reminder.hasRecurrenceRules
                    || RecurringSeriesMatch.seriesID(
                        of: Self.matchRecord(reminder), among: openRecurringRecords) != nil,
                listName: calendar.title,
                listColor: Color(nsColor: calendar.color ?? .controlAccentColor))
        }
        streakStats = StreakCalculator.stats(completionDates: completionRecords.map(\.date))
        wrappedStats = WrappedStats.stats(records: completionRecords)

        // Cards exist for the widened window; the lane itself rests at the
        // last week and only shows the rest on request (see `DoneWindow`).
        let doneWindowStart = DoneWindow.keptCutoff(calendar: calendar)
        let visibleCompleted = completed.filter { ($0.completionDate ?? .distantPast) >= doneWindowStart }

        // De-duplicated by identifier, later wins. The two fetches above are
        // timed independently: a reminder ticked off between them matches the
        // incomplete predicate in the first and the completed one in the
        // second, and would reach the board twice under the same id — which
        // SwiftUI answers with blank rows and broken transitions, not with an
        // error. "Later wins" is also the right answer on content: the
        // completed fetch is the fresher read.
        // A finished turn somebody re-opened elsewhere is not a second card —
        // the series standing right beside it already carries the next turn.
        // Dragging one out of Erledigt is refused here with exactly that
        // reasoning, so displaying the same thing when the click happened in
        // Reminders would mean forbidding ourselves what we then show. The
        // record is left untouched in EventKit; only this board declines to
        // draw it (see `RecurringSeriesMatch.revivedOccurrenceIDs`).
        let revived = RecurringSeriesMatch.revivedOccurrenceIDs(
            among: incomplete.map(Self.matchRecord))

        let drawable: [EKReminder] = (incomplete + visibleCompleted)
            .filter { !revived.contains($0.calendarItemIdentifier) }
        var seen: Set<String> = []
        let refreshed: [KanbanCard] = drawable
            .reversed()
            .compactMap { seen.insert($0.calendarItemIdentifier).inserted ? card(from: $0) : nil }
            .reversed()

        // Work finished elsewhere (a shared list on another device) gets the
        // same settle animation as our own. Skipped on the very first load,
        // where every completed card would look brand new.
        if hasLoadedOnce {
            let wasDone = Set(cards.filter { $0.status == .done }.map(\.id))
            let isDone = Set(refreshed.filter { $0.status == .done }.map(\.id))
            flagRecentlyCompleted(isDone.subtracting(wasDone))
        }
        cards = refreshed
        // Bounded by count, not by the board: a series whose list is switched
        // off in Settings leaves the refresh while its undo entries stay on
        // the stack, and dropping the fence there let exactly the measured
        // write land.
        recurringHandoff.retain()
        deliberatelyMovedSinceRefresh.removeAll()
        // The release memory changes only when the user pulls (see `move`),
        // but its `activeSince` must be pinned on the very first refresh of
        // the first session with this rule: left unsaved, every launch would
        // start counting anew and a completion between two launches would
        // never become evidence.
        if !hasLoadedOnce {
            releaseMemory.save()
        }
        // Kept across launches: the writer this defends against works on a
        // scale of tens of minutes, and the app may well be quit in between.
        // Whatever this refresh changed about the columns — a completion
        // giving its lane back, an import — reaches the file here, in one
        // write.
        persistColumns()
        corrections.retain(now: .now)
        if corrections != lastSavedCorrections {
            lastSavedCorrections = corrections
            corrections.save()
        }
        // An answer the cooldown deferred has to be given eventually, and
        // nothing else would ever ask: a sync runs when the data changes, and
        // a state that is simply *staying* wrong changes nothing. So the
        // store wakes itself once the cooldown is up. The chain ends by
        // itself — either the answer sticks, or the entry goes stale.
        scheduleCooldownWakeUp()
        hasLoadedOnce = true
    }

    /// Schedules the refresh that will give an answer the cooldown deferred.
    private func scheduleCooldownWakeUp() {
        cooldownTask?.cancel()
        guard let due = corrections.nextAnswerDue(now: .now) else { return }
        cooldownTask = Task { [weak self] in
            // A second of slack so the wake-up lands past the boundary, not
            // exactly on it.
            try? await Task.sleep(for: .seconds(due + 1))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    /// One reminder per identifier, later wins — the same rule the card
    /// build uses, and for the same reason.
    private static func deduplicated(_ reminders: [EKReminder]) -> [EKReminder] {
        var seen: Set<String> = []
        return reminders.reversed()
            .filter { seen.insert($0.calendarItemIdentifier).inserted }
            .reversed()
    }

    /// The protected values of a reminder, as the ledger compares them.
    private static func state(of reminder: EKReminder) -> CorrectionLedger.CardState {
        CorrectionLedger.CardState(
            title: reminder.title,
            notes: reminder.notes,
            url: reminder.url?.absoluteString,
            due: reminder.dueDateComponents.flatMap { Foundation.Calendar.current.date(from: $0) },
            hasDueTime: reminder.dueDateComponents?.hour != nil,
            isCompleted: reminder.isCompleted,
            isRecurring: reminder.hasRecurrenceRules)
    }

    /// Hands the old hashtag form over to the board's own record, once per
    /// list.
    ///
    /// **Per list, not per installation.** A single "migration done" flag
    /// would be set after the first refresh, and that refresh does not see
    /// everything: a list switched off in Settings, an account that syncs in
    /// minutes later, a machine that starts offline. Their tags would be lost
    /// for good, and every card in them would rest in Backlog with no way back
    /// but a drag. Stamped per list, each one is taken over the first time it
    /// appears, whenever that is.
    ///
    /// **This is not the rejected hybrid.** The tags are read exactly once per
    /// list and never again; a permanent import channel would hand a foreign
    /// writer back the very lever this change removes.
    private func importColumnsFromTags(_ reminders: [EKReminder], lists: [EKCalendar], now: Date = .now) {
        let pending = lists.filter { !columns.hasImported(listID: $0.calendarIdentifier) }
        guard !pending.isEmpty else { return }
        let pendingIDs = Set(pending.map(\.calendarIdentifier))
        var taggedByList: [String: Set<String>] = [:]
        for reminder in reminders {
            guard let listID = reminder.calendar?.calendarIdentifier,
                  pendingIDs.contains(listID)
            else { continue }
            let cardID = reminder.calendarItemIdentifier
            // Every record carrying a tag right now — completed ones too, so
            // the cleanup below reaches them — is named here and nowhere else.
            // That naming is what keeps the cleanup from ever touching a word
            // the user types later (see `ColumnState.pendingTagCleanup`).
            //
            // Except on a list the board may not write to: its tags can never
            // be cut, so naming them would leave entries that outlive every
            // attempt and quietly deny the promise that an empty list means
            // the migration is over. Their text stays as it is, which is the
            // right answer anyway — it belongs to whoever owns that list.
            if reminder.calendar?.allowsContentModifications == true,
               StatusTagger.hasStatusTag(reminder.notes) {
                taggedByList[listID, default: []].insert(cardID)
            }
            guard !reminder.isCompleted else { continue }
            let status = StatusTagger.status(fromNotes: reminder.notes, isCompleted: false)
            guard let lane = ColumnState.Lane(status) else { continue }
            columns.pull(cardID, into: lane, at: now)
        }
        for list in pending {
            columns.markImported(
                listID: list.calendarIdentifier, at: now,
                taggedIDs: taggedByList[list.calendarIdentifier] ?? [])
        }
        persistColumns()
    }

    /// Which recurring series have a tag left over from a turn that has
    /// already been completed. Pure decision; the writing happens in
    /// `applyCorrections` with everything else.
    ///
    /// A standing condition, not an edge (see `RecurringTagRelease`): it
    /// holds on every refresh, so a tag restored hours later by a stale
    /// writer, or first seen after a sleep gap or cold start, lands in the
    /// same check as one that survived an external completion directly.
    private func releasedSeriesIDs(incomplete: [EKReminder], completed: [EKReminder]) -> Set<String> {
        let snapshots = (incomplete + completed).compactMap { reminder -> RecurringTagRelease.Snapshot? in
            guard let listID = reminder.calendar?.calendarIdentifier else { return nil }
            return RecurringTagRelease.Snapshot(
                id: reminder.calendarItemIdentifier,
                title: reminder.title ?? "",
                listID: listID,
                isCompleted: reminder.isCompleted,
                isRecurring: reminder.hasRecurrenceRules,
                status: currentStatus(of: reminder),
                createdAt: reminder.creationDate,
                completedAt: reminder.completionDate)
        }
        return RecurringTagRelease.releasedSeriesIDs(
            refreshed: snapshots,
            memory: releaseMemory,
            deliberatelyMoved: deliberatelyMovedSinceRefresh)
    }

    /// The one place the board writes to Reminders without being asked: an
    /// echo of its own write, and the one-off removal of the old status tags.
    ///
    /// Since 13.08.2026 columns are not part of this any more — they live in
    /// the board's own file, so a spent pull and a completed card are handled
    /// there, without touching anybody's reminder. What is left here defends
    /// the four fields the *editor* writes.
    ///
    /// Order matters: booking runs before answering, so a third state
    /// withdraws the entry and a user who changed their mind is never fought.
    private func applyCorrections(_ reminders: [EKReminder], now: Date = .now) {
        var answered = 0
        var dirty = false
        // Which records the migration finished with in this pass — struck off
        // only after their save landed, so an interrupted run resumes.
        var cleaned: Set<String> = []
        for reminder in reminders {
            let cardID = reminder.calendarItemIdentifier
            let state = Self.state(of: reminder)
            // A value that is neither what we wrote nor what we displaced
            // means somebody decided something new. Withdraw, do not fight.
            corrections.observe(cardID: cardID, state: state, now: now)

            // A list the board may not write to: attempting anyway would mean
            // mutating, failing and reverting the same record on every single
            // refresh, silently, forever.
            guard reminder.calendar?.allowsContentModifications == true else { continue }
            // A hand on the card outranks bookkeeping.
            guard !deliberatelyMovedSinceRefresh.contains(cardID) else { continue }
            // After a repeating card is completed, this identifier belongs to
            // the *next* turn. Undo refuses to write through it and says so;
            // an automatic correction has even less business there, and must
            // stay silent about it (no dialog, ever). No exception is needed
            // any more: the one write that used to need one — releasing a
            // spent pull — no longer goes through Reminders at all.
            guard !recurringHandoff.refusesUnattributedWrite(to: cardID) else { continue }

            var targetNotes = reminder.notes
            var targetTitle = reminder.title
            var targetURL = reminder.url
            var targetDue = reminder.dueDateComponents
            var touched: Set<CorrectionLedger.Field> = []

            if answered < Self.maxAnsweredCardsPerRefresh {
                let echoes = corrections.pendingEchoes(for: cardID, state: state, now: now)
                for (field, value) in echoes {
                    switch (field, value) {
                    case let (.notes, .text(text)):
                        targetNotes = text
                    case let (.title, .text(text)):
                        targetTitle = text
                    case let (.url, .text(text)):
                        targetURL = text.flatMap(URL.init(string:))
                    case let (.due, .due(date, hasTime)):
                        // Only a *vanished* date is restored, so the previous
                        // date is nil by rule and `followDueDate` — which
                        // would move an alarm — never applies.
                        targetDue = date.map {
                            Foundation.Calendar.current.dateComponents(
                                hasTime
                                    ? [.year, .month, .day, .hour, .minute, .timeZone]
                                    : [.year, .month, .day],
                                from: $0)
                        }
                    default:
                        continue
                    }
                    touched.insert(field)
                }
                if !touched.isEmpty { answered += 1 }
            }

            // The one-off cleanup: a status tag left over from the form this
            // board used until 13.08.2026 is cut out of the notes — but only
            // from the records the import named when it read them. Deciding by
            // "a tag is present" instead was measured deleting a user's own
            // word (14.08.2026): typing "Notiz mit #inprogress darin" and
            // closing the editor left "Notiz mit darin". Nothing outside that
            // list is ever cut, whatever it looks like.
            if columns.awaitsTagCleanup(cardID), StatusTagger.hasStatusTag(targetNotes) {
                targetNotes = targetNotes.map(StatusTagger.removingTags).flatMap { $0.isEmpty ? nil : $0 }
                touched.insert(.notes)
                cleaned.insert(cardID)
            }

            guard !touched.isEmpty else { continue }
            // Every field that is about to change has to be allowed to.
            let paced = touched.filter { field in
                corrections.permitsWrite(cardID: cardID, field: field, state: state, now: now)
            }
            guard !paced.isEmpty else { continue }

            let previousNotes = reminder.notes
            let previousTitle = reminder.title
            let previousURL = reminder.url
            let previousDue = reminder.dueDateComponents
            if paced.contains(.notes), targetNotes != reminder.notes { reminder.notes = targetNotes }
            if paced.contains(.title), targetTitle != reminder.title { reminder.title = targetTitle }
            if paced.contains(.url), targetURL != reminder.url { reminder.url = targetURL }
            if paced.contains(.due) { reminder.dueDateComponents = targetDue }

            if (try? eventStore.save(reminder, commit: false)) != nil {
                dirty = true
                let written = Self.state(of: reminder)
                for field in paced {
                    corrections.record(
                        cardID: cardID, field: field,
                        replaced: state[field], wrote: written[field], at: now)
                    corrections.markAnswered(cardID: cardID, field: field, at: now)
                    Self.correctionLog.notice(
                        "corrected \(field.rawValue, privacy: .public) on \"\(reminder.title ?? "?", privacy: .public)\"")
                }
            } else {
                // Put the record back: EventKit hands out cached instances,
                // so an unsaved change would show on the board as if it had
                // landed. The attempt still counts as this state's one
                // answer — otherwise a permanently failing write retries on
                // every refresh.
                reminder.notes = previousNotes
                reminder.title = previousTitle
                reminder.url = previousURL
                reminder.dueDateComponents = previousDue
                for field in paced {
                    corrections.markAnswered(cardID: cardID, field: field, at: now)
                }
                // The migration keeps this record on its list and tries again.
                cleaned.remove(cardID)
            }
        }
        if dirty {
            try? eventStore.commit()
        }
        if !cleaned.isEmpty {
            for cardID in cleaned { columns.markTagCleaned(cardID) }
            persistColumns()
        }
    }

    /// The newest completion on the current board that belongs to the series
    /// with this creation date — the same identity the release rule reads.
    /// The visible Done window is enough here: this only guards a pull
    /// against completions the board can already see (and against modest
    /// clock skew on the device that completed them).
    private func newestVisibleCompletion(matchingCreation creation: Date?, listID: String?) -> Date? {
        guard let creation, let listID else { return nil }
        return cards
            .filter { $0.status == .done && $0.creationDate == creation && $0.listID == listID }
            .compactMap(\.completionDate)
            .max()
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

    /// The column this reminder sits in — the one decision this whole board
    /// turns on.
    ///
    /// Completion still comes from EventKit, because that is where everybody
    /// else reads it. Everything else comes from the board's own record: no
    /// entry means Backlog, exactly as no tag did before 13.08.2026. What
    /// stands in the notes is now nobody's business but the user's.
    private func currentStatus(of reminder: EKReminder) -> KanbanStatus {
        if reminder.isCompleted { return .done }
        return columns.lane(of: reminder.calendarItemIdentifier)?.status ?? .backlog
    }

    /// An instance method since 13.08.2026: the column is read from the
    /// board's own state, which a static function cannot reach.
    private func card(from reminder: EKReminder) -> KanbanCard? {
        guard let calendar = reminder.calendar else { return nil }
        return KanbanCard(
            id: reminder.calendarItemIdentifier,
            title: TextSanitizer.displayTitle(reminder.title),
            notesPreview: TextSanitizer.notesPreview(reminder.notes),
            notesExcerpt: TextSanitizer.notesExcerpt(reminder.notes),
            // The whole note plus the link — what the card shows is a
            // preview, what Find searches is the reminder. Nothing is
            // stripped: the board writes no tags, so every word in there is
            // the user's and has to be findable.
            searchText: [
                reminder.notes,
                reminder.url?.absoluteString,
            ].compactMap { $0 }.joined(separator: "\n"),
            dueDate: reminder.dueDateComponents.flatMap { Foundation.Calendar.current.date(from: $0) },
            priority: reminder.priority,
            status: currentStatus(of: reminder),
            listID: calendar.calendarIdentifier,
            listName: calendar.title,
            listColor: Color(nsColor: calendar.color ?? .controlAccentColor),
            completionDate: reminder.completionDate,
            isRecurring: reminder.hasRecurrenceRules,
            lastModifiedDate: reminder.lastModifiedDate,
            pulledAt: columns.pulledAt(reminder.calendarItemIdentifier),
            creationDate: reminder.creationDate)
    }

    // MARK: - Writing

    /// Moves a card to another column. Returns the column it came from if
    /// anything actually changed, so the UI can give feedback (haptics) only
    /// on a real move — and can offer to put the card back.
    ///
    /// `feedback` is false only when the move replays through undo/redo:
    /// sound and haptics belong to the hand on the card, not to ⌘Z — an
    /// undone completion chiming like a fresh one read as the board
    /// celebrating a correction. The *visual* settles stay either way: they
    /// mark where the card went, which is wayfinding, and remote moves get
    /// them too.
    @discardableResult
    func move(
        cardID: String,
        to status: KanbanStatus,
        undoManager: UndoManager? = nil,
        feedback: Bool = true,
        restoredCompletion: Date? = nil
    ) -> KanbanStatus? {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return nil }
        let origin = currentStatus(of: reminder)
        let writeStamp = beginWrite()
        guard origin != status else { return nil }
        // Un-completing a repeating reminder is the one move EventKit cannot
        // express. Completing one detaches the finished occurrence and lets
        // the series carry on (measured on a real board — see `refresh`), so
        // clearing `isCompleted` here would not rewind anything: it would
        // revive the occurrence *beside* the instance the series has already
        // produced, and the board would show the same chore twice with no
        // hint of which is which. Saying so is better than quietly making a
        // duplicate the user then has to clean up by hand.
        if origin == .done, let live = liveRecurringSibling(of: reminder) {
            let name = live.title ?? String(localized: "This task")
            pendingSaveFailure = SaveFailure(
                cardID: cardID,
                title: String(localized: "Not Restored"),
                message: String(localized: "“\(name)” repeats, and the series has already moved on. Restoring the finished occurrence would put it on the board twice."))
            return nil
        }
        // Read before the save: afterwards this record is the rolled-on series
        // and no longer says anything about the occurrence that was finished.
        let wasRecurringSeries = reminder.hasRecurrenceRules
        // Only written when it actually changes: the setter also touches
        // `completionDate`, and a lateral move has no business rewriting
        // completion fields on a live recurring series.
        let completed = (status == .done)
        // A move between the open lanes touches EventKit not at all since
        // 13.08.2026 — the column is the board's own, and the reminder has no
        // business carrying it. Only crossing into or out of Erledigt is a
        // fact about the task itself, and that one still belongs in Reminders
        // where everybody else reads it.
        let touchesEventKit = reminder.isCompleted != completed
        // The day something was finished on is a fact, not a side effect of
        // where its card sits. Clearing `isCompleted` drops `completionDate`,
        // and setting it again stamps *now* — so pulling last week's card
        // back out of Erledigt and pressing ⌘Z filed it as finished today,
        // moving it to the top of the lane and counting it into the streak,
        // the weekly figure and the lead-time median. In Reminders the old
        // date was gone for good. Carried through the move instead, and
        // handed to the undo below so the way back restores it too.
        let previousCompletionDate = reminder.completionDate
        if touchesEventKit {
            reminder.isCompleted = completed
            if completed, let restoredCompletion {
                reminder.completionDate = restoredCompletion
            }
            do {
                try eventStore.save(reminder, commit: true)
            } catch {
                // Put the record back the way it was. EventKit hands out
                // cached instances by identifier, so a reminder left carrying
                // an unsaved completion would show as finished while the alert
                // says it did not move.
                reminder.isCompleted = (origin == .done)
                // Say so. A move that fails leaves the card where it was,
                // which on a board that animates every real move looks exactly
                // like a drop that missed — so the user tries again instead of
                // learning that this list is read-only.
                pendingSaveFailure = SaveFailure(
                    cardID: cardID, title: String(localized: "Not Moved"), message: error.localizedDescription)
                scheduleRefreshAfterWrite()
                return nil
            }
        }
        // The column itself, written last and only once anything it depends on
        // has actually landed: a completion that failed to save must not leave
        // the lane cleared. A read-only list is no obstacle here — the entry
        // is the board's own, and whether somebody else's reminder may be
        // edited says nothing about how this board sorts its own view.
        columns.pull(cardID, into: ColumnState.Lane(status), at: .now)
        persistColumns()
        // Registered after the save, not before: an undo entry for a move
        // that never happened spends itself doing nothing, and the *next* ⌘Z
        // then reaches back past it into an edit the user did mean to keep.
        register(undoManager, name: String(localized: "Move"), for: cardID, at: writeStamp) { store in
            store.move(
                cardID: cardID, to: origin, undoManager: undoManager,
                feedback: false, restoredCompletion: previousCompletionDate)
        }
        // Who this identifier belongs to from here on. Completing a repeating
        // card hands it to the next turn of the series; a move the user made
        // themselves hands it back (see `RecurringHandoff`).
        if status == .done {
            recurringHandoff.completed(
                cardID: cardID, isRecurringSeries: wasRecurringSeries, at: writeStamp)
        } else if feedback {
            recurringHandoff.movedDeliberately(cardID: cardID)
        }
        // A hand on the card outranks bookkeeping: the tag release must not
        // touch anything the user placed themselves this refresh cycle.
        if feedback {
            deliberatelyMovedSinceRefresh.insert(cardID)
        }
        // A pull of a recurring series is recorded durably: the standing
        // release rule weighs every completion against the last pull, and a
        // pull it cannot see reads as "nobody pulled". Replays through undo
        // count too — it is still this board writing. Stamped no earlier
        // than the newest completion already on the board, so a completion
        // that synced in before the pull can never outrank it.
        if wasRecurringSeries, status == .next || status == .inProgress {
            releaseMemory.recordPull(
                seriesID: cardID, at: .now,
                newestVisibleCompletion: newestVisibleCompletion(
                    matchingCreation: reminder.creationDate,
                    listID: reminder.calendar?.calendarIdentifier))
            releaseMemory.save()
        }
        // Nothing is booked into the correction ledger here any more: a move
        // no longer writes a reminder field, so there is no displacement for a
        // foreign writer to undo. The ledger still defends everything the
        // *editor* writes — title, notes, URL, due date.

        // Optimistic UI update; the EventKit change notification will
        // confirm it with a full refresh shortly after.
        //
        // Completing a repeating card is the exception, for the same reason
        // the settle below is skipped: this identifier already belongs to the
        // *next* turn of the series. Showing it as done parks an unstarted
        // chore in Erledigt, struck through, until the refresh moves it to
        // Backlog a moment later. The finished occurrence arrives in Erledigt
        // on its own, with its own identifier.
        if let index = cards.firstIndex(where: { $0.id == cardID }),
           !(status == .done && wasRecurringSeries) {
            cards[index].status = status
            cards[index].completionDate = (status == .done) ? (restoredCompletion ?? .now) : nil
        }
        // Not for a repeating card: this id is the next turn of the series by
        // now, so the strike-through would be drawn across a Backlog card that
        // has not been done at all. The finished occurrence is a record of its
        // own with its own id, and the refresh a moment later flags it through
        // the same diff that catches work finished on another device — inside
        // `Board.settleDelay`, so the choreography is unchanged.
        if status == .done, !wasRecurringSeries {
            flagRecentlyCompleted([cardID])
        }
        if status == .inProgress {
            flagRecentlyPulled([cardID])
        }
        // A card the user placed by hand must be visible where it landed,
        // even when the target lane folds it away (see `ColumnView`).
        if feedback {
            flagLanded(cardID)
        }
        // Feedback lives here, at the single point every route into a move
        // converges — drag & drop, context menu, VoiceOver action — because
        // a reward that only fires for mouse users is as broken as a limit
        // that only applies to them (see `pendingOverflow` above). Undo and
        // redo pass through this same point silently (see `feedback` above).
        if feedback {
            MoveFeedback.play(
                completed: status == .done,
                pulled: status == .inProgress,
                soundEnabled: completionSoundEnabled)
        }
        // Asked after the move, never before it: the board does not block a
        // drop, it lets the work land and then offers to put it back.
        // Only for a move the user just made. Replaying a decision is not
        // making one — the same rule the delete dialog already follows — and
        // answering "Erst abschließen" on a replayed move registered a fresh
        // undo entry of its own, so ⌘Z bounced the card between two lanes,
        // asking every time.
        if feedback, status.asksBeforeExceedingLimit, isOverWIPLimit(status) {
            pendingOverflow = PendingOverflow(cardID: cardID, origin: origin, status: status)
        }
        scheduleRefreshAfterWrite()
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
            scheduleRefreshAfterWrite()
            return nil
        }

        let cardID = reminder.calendarItemIdentifier
        newlyCreatedCardID = cardID
        // Deliberately *not* registered here. A creation that gets taken back
        // must leave no trace on the stack, and there is no way to withdraw a
        // single entry once it is on it — the previous attempt cleared the
        // whole stack instead, which silently threw away every undo the
        // session had, including a card the user had just deleted while the
        // confirmation promised ⌘Z would bring it back. The entry is booked
        // when the ticket is kept (see `finalizeNewTicket`).
        // Optimistic, like `move`: the editor opens on this card immediately,
        // it cannot wait out the debounced refresh.
        if let card = card(from: reminder) {
            cards.append(card)
        }
        scheduleRefreshAfterWrite()
        return cardID
    }

    /// Called by the editor as it closes. A brand-new ticket that is still
    /// empty in every field was a creation that got abandoned — it is removed
    /// silently, no undo entry: there is nothing to restore. `keep` is passed
    /// when the close is a jump to Reminders, where the user is clearly about
    /// to fill the ticket in over there.
    func finalizeNewTicket(cardID: String, keep: Bool = false, undoManager: UndoManager? = nil) {
        guard newlyCreatedCardID == cardID else { return }
        newlyCreatedCardID = nil
        guard !keep, let ticket = loadEditableTicket(cardID: cardID) else {
            registerCreation(cardID: cardID, undoManager: undoManager)
            keepNewTicketInSight(cardID: cardID)
            return
        }
        let isEmpty = ticket.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ticket.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ticket.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ticket.dueDate == nil
            && ticket.priority == 0
        guard isEmpty else {
            registerCreation(cardID: cardID, undoManager: undoManager)
            keepNewTicketInSight(cardID: cardID)
            return
        }
        removeNewTicket(cardID: cardID, undoManager: undoManager)
    }

    /// A ticket someone just made has to be on the board they made it on.
    ///
    /// The "+" stays available while the find settings are narrowed, and a
    /// brand-new ticket carries no priority and no date — so almost any
    /// active restriction hid it the moment the editor closed. The card was
    /// really there, and it looked like the app had thrown it away.
    ///
    /// The find settings lose that argument: they were set before this ticket
    /// existed, and the lane's own fold already bends the same way to keep a
    /// just-closed card visible (see `ColumnView.onChange(of:editingCardID)`).
    /// Books the undo entry for a creation that is being kept. Both routes
    /// out of "kept" come through here, so ⌘Z reaches a new ticket whether it
    /// was filled in or handed over to Reminders.
    private func registerCreation(cardID: String, undoManager: UndoManager?) {
        register(undoManager, name: String(localized: "Create Ticket"), for: cardID, at: beginWrite()) { store in
            store.deleteTicket(cardID: cardID, undoManager: undoManager)
        }
    }

    private func keepNewTicketInSight(cardID: String) {
        guard isFiltering else { return }
        let isVisible = KanbanStatus.allCases.contains { status in
            cards(for: status).contains { $0.id == cardID }
        }
        guard !isVisible else { return }
        resetFilters()
    }

    /// Called instead of `finalizeNewTicket` when the editor was left with
    /// Escape. Cancelling the edit of a ticket the "+" just made cancels the
    /// creation itself: whatever was typed was never written (the editor
    /// skips its save on this route), so the reminder is still the empty
    /// placeholder creation left behind — it goes, regardless of what stood in
    /// the fields. For every other card this does nothing: discarding is
    /// simply not saving, and there is nothing to undo.
    func cancelNewTicket(cardID: String, undoManager: UndoManager? = nil) {
        guard newlyCreatedCardID == cardID else { return }
        newlyCreatedCardID = nil
        removeNewTicket(cardID: cardID, undoManager: undoManager)
    }

    /// Takes back a creation, silently and with no undo entry — there is
    /// nothing to restore that the user ever put in.
    private func removeNewTicket(cardID: String, undoManager: UndoManager? = nil) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        try? eventStore.remove(reminder, commit: true)
        cards.removeAll { $0.id == cardID }
        // Nothing to withdraw: the creation was never booked (see
        // `createTicketForEditing`). Removing the reminder is not a change to
        // undo, it is the change never having happened — and every earlier
        // entry on the stack stays exactly where it was.
        scheduleRefreshAfterWrite()
    }

    /// `defaultCalendarForNewReminders()`, unless that list is excluded from
    /// the board — then the first included calendar, so the new ticket is
    /// visible immediately. Nil only if there are no reminder calendars at all.
    private func targetCalendarForNewTicket() -> EKCalendar? {
        // Writable only. A read-only shared list as the default target made
        // the "+" do visibly nothing, however often it was pressed, with no
        // message — the save failed after the placeholder had already been
        // created. The editor's own list picker has always filtered this way.
        let includedIDs = reminderCalendars
            .filter { !excludedCalendarIDs.contains($0.calendarIdentifier) && $0.allowsContentModifications }
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
    /// content — which is what Reminders' own "Recently Deleted" does too.
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
        /// The column the card stood in. Carried in the snapshot because
        /// EventKit gives a restored reminder a *new* identifier, so the
        /// board's own record cannot be found again under the old one — undo
        /// would silently return the card to Backlog. While the column lived
        /// in the notes, it rode along in `notes` and nobody had to think
        /// about it.
        let lane: ColumnState.Lane?
    }

    /// A ticket the user asked to delete, waiting for the answer.
    struct PendingDeletion: Identifiable {
        let cardID: String
        let title: String
        var id: String { cardID }
    }

    /// Set by every user-facing route into deleting — context menu and the
    /// VoiceOver action alike, the same way `pendingOverflow` catches every
    /// route into a move. A question only the mouse asks is not a question.
    @Published var pendingDeletion: PendingDeletion?

    /// Asks first. Undo and redo go straight to `deleteTicket`, because
    /// replaying a decision is not making one.
    ///
    /// Deleting used to happen on the spot, on the argument that ⌘Z charges
    /// only the person who made the mistake. That argument rested on undo
    /// being able to put the ticket back — and it cannot put all of it back:
    /// `restoreTicket` creates a *new* reminder from what EventKit exposes,
    /// so subtasks and attachments do not survive the round trip. A safety
    /// net with a hole in it has to be announced before the jump, not after.
    func requestDelete(cardID: String) {
        guard let card = cards.first(where: { $0.id == cardID }) else { return }
        pendingDeletion = PendingDeletion(
            cardID: cardID,
            title: card.title.isEmpty ? String(localized: "Untitled") : card.title)
    }

    /// Deletes a ticket and registers the undo that puts it back. The
    /// question is asked by `requestDelete`; this is the write itself.
    func deleteTicket(cardID: String, undoManager: UndoManager? = nil) {
        let writeStamp = beginWrite()
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        let snapshot = DeletedTicket(
            // `EKCalendarItem.calendar` is null_unspecified — it arrives as an
            // implicitly unwrapped optional and is nil for an item that has
            // not been filed yet. Every other read of it in this file guards;
            // this one would have trapped.
            calendarID: reminder.calendar?.calendarIdentifier ?? "",
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
            alarms: reminder.alarms,
            lane: columns.lane(of: cardID))
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            pendingSaveFailure = SaveFailure(
                cardID: cardID, title: String(localized: "Not Deleted"), message: error.localizedDescription)
            scheduleRefreshAfterWrite()
            return
        }
        // The record is gone, so its column is nothing but a stranded entry —
        // the snapshot carries it now, and `restoreTicket` puts it back.
        columns.release(cardID, at: .now)
        persistColumns()
        register(undoManager, name: String(localized: "Delete Ticket"), for: cardID, at: writeStamp) { store in
            store.restoreTicket(snapshot, undoManager: undoManager)
        }
        cards.removeAll { $0.id == cardID }
        scheduleRefreshAfterWrite()
    }

    /// Writes a deleted ticket back, and registers the redo that removes it
    /// again — so ⌘Z / ⇧⌘Z can be pressed as often as the user likes.
    @discardableResult
    func restoreTicket(_ snapshot: DeletedTicket, undoManager: UndoManager? = nil) -> String? {
        let writeStamp = beginWrite()
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
            scheduleRefreshAfterWrite()
            return nil
        }

        let cardID = reminder.calendarItemIdentifier
        // Under the *new* identifier: EventKit does not hand back the old one,
        // and without this the card would come back resting in Backlog.
        if let lane = snapshot.lane {
            columns.pull(cardID, into: lane, at: .now)
            persistColumns()
        }
        register(undoManager, name: String(localized: "Delete Ticket"), for: cardID, at: writeStamp) { store in
            store.deleteTicket(cardID: cardID, undoManager: undoManager)
        }
        scheduleRefreshAfterWrite()
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
        let writeStamp = beginWrite()
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        let previousTitle = reminder.title ?? ""
        // Nothing typed, nothing written. The board shows a trimmed title, so
        // a stored " Einkaufen" came back from the field as "Einkaufen" and
        // counted as a change: the reminder was rewritten, its modification
        // date bumped, and the card's dwell-time chip reset to zero for
        // opening a rename and pressing Return. The editor already refuses
        // this; the inline rename must too.
        guard title != previousTitle else { return }
        reminder.title = title
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            pendingSaveFailure = SaveFailure(
                cardID: cardID, title: String(localized: "Not Renamed"), message: error.localizedDescription)
            scheduleRefreshAfterWrite()
            return
        }
        corrections.record(
            cardID: cardID, field: .title,
            replaced: .text(previousTitle), wrote: .text(reminder.title), at: .now)
        register(undoManager, name: String(localized: "Rename"), for: cardID, at: writeStamp) { store in
            store.renameTicket(cardID: cardID, title: previousTitle, undoManager: undoManager)
        }
        if let index = cards.firstIndex(where: { $0.id == cardID }) {
            // The card carries the display form, so the optimistic update has
            // to go through the same sanitizer the refresh would apply.
            cards[index].title = TextSanitizer.displayTitle(title)
        }
        scheduleRefreshAfterWrite()
    }

    /// Whether a replayed write (undo/redo) has to be turned away because this
    /// identifier has moved on to the next turn of a repeating series, and
    /// says so if it does. See `RecurringHandoff` for the measurement behind
    /// the rule.
    ///
    /// One place for both replay paths — the move and the edit — so ⌘Z means
    /// the same thing whichever kind of change it lands on.
    private func refuseReplayOnRolledOnSeries(
        cardID: String,
        recordedAt: RecurringHandoff.Generation
    ) -> Bool {
        guard recurringHandoff.refusesReplay(of: cardID, recordedAt: recordedAt) else { return false }
        let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder
        let name = reminder?.title ?? String(localized: "This task")
        pendingSaveFailure = SaveFailure(
            cardID: cardID,
            title: String(localized: "Not Undone"),
            message: String(localized: "“\(name)” repeats. The turn you finished is filed away and this card is already the next one — undoing would change work that has not even been pulled yet."))
        return true
    }

    /// The live series instance behind a completed occurrence, if there is
    /// one.
    ///
    /// Matched by creation date (`RecurringSeriesMatch`, not title — see
    /// there for why), the same rule `refresh` uses to keep series creation
    /// dates out of the lead-time median, and for the same underlying reason
    /// this lookup exists at all: a completed occurrence has already been
    /// detached, so `hasRecurrenceRules` is false on it and the recurrence is
    /// only visible on the sibling that is still open.
    private func liveRecurringSibling(of reminder: EKReminder) -> EKReminder? {
        guard let seriesID = RecurringSeriesMatch.seriesID(
            of: Self.matchRecord(reminder),
            among: openRecurringReminders.map(Self.matchRecord))
        else { return nil }
        return openRecurringReminders.first { $0.calendarItemIdentifier == seriesID }
    }

    /// One reminder reduced to what identity reads (see
    /// `RecurringSeriesMatch`).
    private static func matchRecord(_ reminder: EKReminder) -> RecurringSeriesMatch.Record {
        RecurringSeriesMatch.Record(
            id: reminder.calendarItemIdentifier,
            listID: reminder.calendar?.calendarIdentifier ?? "",
            createdAt: reminder.creationDate,
            isCompleted: reminder.isCompleted,
            isRecurring: reminder.hasRecurrenceRules)
    }

    /// Registers the inverse of a write with the window's undo manager.
    ///
    /// Every board write goes through here, so ⌘Z means the same thing
    /// wherever it is pressed — and since the recurring fence lives *inside*
    /// this wrapper, that sentence is now structural rather than a promise.
    /// A future write path cannot forget the guard, because there is nothing
    /// to remember: it is guarded by registering. Before, two of six sites
    /// checked it and four did not, which is why undoing an edit made in the
    /// card editor was refused while the identical inline rename went
    /// through.
    ///
    /// The handler runs on the main thread — that is where the undo manager
    /// posted from — which is what lets it call back into this main-actor
    /// store.
    private func register(
        _ undoManager: UndoManager?,
        name: String,
        for cardID: String,
        at generation: RecurringHandoff.Generation,
        _ undo: @escaping (RemindersStore) -> Void
    ) {
        guard let undoManager else { return }
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                guard !store.refuseReplayOnRolledOnSeries(cardID: cardID, recordedAt: generation) else { return }
                undo(store)
            }
        }
    }

    /// Where the write currently being made sits in this session's order.
    /// Taken once at the top of every board write, so everything that write
    /// stamps — its undo entry, a handover it causes — carries the same value.
    private func beginWrite() -> RecurringHandoff.Generation {
        writeOrder = writeOrder.next()
        return writeOrder
    }

    /// Working copy for `TicketEditSheet`, read fresh from EventKit rather
    /// than carried on `KanbanCard` — the full notes text is only ever
    /// needed while a sheet is open, not for every card on the board.
    func loadEditableTicket(cardID: String) -> EditableTicket? {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return nil }
        let components = reminder.dueDateComponents
        return EditableTicket(
            title: reminder.title ?? "",
            notes: reminder.notes ?? "",
            url: reminder.url?.absoluteString ?? "",
            dueDate: components.flatMap { Foundation.Calendar.current.date(from: $0) },
            hasDueTime: components?.hour != nil,
            priority: reminder.priority,
            calendarID: reminder.calendar?.calendarIdentifier ?? "")
    }

    /// Moves the alarm that was pinned to the old due date along with it.
    ///
    /// Reminders.app files a timed reminder with an absolute alarm at its due
    /// date. Nothing here used to touch `alarms`, so shifting the date left
    /// the notification at the old time — the reminder said Friday and rang
    /// on Monday — and clearing the date left an alarm on a reminder that no
    /// longer had one.
    ///
    /// Deliberately narrow: only an absolute alarm sitting exactly on the old
    /// due date is treated as *its* alarm. Relative offsets, location alarms
    /// and anything the user set to a different time express an intent this
    /// code cannot infer, and are left alone. `deleteTicket` already carries
    /// alarms verbatim through the undo round trip; this is the one write
    /// that changes what they are anchored to.
    private static func followDueDate(on reminder: EKReminder, from oldDue: Date?, to newDue: Date?) {
        guard let oldDue, let alarms = reminder.alarms, !alarms.isEmpty else { return }
        let pinned = alarms.filter { alarm in
            guard let absolute = alarm.absoluteDate else { return false }
            return abs(absolute.timeIntervalSince(oldDue)) < 1
        }
        guard !pinned.isEmpty else { return }
        for alarm in pinned {
            reminder.removeAlarm(alarm)
        }
        // The date was cleared: the alarm it hung on goes with it.
        guard let newDue else { return }
        reminder.addAlarm(EKAlarm(absoluteDate: newDue))
    }

    /// Turns what was typed in the URL field into what EventKit stores —
    /// the same rule the field itself shows while it is being typed into
    /// (`TicketURL`). An empty field clears the reminder's URL rather than
    /// leaving a stale one behind.
    private static func parsedURL(_ text: String) -> URL? {
        TicketURL.parsed(text)
    }

    /// Every list the board actually draws from — what the settings left
    /// switched on. Read-only lists are in it: their cards are on the board
    /// too, so the find popover has to be able to filter by them.
    var boardCalendars: [EKCalendar] {
        reminderCalendars.filter { !excludedCalendarIDs.contains($0.calendarIdentifier) }
    }

    /// Lists a card can be moved to from the edit sheet: writable, and not
    /// hidden from the board — moving a card into an excluded list would
    /// make it vanish, which is not what picking a list should mean.
    var selectableCalendars: [EKCalendar] {
        boardCalendars.filter(\.allowsContentModifications)
    }

    /// Writes back the fields `TicketEditSheet` lets the user touch. The
    /// status hashtag is reapplied for the card's current column — this
    /// method never changes status, `move` does that — so a content edit
    /// can never accidentally relocate the card.
    /// Writes only the fields that actually changed, measured against the
    /// state the editor loaded (`baseline`).
    ///
    /// The sheet reads once, when it opens, and can then sit open for as long
    /// as it likes. Writing every field back would make that stale copy the
    /// truth: add a line to the same reminder on a phone, change nothing but
    /// the priority here, and the phone's line is gone — no conflict, no
    /// warning, and nothing on screen that ever showed it. Comparing against
    /// the baseline instead means an untouched field is not written at all,
    /// so a change that arrived from somewhere else survives.
    ///
    /// This is the same care `status` below already took, applied to the rest
    /// of the ticket.
    ///
    /// A replayed edit on a card whose identifier has since rolled on to the
    /// next turn of a series would put an old due date on a chore that has not
    /// come round yet — which is why every undo entry, this one included, is
    /// fenced at the single point it is registered (see `register`).
    func updateTicket(
        cardID: String,
        edited: EditableTicket,
        baseline: EditableTicket,
        undoManager: UndoManager? = nil
    ) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        let writeStamp = beginWrite()
        // Not a guard: the index only drives the optimistic redraw below. A
        // card can leave `cards` while its editor is open — its list gets
        // excluded in Settings, or it is deleted on another device — and the
        // edit still has to reach EventKit rather than being dropped on the
        // floor without a word.
        let index = cards.firstIndex(where: { $0.id == cardID })

        let newCalendar = eventStore.calendar(withIdentifier: edited.calendarID)

        let titleChanged = edited.title != baseline.title
        let notesChanged = edited.notes != baseline.notes
        let urlChanged = edited.url != baseline.url
        let dueChanged = edited.dueDate != baseline.dueDate || edited.hasDueTime != baseline.hasDueTime
        let priorityChanged = edited.priority != baseline.priority
        let calendarChanged = edited.calendarID != baseline.calendarID

        // The note is now nothing but the user's text. Empty means no note at
        // all rather than an empty one — EventKit distinguishes the two, and
        // the tag-writing code this replaces was careful about it as well.
        var rewrittenNotes: String?
        if notesChanged {
            rewrittenNotes = edited.notes.isEmpty ? nil : edited.notes
        }

        let replacedTitle = reminder.title
        let replacedURL = reminder.url?.absoluteString
        let replacedDue = reminder.dueDateComponents.flatMap { Foundation.Calendar.current.date(from: $0) }
        let replacedDueHasTime = reminder.dueDateComponents?.hour != nil
        if titleChanged { reminder.title = edited.title }
        let replacedNotes = reminder.notes
        if notesChanged { reminder.notes = rewrittenNotes }
        if urlChanged { reminder.url = Self.parsedURL(edited.url) }
        if dueChanged {
            // Without a time of day the reminder stays all-day, the way
            // Reminders itself models it (see `EditableTicket.hasDueTime`) —
            // and all-day is deliberately floating, so no time zone goes with
            // it: "the 3rd" is the 3rd wherever you are.
            //
            // A reminder due at a *time* carries one, because otherwise the
            // components are read in whatever zone the device happens to be
            // in. Written without it, "Monday 09:00 Europe/Berlin" became
            // "Monday 09:00 wherever I am" — six hours adrift after a flight,
            // for a reminder whose time nobody had touched.
            let dueFields: Set<Foundation.Calendar.Component> =
                edited.hasDueTime
                    ? [.year, .month, .day, .hour, .minute, .timeZone]
                    : [.year, .month, .day]
            let previousDue = reminder.dueDateComponents
                .flatMap { Foundation.Calendar.current.date(from: $0) }
            reminder.dueDateComponents = edited.dueDate.map {
                Foundation.Calendar.current.dateComponents(dueFields, from: $0)
            }
            Self.followDueDate(on: reminder, from: previousDue, to: edited.dueDate)
        }
        if priorityChanged { reminder.priority = edited.priority }
        if calendarChanged, let newCalendar,
           newCalendar.calendarIdentifier != reminder.calendar?.calendarIdentifier {
            reminder.calendar = newCalendar
        }

        // Captured before the save but registered after it: an undo entry for
        // a write that never happened is worse than none, because ⌘Z then
        // spends itself doing nothing and the *next* ⌘Z undoes something the
        // user did not mean to reach.
        let previous = loadEditableTicket(cardID: cardID)
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            pendingSaveFailure = SaveFailure(
                cardID: cardID, title: String(localized: "Not Saved"), message: error.localizedDescription)
            scheduleRefreshAfterWrite()
            return
        }
        // Moving a reminder between lists is the one identifier break this app
        // triggers itself — Apple documents it as possible, and this
        // measurement (13.08.2026, iCloud scratch lists) found the identifier
        // intact. Carried over anyway: if it ever does break, the card would
        // otherwise fall out of its column for a reason the user cannot see.
        if calendarChanged {
            columns.rekey(from: cardID, to: reminder.calendarItemIdentifier)
            persistColumns()
        }
        // Booked after the save, like every other write: an entry for a write
        // that never happened would have the app quietly "restoring" an edit
        // it just reported as failed, and retrying it on every refresh.
        if notesChanged {
            corrections.record(
                cardID: cardID, field: .notes,
                replaced: .text(replacedNotes), wrote: .text(reminder.notes), at: .now)
        }
        if titleChanged {
            corrections.record(
                cardID: cardID, field: .title,
                replaced: .text(replacedTitle), wrote: .text(reminder.title), at: .now)
        }
        if urlChanged {
            // The parsed form on both sides: a typed URL and the one EventKit
            // stores differ in percent-encoding, which would read as a
            // permanent echo.
            corrections.record(
                cardID: cardID, field: .url,
                replaced: .text(replacedURL), wrote: .text(reminder.url?.absoluteString), at: .now)
        }
        if dueChanged {
            corrections.record(
                cardID: cardID, field: .due,
                replaced: .due(replacedDue, hasTime: replacedDueHasTime),
                wrote: .due(
                    reminder.dueDateComponents.flatMap { Foundation.Calendar.current.date(from: $0) },
                    hasTime: reminder.dueDateComponents?.hour != nil),
                at: .now)
        }
        // Filling in a brand-new ticket is part of making it, not a second
        // change on top: with its own entry, ⌘Z right after creating a ticket
        // only emptied the title and left "Ohne Titel" lying on the board,
        // and it took a second ⌘Z to undo what felt like one action. The
        // creation's own entry (booked when the ticket is kept) removes the
        // whole card, which is what "undo that" means here.
        let isFirstFillOfNewTicket = newlyCreatedCardID == cardID
        // The inverse write: back to `previous`, measured against what was
        // just written, so undo touches exactly the fields this edit did.
        if let previous, !isFirstFillOfNewTicket {
            register(undoManager, name: String(localized: "Edit"), for: cardID, at: writeStamp) { store in
                store.updateTicket(
                    cardID: cardID, edited: previous, baseline: edited,
                    undoManager: undoManager)
            }
        }
        guard let index else {
            scheduleRefreshAfterWrite()
            return
        }
        // Only what was written is reflected — a field left alone on the
        // reminder must not be overwritten on the card either.
        if titleChanged { cards[index].title = TextSanitizer.displayTitle(edited.title) }
        if notesChanged {
            cards[index].notesPreview = TextSanitizer.notesPreview(rewrittenNotes)
            cards[index].notesExcerpt = TextSanitizer.notesExcerpt(rewrittenNotes)
        }
        if dueChanged { cards[index].dueDate = edited.dueDate }
        if priorityChanged { cards[index].priority = edited.priority }
        if calendarChanged, let newCalendar {
            cards[index].listName = newCalendar.title
            cards[index].listColor = Color(nsColor: newCalendar.color ?? .controlAccentColor)
        }
        scheduleRefreshAfterWrite()
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

    private func flagRecentlyPulled(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        recentlyPulledIDs.formUnion(ids)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            self?.recentlyPulledIDs.subtract(ids)
        }
    }

    func beginDrag(cardID: String) {
        guard draggingCardID != cardID else { return }
        draggingCardID = cardID
    }

    /// Ends the drag. Called from the drop target and from the gesture that
    /// runs alongside it — but neither fires when a drag is released over the
    /// toolbar, the gap between two lanes, or outside the window. The card
    /// then stayed ghosted at 40 % and every board tooltip stayed suppressed
    /// until the next drag happened to end inside a lane, so the window also
    /// clears it whenever it stops being the drag's target (see `BoardView`).
    func endDrag() {
        draggingCardID = nil
    }

    /// Notes that the user just placed a card themselves. The lane it landed
    /// in uses this to make sure the card is visible there rather than hidden
    /// under a fold.
    private func flagLanded(_ cardID: String) {
        lastLandedCardID = cardID
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            if self?.lastLandedCardID == cardID {
                self?.lastLandedCardID = nil
            }
        }
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
                && listFilter.matches($0.listID)
                && $0.matches(search: searchTerm)
        }
        if status == .done {
            // Finished work reads newest first; priority no longer matters.
            return filtered.sorted { ($0.completionDate ?? .distantPast) > ($1.completionDate ?? .distantPast) }
        }
        return filtered.sorted(by: KanbanCard.openLaneOrder())
    }

    func resetFilters() {
        priorityFilter = .all
        dueFilter = .all
        listFilter.showAll()
        searchText = ""
    }


    // MARK: - Find field

    /// True while the board shows less than everything. The find control wears
    /// this: a board must never be filtered without saying so, or cards look
    /// lost rather than hidden.
    ///
    /// The trimmed text decides, not the raw field: a stray space is not a
    /// search. Untrimmed, one accidental keystroke tinted the magnifier,
    /// raised the badge to 1 and made the board announce itself as filtered
    /// while every card stayed exactly where it was — `matches(search:)` had
    /// already decided that a term of nothing but whitespace matches
    /// everything.
    var searchTerm: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isFiltering: Bool {
        priorityFilter != .all
            || dueFilter != .all
            || !listFilter.isUnrestricted
            || !searchTerm.isEmpty
    }

    /// Active restrictions, for the badge on the collapsed find control.
    /// The list filter counts as one however many lists it holds — it is one
    /// row in the popover, and the badge counts rows, not values.
    var activeRestrictionCount: Int {
        (priorityFilter != .all ? 1 : 0)
            + (dueFilter != .all ? 1 : 0)
            + (listFilter.isUnrestricted ? 0 : 1)
            + (searchTerm.isEmpty ? 0 : 1)
    }

    // MARK: - Empty board

    var emptiness: BoardEmptiness? {
        BoardEmptiness.evaluate(
            hasVisibleCards: KanbanStatus.allCases.contains { !cards(for: $0).isEmpty },
            isFiltering: isFiltering,
            hasSelectedLists: !reminderCalendars.isEmpty
                && !reminderCalendars.allSatisfy { excludedCalendarIDs.contains($0.calendarIdentifier) },
            hasAnyList: !reminderCalendars.isEmpty,
            hasLoaded: hasLoadedOnce)
    }

    /// URL that opens this card's reminder directly in the Reminders app,
    /// or nil if no deep link could be resolved.
    func deepLinkURL(forCardID id: String) -> URL? {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        return ReminderDeepLink.url(for: reminder)
    }
}
