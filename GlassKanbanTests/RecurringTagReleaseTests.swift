import XCTest

/// The rule that takes `#next` off a chore nobody pulled.
///
/// Completing a recurring reminder outside this app leaves the notes
/// untouched: the finished turn is filed away as a detached copy under a new
/// identifier, and the series rolls on carrying the status tag (measured
/// against iCloud, 09.08.2026). Since 13.08.2026 the rule is a *standing
/// condition* — a completion newer than the last pull on this board spends
/// the tag, however late the tag arrives — because a stale writer restoring
/// `#next` minutes after an in-app completion defeated the old edge-triggered
/// form (measured 12.–13.08.2026, "Einkaufen"). It still fails toward keeping
/// the tag whenever the pull might be the user's.
final class RecurringTagReleaseTests: XCTestCase {

    /// The creation date a series and its own occurrences share — measured to
    /// be bit-identical against real EventKit (10.08.2026).
    private static let seriesCreated = Date(timeIntervalSinceReferenceDate: 808_083_284.719828010)

    /// When the standing rule started counting on this fictional board.
    private static let activeSince = Date(timeIntervalSinceReferenceDate: 900_000_000)

    /// A completion safely after `activeSince`.
    private static let completedAt = RecurringTagReleaseTests.activeSince.addingTimeInterval(3_600)

    private func series(
        id: String = "series", title: String = "Einkaufen", listID: String = "shared",
        status: KanbanStatus = .next, isRecurring: Bool = true, created: Date? = nil
    ) -> RecurringTagRelease.Snapshot {
        RecurringTagRelease.Snapshot(
            id: id, title: title, listID: listID,
            isCompleted: false, isRecurring: isRecurring, status: status,
            createdAt: created ?? Self.seriesCreated)
    }

    private func detachedOccurrence(
        id: String = "detached", title: String = "Einkaufen", listID: String = "shared",
        created: Date? = nil, completed: Date? = nil
    ) -> RecurringTagRelease.Snapshot {
        RecurringTagRelease.Snapshot(
            id: id, title: title, listID: listID,
            isCompleted: true, isRecurring: false, status: .done,
            createdAt: created ?? Self.seriesCreated,
            completedAt: completed ?? Self.completedAt)
    }

    private func memory(pulls: [String: Date] = [:]) -> RecurringTagRelease.Memory {
        RecurringTagRelease.Memory(lastPullByID: pulls, activeSince: Self.activeSince)
    }

    // MARK: - The standing condition

