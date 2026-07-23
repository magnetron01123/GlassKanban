import XCTest

final class FilterTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Priority (EventKit: 0 none, 1–4 high, 5 medium, 6–9 low)

    func testPriorityGroups() {
        XCTAssertTrue(PriorityFilter.high.matches(1))
        XCTAssertTrue(PriorityFilter.high.matches(4))
        XCTAssertFalse(PriorityFilter.high.matches(5))
        XCTAssertTrue(PriorityFilter.medium.matches(5))
        XCTAssertTrue(PriorityFilter.low.matches(6))
        XCTAssertTrue(PriorityFilter.low.matches(9))
        XCTAssertTrue(PriorityFilter.unset.matches(0))
        XCTAssertFalse(PriorityFilter.unset.matches(5))
        XCTAssertTrue(PriorityFilter.all.matches(0))
        XCTAssertTrue(PriorityFilter.all.matches(7))
    }

    // MARK: - Due date (reference "now": Friday, 2026-07-17)

    func testOverdueMatchesPastDatesOnly() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(DueFilter.overdue.matches(date(2026, 7, 16), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.overdue.matches(date(2026, 7, 17, hour: 8), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.overdue.matches(date(2026, 7, 18), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.overdue.matches(nil, calendar: calendar, now: now))
    }

    func testTodayMatchesSameDayRegardlessOfTime() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(DueFilter.today.matches(date(2026, 7, 17, hour: 23), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.today.matches(date(2026, 7, 16), calendar: calendar, now: now))
    }

    func testThisWeekMatchesMondayThroughSunday() {
        let now = date(2026, 7, 17) // Friday of week Mon 13 – Sun 19
        XCTAssertTrue(DueFilter.thisWeek.matches(date(2026, 7, 13), calendar: calendar, now: now))
        XCTAssertTrue(DueFilter.thisWeek.matches(date(2026, 7, 19), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.thisWeek.matches(date(2026, 7, 20), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.thisWeek.matches(date(2026, 7, 12), calendar: calendar, now: now))
    }

    /// "Diese Woche" compares week-of-year, which repeats every January — so
    /// without the year being part of the comparison, a card due next New
    /// Year's Eve would show up in the first week of this one. `isDate(_:
    /// equalTo:toGranularity: .weekOfYear)` compares the era down to the week,
    /// so it does not; this pins that down.
    func testThisWeekDoesNotMatchTheSameWeekInAnotherYear() {
        let now = date(2026, 1, 7) // Wednesday of week 2, 2026
        XCTAssertTrue(DueFilter.thisWeek.matches(date(2026, 1, 8), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.thisWeek.matches(date(2027, 1, 7), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.thisWeek.matches(date(2025, 1, 8), calendar: calendar, now: now))
    }

    /// Turn of the year inside one week: 2025-12-29 (Mon) to 2026-01-04 (Sun)
    /// is a single week that spans two years.
    func testThisWeekSpansTheTurnOfTheYear() {
        let now = date(2025, 12, 30)
        XCTAssertTrue(DueFilter.thisWeek.matches(date(2026, 1, 2), calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.thisWeek.matches(date(2026, 1, 5), calendar: calendar, now: now))
    }

    func testNoDateMatchesOnlyNil() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(DueFilter.noDate.matches(nil, calendar: calendar, now: now))
        XCTAssertFalse(DueFilter.noDate.matches(now, calendar: calendar, now: now))
    }

    // MARK: - Search

    private func searchCard(title: String, notes: String = "") -> KanbanCard {
        KanbanCard(
            id: title,
            title: title,
            notesPreview: notes,
            notesExcerpt: notes,
            dueDate: nil,
            priority: 0,
            status: .backlog,
            listName: "Test",
            listColor: .accentColor,
            completionDate: nil,
            isRecurring: false,
            lastModifiedDate: nil)
    }

    func testEmptySearchMatchesEverything() {
        let card = searchCard(title: "Steuererklärung")
        XCTAssertTrue(card.matches(search: ""))
        XCTAssertTrue(card.matches(search: "   "))
    }

    func testSearchLooksAtTitleAndNotes() {
        let card = searchCard(title: "Angebot prüfen", notes: "Rückmeldung an Kollegin")
        XCTAssertTrue(card.matches(search: "angebot"))
        XCTAssertTrue(card.matches(search: "kollegin"))
        XCTAssertFalse(card.matches(search: "rechnung"))
    }

    /// The same forgiveness the Reminders app itself shows: case and
    /// diacritics are ignored, so "uber" finds "Überweisung".
    func testSearchIgnoresCaseAndDiacritics() {
        let card = searchCard(title: "Überweisung an Müller")
        XCTAssertTrue(card.matches(search: "uberweisung"))
        XCTAssertTrue(card.matches(search: "MÜLLER"))
    }

    /// Every word has to appear somewhere, but not as one contiguous phrase —
    /// typing the two words you remember should not depend on their order.
    func testSearchWordsMayAppearInAnyOrderAndAcrossFields() {
        let card = searchCard(title: "Angebot prüfen", notes: "für das Gartenhaus")
        XCTAssertTrue(card.matches(search: "prüfen angebot"))
        XCTAssertTrue(card.matches(search: "angebot gartenhaus"))
        XCTAssertFalse(card.matches(search: "angebot dachterrasse"))
    }

    // MARK: - Recurring (reference "now": Friday, 2026-07-17, week Mon 13 – Sun 19)

    private func card(
        recurring: Bool,
        due: Date?,
        status: KanbanStatus = .backlog
    ) -> KanbanCard {
        KanbanCard(
            id: "card",
            title: "Pflanzen umtopfen",
            notesPreview: "",
            notesExcerpt: "",
            dueDate: due,
            priority: 0,
            status: status,
            listName: "Test",
            listColor: .accentColor,
            completionDate: nil,
            isRecurring: recurring,
            lastModifiedDate: nil)
    }

    private func isVisible(
        _ filter: RecurringFilter,
        _ card: KanbanCard,
        now: Date = Date(timeIntervalSince1970: 0)
    ) -> Bool {
        filter.matches(card, calendar: calendar, now: now)
    }

    func testNonRecurringCardsAreNeverHidden() {
        let now = date(2026, 7, 17)
        let farFuture = card(recurring: false, due: date(2026, 12, 24))
        XCTAssertTrue(isVisible(.hiddenUntilDue, farFuture, now: now))
    }

    /// Not yet due is not yet due — including later the same calendar week,
    /// which is the case that gave the rule away in practice: a card due
    /// Wednesday sat in the Backlog from Monday under a filter that says
    /// "Wenn fällig".
    func testRecurringCardNotYetDueIsHidden() {
        let now = date(2026, 7, 17) // Friday, week Mon 13 – Sun 19
        XCTAssertFalse(isVisible(.hiddenUntilDue, card(recurring: true, due: date(2026, 7, 18)), now: now),
                       "tomorrow is not due")
        XCTAssertFalse(isVisible(.hiddenUntilDue, card(recurring: true, due: date(2026, 7, 19)), now: now),
                       "later this same calendar week is not due either")
        XCTAssertFalse(isVisible(.hiddenUntilDue, card(recurring: true, due: date(2026, 7, 20)), now: now))
        XCTAssertFalse(isVisible(.hiddenUntilDue, card(recurring: true, due: date(2026, 8, 17)), now: now))
    }

    func testRecurringCardAppearsOnceItIsDue() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(isVisible(.hiddenUntilDue, card(recurring: true, due: date(2026, 7, 10)), now: now),
                      "overdue")
        XCTAssertTrue(isVisible(.hiddenUntilDue, card(recurring: true, due: date(2026, 7, 17, hour: 23)), now: now),
                      "due today, whatever the time of day")
    }

    /// Without a date there is no way to tell when it comes round again, so
    /// hiding it would remove it from the board indefinitely.
    func testRecurringCardWithoutDueDateStaysVisible() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(isVisible(.hiddenUntilDue, card(recurring: true, due: nil), now: now))
    }

    /// Pulling a card into a lane is a decision the user made; completing it
    /// is a record. Neither is the board's to hide.
    func testOnlyBacklogHidesRecurringCards() {
        let now = date(2026, 7, 17)
        let due = date(2026, 8, 17)
        for status in KanbanStatus.allCases where status != .backlog {
            XCTAssertTrue(
                isVisible(.hiddenUntilDue, card(recurring: true, due: due, status: status), now: now),
                "\(status.displayName) must not hide recurring cards")
        }
    }

    func testAlwaysVisibleShowsEverything() {
        let now = date(2026, 7, 17)
        XCTAssertTrue(isVisible(.alwaysVisible, card(recurring: true, due: date(2026, 12, 24)), now: now))
        XCTAssertTrue(isVisible(.alwaysVisible, card(recurring: true, due: nil), now: now))
    }

    /// The resting value is part of the rule, not an implementation detail:
    /// it is the one filter whose default already hides something, and the
    /// store leans on that when deciding whether the board counts as filtered.
    /// (How the store reports that is exercised through the board itself —
    /// this bundle compiles pure logic only, with no app host.)
    func testDefaultIsTheHidingValue() {
        XCTAssertEqual(RecurringFilter.allCases.first, .hiddenUntilDue)
    }
}
