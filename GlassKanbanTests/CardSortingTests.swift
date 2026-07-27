import XCTest
import SwiftUI

/// Sorting for the open lanes: not-yet-due recurring chores sink to the foot,
/// then urgency, then priority, then due date, then age, then title.
final class CardSortingTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Fixed "today" for every case below.
    private var now: Date { date(2026, 7, 18) }

    private func card(
        _ title: String,
        priority: Int = 0,
        due: Date? = nil,
        modified: Date? = nil,
        created: Date? = nil,
        recurring: Bool = false,
        status: KanbanStatus = .backlog
    ) -> KanbanCard {
        KanbanCard(
            id: title,
            title: title,
            notesPreview: "",
            notesExcerpt: "",
            dueDate: due,
            priority: priority,
            status: status,
            listName: "Test",
            listColor: .accentColor,
            completionDate: nil,
            isRecurring: recurring,
            lastModifiedDate: modified,
            creationDate: created)
    }

    private func sortedTitles(_ cards: [KanbanCard]) -> [String] {
        cards
            .sorted(by: KanbanCard.openLaneOrder(calendar: calendar, now: now))
            .map(\.title)
    }

    // MARK: - Priority rank

    func testPriorityRankOrdersHighToNone() {
        XCTAssertEqual(card("a", priority: 1).priorityRank, 0)
        XCTAssertEqual(card("a", priority: 4).priorityRank, 0)
        XCTAssertEqual(card("a", priority: 5).priorityRank, 1)
        XCTAssertEqual(card("a", priority: 9).priorityRank, 2)
        // "No priority" (0) must sort last despite its low number.
        XCTAssertEqual(card("a", priority: 0).priorityRank, 3)
    }

    // MARK: - Sorting

    func testPriorityBeatsDueDateAmongNonUrgentCards() {
        let cards = [
            card("undated low", priority: 9),
            card("high next year", priority: 1, due: date(2027, 1, 1)),
            card("none tomorrow", priority: 0, due: date(2026, 7, 19)),
            card("medium later", priority: 5, due: date(2026, 12, 1)),
        ]
        XCTAssertEqual(
            sortedTitles(cards),
            ["high next year", "medium later", "undated low", "none tomorrow"])
    }

    // MARK: - Urgency outranks priority

    func testDueTodayFloatsAbovePriorityWork() {
        let cards = [
            card("high in september", priority: 1, due: date(2026, 9, 1)),
            card("unprioritized today", priority: 0, due: now),
        ]
        XCTAssertEqual(sortedTitles(cards), ["unprioritized today", "high in september"])
    }

    func testOverdueFloatsAbovePriorityWork() {
        let cards = [
            card("high in september", priority: 1, due: date(2026, 9, 1)),
            card("unprioritized overdue", priority: 0, due: date(2026, 7, 10)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["unprioritized overdue", "high in september"])
    }

    func testPriorityStillOrdersWithinTheUrgentGroup() {
        let cards = [
            card("today no priority", priority: 0, due: now),
            card("overdue high", priority: 1, due: date(2026, 7, 10)),
            card("today medium", priority: 5, due: now),
        ]
        XCTAssertEqual(
            sortedTitles(cards),
            ["overdue high", "today medium", "today no priority"])
    }

    // MARK: - Days in column (dwell time)

    func testDaysInColumnCountsWholeDays() {
        XCTAssertEqual(
            card("t", modified: date(2026, 7, 16)).daysInColumn(calendar: calendar, now: now), 2)
        XCTAssertEqual(
            card("t", modified: date(2026, 7, 18)).daysInColumn(calendar: calendar, now: now), 0)
        XCTAssertNil(card("t").daysInColumn(calendar: calendar, now: now))
    }

    func testDaysInColumnIgnoresTimeOfDay() {
        let lateEvening = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 16, hour: 23, minute: 50))!
        XCTAssertEqual(
            card("t", modified: lateEvening).daysInColumn(calendar: calendar, now: now), 2)
    }

    func testTomorrowIsNotUrgent() {
        XCTAssertFalse(
            card("t", due: date(2026, 7, 19)).isUrgent(calendar: calendar, now: now))
        XCTAssertTrue(
            card("t", due: now).isUrgent(calendar: calendar, now: now))
        XCTAssertFalse(card("t").isUrgent(calendar: calendar, now: now))
    }

    func testDueDateOrdersWithinSamePriority() {
        let cards = [
            card("later", priority: 5, due: date(2026, 9, 1)),
            card("soon", priority: 5, due: date(2026, 7, 20)),
            card("mid", priority: 5, due: date(2026, 8, 5)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["soon", "mid", "later"])
    }

    func testUndatedCardsSortAfterDatedOnesOfSamePriority() {
        let cards = [
            card("no date", priority: 5),
            card("has date", priority: 5, due: date(2027, 1, 1)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["has date", "no date"])
    }

    func testTitleBreaksTiesSoOrderNeverJitters() {
        let due = date(2026, 8, 1)
        let cards = [
            card("Zebra", priority: 5, due: due),
            card("apple", priority: 5, due: due),
            card("Mango", priority: 5, due: due),
        ]
        XCTAssertEqual(sortedTitles(cards), ["apple", "Mango", "Zebra"])
    }

    // MARK: - Age (creation date)

    func testOldestTicketWinsAmongOtherwiseEqualCards() {
        // Alphabetically this order would be exactly reversed — age has to
        // outrank the title, or the pile buries whatever was added first.
        let cards = [
            card("apple", priority: 5, created: date(2026, 7, 10)),
            card("Mango", priority: 5, created: date(2026, 7, 3)),
            card("Zebra", priority: 5, created: date(2026, 6, 1)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["Zebra", "Mango", "apple"])
    }

    func testAgeOnlyBreaksTiesWithinTheSamePriorityAndDueDate() {
        // The old card is unprioritized: age must not lift it over
        // higher-priority work, it only orders peers.
        let cards = [
            card("old but unprioritized", priority: 0, created: date(2020, 1, 1)),
            card("new but high", priority: 1, created: date(2026, 7, 18)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["new but high", "old but unprioritized"])
    }

    func testAgeOrdersDatedCardsSharingADueDate() {
        let due = date(2026, 8, 1)
        let cards = [
            card("added later", priority: 5, due: due, created: date(2026, 7, 15)),
            card("added first", priority: 5, due: due, created: date(2026, 7, 1)),
        ]
        XCTAssertEqual(sortedTitles(cards), ["added first", "added later"])
    }

    func testTitleStillDecidesWhenCreationDatesAreMissingOrEqual() {
        let created = date(2026, 7, 5)
        let sameInstant = [
            card("Zebra", priority: 5, created: created),
            card("apple", priority: 5, created: created),
        ]
        XCTAssertEqual(sortedTitles(sameInstant), ["apple", "Zebra"])

        // EventKit does not guarantee a creation date; a card without one
        // must still land somewhere deterministic rather than jittering.
        let noDates = [card("Zebra", priority: 5), card("apple", priority: 5)]
        XCTAssertEqual(sortedTitles(noDates), ["apple", "Zebra"])
    }

    // MARK: - Ripeness outranks everything else

    /// The reason this rule exists. A high-priority monthly chore used to sit
    /// above the errand that was actually due today, because priority won
    /// before the due date was ever consulted. "Important" is not "now".
    func testNotYetDueSinksBelowPriority() {
        XCTAssertEqual(
            sortedTitles([
                card("Monatsputz", priority: 1, due: date(2026, 8, 18), recurring: true),
                card("Rechnung", priority: 9, due: date(2026, 7, 18)),
            ]),
            ["Rechnung", "Monatsputz"])
    }

    /// It even sinks below an undated card. Backlog is the pool of things that
    /// could be pulled now; a chore with a date three weeks out is the weakest
    /// option on the board, whatever else it is competing with.
    func testNotYetDueSinksBelowUndatedCards() {
        XCTAssertEqual(
            sortedTitles([
                card("Einkaufen", due: date(2026, 7, 22), recurring: true),
                card("Idee notieren"),
            ]),
            ["Idee notieren", "Einkaufen"])
    }

    /// Among themselves the not-yet-due chores run by the calendar: nearest
    /// turn first.
    func testNotYetDueCardsRunChronologically() {
        XCTAssertEqual(
            sortedTitles([
                card("Filter wechseln", due: date(2026, 9, 1), recurring: true),
                card("Einkaufen", due: date(2026, 7, 22), recurring: true),
            ]),
            ["Einkaufen", "Filter wechseln"])
    }

    /// And priority does not get a say down there. A "!!!" chore four months
    /// out above a "!" one due next week is not an order anybody can read —
    /// this is what the real board showed the first time the fold opened.
    func testPriorityDoesNotReorderTheNotYetDueTail() {
        XCTAssertEqual(
            sortedTitles([
                card("Rebalancing", priority: 1, due: date(2026, 12, 1), recurring: true),
                card("Saugroboter", priority: 9, due: date(2026, 8, 14), recurring: true),
                card("HelloFresh", priority: 5, due: date(2026, 8, 1), recurring: true),
            ]),
            ["HelloFresh", "Saugroboter", "Rebalancing"])
    }

    /// Above the line nothing changed: priority still beats the due date for
    /// the cards that really are candidates for today.
    func testPriorityStillRanksTheRipeCards() {
        XCTAssertEqual(
            sortedTitles([
                card("Später fällig", priority: 9, due: date(2026, 7, 20)),
                card("Wichtig", priority: 1, due: date(2026, 7, 25)),
            ]),
            ["Wichtig", "Später fällig"])
    }

    /// A recurring card that is due — today or overdue — is an ordinary
    /// urgent card and keeps the top of the lane.
    func testDueRecurringCardIsNotSunk() {
        XCTAssertEqual(
            sortedTitles([
                card("Idee notieren"),
                card("Müll rausbringen", due: date(2026, 7, 18), recurring: true),
            ]),
            ["Müll rausbringen", "Idee notieren"])
    }

    /// Once pulled, it is a decision, not an option — the working lanes never
    /// re-rank it.
    func testWorkingLanesDoNotSinkRecurringCards() {
        XCTAssertEqual(
            sortedTitles([
                card("Idee notieren", status: .inProgress),
                card("Einkaufen", due: date(2026, 7, 22), recurring: true, status: .inProgress),
            ]),
            ["Einkaufen", "Idee notieren"])
    }
}