    func testACompletionWithNoRecordedPullReleasesTheSeriesTag() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), detachedOccurrence()],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    func testInProgressTagIsReleasedTheSameWay() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(status: .inProgress), detachedOccurrence()],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    /// The regression this rule's standing form exists for ("Einkaufen",
    /// 12.–13.08.2026): the occurrence was completed, the tag stripped — and
    /// minutes later a stale writer restored `#next` onto the rolled-on
    /// series. The old edge rule had already consumed its one look and never
    /// asked again. The standing condition does not care *when* the tag
    /// arrives: the completion is newer than any pull, so it is released.
    func testATagRestoredLongAfterTheCompletionIsStillReleased() {
        let pulledBeforeCompletion = Self.completedAt.addingTimeInterval(-7_200)
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), detachedOccurrence()],
            memory: memory(pulls: ["series": pulledBeforeCompletion]),
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    /// The user pulled the new turn after the completion. That pull is the
    /// freshest decision on the card; the tag is theirs.
    func testAPullAfterTheCompletionKeepsTheTag() {
        let pulledAfterCompletion = Self.completedAt.addingTimeInterval(60)
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), detachedOccurrence()],
            memory: memory(pulls: ["series": pulledAfterCompletion]),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Completions from before the rule existed are not evidence: the pulls
    /// they would be weighed against were never recorded, and judging them
    /// would demote every legitimately pulled recurring card once, board-wide,
    /// on upgrade.
    func testACompletionFromBeforeActivationReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [
                series(),
                detachedOccurrence(completed: Self.activeSince.addingTimeInterval(-60)),
            ],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Only the *newest* completion counts: an old finished turn from before
    /// the pull says nothing about the turn the user is holding now.
    func testTheNewestCompletionDecides() {
        let pulled = Self.completedAt.addingTimeInterval(60)
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [
                series(),
                detachedOccurrence(id: "old-done"),
                detachedOccurrence(id: "new-done", completed: pulled.addingTimeInterval(60)),
            ],
            memory: memory(pulls: ["series": pulled]),
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"], "a completion after the pull spends the tag again")
    }

    /// The user dragged the card in this refresh cycle. A hand on the card
    /// outranks bookkeeping, whatever the timestamps say.
    func testADeliberateMoveSinceLastRefreshBlocksTheRelease() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), detachedOccurrence()],
            memory: memory(),
            deliberatelyMoved: ["series"])
        XCTAssertEqual(released, [])
    }

    /// Running the rule on the post-release state finds nothing: the series
    /// no longer carries a tag, so the refresh the release write triggers
    /// terminates instead of looping.
    func testReleaseIsIdempotent() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(status: .backlog), detachedOccurrence()],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// A series resting in Backlog has no tag to give back; the rule only
    /// speaks for the working lanes.
    func testAnUntaggedSeriesReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(status: .backlog), detachedOccurrence()],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    func testAOneOffReminderIsNeverReleased() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(isRecurring: false), detachedOccurrence()],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Two different chores finished elsewhere in the same window: each
    /// series gets its own tag back, independently.
    func testTwoIndependentChoresReleaseIndependently() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [
                series(id: "shop", title: "Einkaufen"),
                series(id: "bath", title: "Joris baden", status: .inProgress,
                       created: Self.seriesCreated.addingTimeInterval(1)),
                detachedOccurrence(id: "shop-done", title: "Einkaufen"),
                detachedOccurrence(id: "bath-done", title: "Joris baden",
                                   created: Self.seriesCreated.addingTimeInterval(1)),
            ],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["shop", "bath"])
    }

    // MARK: - Identity by creation date (10.08.2026)

    /// The forbidden direction: a task created *and* completed on another
    /// device between two refreshes is fresh and completed — but its creation
    /// date is its own, so it is not an occurrence of anything.
    func testAForeignSameTitledTaskDoesNotReleaseTheTag() {
        let foreign = detachedOccurrence(
            id: "from-phone", created: Self.seriesCreated.addingTimeInterval(9_999))
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), foreign],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [], "a namesake must never take a pulled card's tag")
    }

    /// Renaming the series after the completion used to switch the old
    /// title-matching rule off entirely, so the chore kept its tag every
    /// cycle. Identity is the creation date; the name is free to change.
    func testARenamedSeriesStillReleases() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(title: "Einkaufen neu"), detachedOccurrence(title: "Einkaufen")],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    /// Two live series of one list sharing the occurrence's creation date make
    /// the match ambiguous. Fail closed: a kept tag costs one drag, a wrongly
    /// released one breaks the pull principle.
    func testTwoSeriesSharingTheCreationDateReleaseNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [
                series(id: "series-a"),
                series(id: "series-b"),
                detachedOccurrence(),
            ],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Uniqueness is judged among all live series of the list, not only the
    /// tagged ones — stricter is the right direction for the one rule that
    /// can move a card without anybody seeing it.
    func testAnUntaggedSeriesSharingTheDateBlocksTheRelease() {
        let twin = series(id: "twin", title: "Etwas anderes", status: .backlog)
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), twin, detachedOccurrence()],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [], "ambiguous identity means no proof")
    }

    func testSameTitleInAnotherListReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), detachedOccurrence(listID: "private")],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Untitled reminders are abandoned placeholders, not evidence about
    /// anybody's pull.
    func testAnUntitledOccurrenceReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), detachedOccurrence(title: "")],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    func testAnOccurrenceWithoutACreationDateReleasesNothing() {
        let dateless = RecurringTagRelease.Snapshot(
            id: "detached", title: "Einkaufen", listID: "shared",
            isCompleted: true, isRecurring: false, status: .done,
            createdAt: nil, completedAt: Self.completedAt)
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), dateless],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    func testAnOccurrenceWithoutACompletionDateReleasesNothing() {
        let dateless = RecurringTagRelease.Snapshot(
            id: "detached", title: "Einkaufen", listID: "shared",
            isCompleted: true, isRecurring: false, status: .done,
            createdAt: Self.seriesCreated, completedAt: nil)
        let released = RecurringTagRelease.releasedSeriesIDs(
            refreshed: [series(), dateless],
            memory: memory(),
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }
}

/// The persisted half of the release rule: the pull ledger, its stamping
/// rule, and how reading degrades when the stored data is missing, foreign,
/// or from another build.
final class RecurringTagReleaseMemoryTests: XCTestCase {

    /// The suite writes into the developer's real defaults — whatever was
    /// there before has to survive the test run (pattern from
    /// `AppAppearanceTests`).
    private var savedValue: Any?

