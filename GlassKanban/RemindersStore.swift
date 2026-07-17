import EventKit
import SwiftUI

/// The single data layer of the app. Reads reminders via EventKit, derives
/// `KanbanCard`s, and performs the only write operations the app has:
/// moving a card between columns (rewriting the status hashtag and/or
/// `isCompleted`) plus tag hygiene. All app data lives in Reminders.
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
    @Published private(set) var streak: Int = 0
    @Published var priorityFilter: PriorityFilter = .all
    @Published var dueFilter: DueFilter = .all

    /// Calendar identifiers the user excluded in Settings (e.g. a shopping
    /// list). Persisted in UserDefaults; everything else is included.
    @Published var excludedCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(excludedCalendarIDs), forKey: Self.excludedKey)
            scheduleRefresh()
        }
    }

    private static let excludedKey = "excludedCalendarIDs"

    /// Completed reminders are shown in "Erledigt" for this many days.
    private static let doneWindowDays = 14
    /// How far back completions are fetched for the streak calculation.
    private static let streakWindowDays = 400

    private let eventStore = EKEventStore()
    private var refreshTask: Task<Void, Never>?

    init() {
        excludedCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: Self.excludedKey) ?? [])
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
        await refresh()
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
            streak = 0
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

        streak = StreakCalculator.streak(completionDates: completed.compactMap(\.completionDate))

        let doneWindowStart = calendar.date(
            byAdding: .day, value: -Self.doneWindowDays, to: calendar.startOfDay(for: .now))!
        let visibleCompleted = completed.filter { ($0.completionDate ?? .distantPast) >= doneWindowStart }

        cards = (incomplete + visibleCompleted).compactMap(Self.card(from:))
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
            dueDate: reminder.dueDateComponents.flatMap { Foundation.Calendar.current.date(from: $0) },
            priority: reminder.priority,
            status: StatusTagger.status(fromNotes: reminder.notes, isCompleted: reminder.isCompleted),
            listName: calendar.title,
            listColor: Color(nsColor: calendar.color ?? .controlAccentColor),
            completionDate: reminder.completionDate)
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

    // MARK: - Writing (the app's only write: moving a card)

    func move(cardID: String, to status: KanbanStatus) {
        guard let reminder = eventStore.calendarItem(withIdentifier: cardID) as? EKReminder else { return }
        guard StatusTagger.status(fromNotes: reminder.notes, isCompleted: reminder.isCompleted) != status else { return }

        reminder.notes = StatusTagger.rewrittenNotes(reminder.notes, for: status)
        reminder.isCompleted = (status == .done)
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            scheduleRefresh()
            return
        }

        // Optimistic UI update; the EventKit change notification will
        // confirm it with a full refresh shortly after.
        if let index = cards.firstIndex(where: { $0.id == cardID }) {
            cards[index].status = status
            cards[index].completionDate = (status == .done) ? .now : nil
        }
        scheduleRefresh()
    }

    // MARK: - Board queries

    func cards(for status: KanbanStatus) -> [KanbanCard] {
        let filtered = cards.filter {
            $0.status == status
                && priorityFilter.matches($0.priority)
                && dueFilter.matches($0.dueDate)
        }
        if status == .done {
            return filtered.sorted { ($0.completionDate ?? .distantPast) > ($1.completionDate ?? .distantPast) }
        }
        return filtered.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(l), .some(r)):
                if l != r { return l < r }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    func resetFilters() {
        priorityFilter = .all
        dueFilter = .all
    }

    /// URL that opens this card's reminder directly in the Reminders app,
    /// or nil if no deep link could be resolved.
    func deepLinkURL(forCardID id: String) -> URL? {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        return ReminderDeepLink.url(for: reminder)
    }
}