    override func setUp() {
        super.setUp()
        savedValue = UserDefaults.standard.object(forKey: RecurringTagRelease.Memory.storageKey)
    }

    override func tearDown() {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: RecurringTagRelease.Memory.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: RecurringTagRelease.Memory.storageKey)
        }
        super.tearDown()
    }

    private static let activeSince = Date(timeIntervalSince1970: 1_700_000_000)

    func testMemoryRoundTripsThroughDefaults() {
        var memory = RecurringTagRelease.Memory(activeSince: Self.activeSince)
        memory.recordPull(
            seriesID: "series",
            at: Self.activeSince.addingTimeInterval(60),
            newestVisibleCompletion: nil)
        memory.save()
        XCTAssertEqual(RecurringTagRelease.Memory.load(), memory)
    }

    /// Fresh install: nothing stored means the rule starts counting from
    /// now — nothing that already happened is evidence.
    func testMissingKeyStartsCountingFromNow() {
        UserDefaults.standard.removeObject(forKey: RecurringTagRelease.Memory.storageKey)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let memory = RecurringTagRelease.Memory.load(now: now)
        XCTAssertTrue(memory.lastPullByID.isEmpty)
        XCTAssertEqual(memory.activeSince, now)
    }

    /// The pre-13.08.2026 payload stored seen identifiers and tagged lanes.
    /// None of it maps onto the pull ledger; it is dropped, and the rule
    /// starts counting from now — the documented upgrade path.
    func testOldEdgeRulePayloadLoadsAsAFreshStart() {
        UserDefaults.standard.set(
            ["seen": ["a", "b"], "tagged": ["a": "next"]],
            forKey: RecurringTagRelease.Memory.storageKey)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let memory = RecurringTagRelease.Memory.load(now: now)
        XCTAssertTrue(memory.lastPullByID.isEmpty)
        XCTAssertEqual(memory.activeSince, now)
    }

    func testForeignTypesUnderTheKeyLoadAsAFreshStart() {
        UserDefaults.standard.set("not a dictionary", forKey: RecurringTagRelease.Memory.storageKey)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let memory = RecurringTagRelease.Memory.load(now: now)
        XCTAssertTrue(memory.lastPullByID.isEmpty)
        XCTAssertEqual(memory.activeSince, now)
    }

    /// A pull is stamped no earlier than one second past the newest
    /// completion already on the board: a completion that synced in *before*
    /// the pull — even one stamped by a device whose clock runs ahead — can
    /// never outrank the pull it preceded.
    func testAPullOutranksEveryCompletionTheBoardCouldSee() {
        let now = Self.activeSince.addingTimeInterval(1_000)
        let skewedCompletion = now.addingTimeInterval(180)
        var memory = RecurringTagRelease.Memory(activeSince: Self.activeSince)
        memory.recordPull(seriesID: "series", at: now, newestVisibleCompletion: skewedCompletion)
        let pulledAt = memory.lastPullByID["series"]
        XCTAssertNotNil(pulledAt)
        XCTAssertGreaterThan(pulledAt!, skewedCompletion)
    }

    /// A completion already behind the pull leaves the stamp at "now" — the
    /// pull's own moment is the honest record.
    func testAPullAfterAnOlderCompletionIsStampedAtItsOwnTime() {
        let now = Self.activeSince.addingTimeInterval(1_000)
        var memory = RecurringTagRelease.Memory(activeSince: Self.activeSince)
        memory.recordPull(
            seriesID: "series", at: now,
            newestVisibleCompletion: now.addingTimeInterval(-600))
        XCTAssertEqual(memory.lastPullByID["series"], now)
    }

    /// The ledger is bounded; the oldest pull falls out first.
    func testThePullLedgerIsBoundedOldestFirst() {
        var memory = RecurringTagRelease.Memory(activeSince: Self.activeSince)
        for index in 0...RecurringTagRelease.Memory.maxPulls {
            memory.recordPull(
                seriesID: "series-\(index)",
                at: Self.activeSince.addingTimeInterval(Double(index)),
                newestVisibleCompletion: nil)
        }
        XCTAssertEqual(memory.lastPullByID.count, RecurringTagRelease.Memory.maxPulls)
        XCTAssertNil(memory.lastPullByID["series-0"], "the oldest pull is the one to go")
        XCTAssertNotNil(memory.lastPullByID["series-\(RecurringTagRelease.Memory.maxPulls)"])
    }
}
