import XCTest

/// The rule that takes `#next` off a chore nobody pulled.
///
/// Completing a recurring reminder outside this app leaves the notes
/// untouched: the finished turn is filed away as a detached copy under a new
/// identifier, and the series rolls on carrying the status tag (measured
/// against iCloud, 09.08.2026). The release rule spots that fingerprint and
/// gives the tag back — and fails toward keeping it whenever the pull might
/// still be the user's.
final class RecurringTagReleaseTests: XCTestCase {

    /// The creation date a series and its own occurrences share — measured to
    /// be bit-identical against real EventKit (10.08.2026).
    private static let seriesCreated = Date(timeIntervalSinceReferenceDate: 808_083_284.719828010)

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
        created: Date? = nil
    ) -> RecurringTagRelease.Snapshot {
        RecurringTagRelease.Snapshot(
            id: id, title: title, listID: listID,
            isCompleted: true, isRecurring: false, status: .done,
            createdAt: created ?? Self.seriesCreated)
    }

    func testExternallyCompletedOccurrenceReleasesTheSeriesTag() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    func testInProgressTagIsReleasedTheSameWay() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .inProgress],
            previouslySeenIDs: ["series"],
            refreshed: [series(status: .inProgress), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    /// An ordinary completion keeps its identifier — it was on the board as
    /// an open card. Only an identifier the previous fetch never saw is the
    /// fingerprint of a detached occurrence.
    func testCompletionOfAKnownReminderReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next, "one-off": .inProgress],
            previouslySeenIDs: ["series", "one-off"],
            refreshed: [
                series(),
                detachedOccurrence(id: "one-off"),
            ],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// First load after a cold start: there is no previous board, so nothing
    /// can prove the tag predates the completion. The tag stays — the
    /// documented, accepted gap.
    func testEmptyPreviousBoardReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: [:],
            previouslySeenIDs: [],
            refreshed: [series(), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// The tag changed since the last refresh — someone pulled or re-lane'd
    /// the card. That pull is fresher than the completion; it stays.
    func testATagThatChangedSinceLastRefreshStays() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .backlog],
            previouslySeenIDs: ["series"],
            refreshed: [series(), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// The user dragged the card between the external completion syncing in
    /// and the refresh seeing it. A hand on the card outranks bookkeeping.
    func testADeliberateMoveSinceLastRefreshBlocksTheRelease() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(), detachedOccurrence()],
            deliberatelyMoved: ["series"])
        XCTAssertEqual(released, [])
    }

    /// Two live series of one list sharing the occurrence's creation date make
    /// the match ambiguous. Fail closed: a kept tag costs one drag, a wrongly
    /// released one breaks the pull principle.
    func testTwoSeriesSharingTheCreationDateReleaseNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series-a": .next, "series-b": .next],
            previouslySeenIDs: ["series-a", "series-b"],
            refreshed: [
                series(id: "series-a"),
                series(id: "series-b"),
                detachedOccurrence(),
            ],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    func testSameTitleInAnotherListReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(), detachedOccurrence(listID: "private")],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    func testAOneOffReminderIsNeverReleased() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(isRecurring: false), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// A series resting in Backlog has no tag to give back; the rule only
    /// speaks for the working lanes.
    func testAnUntaggedSeriesReleasesNothing() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .backlog],
            previouslySeenIDs: ["series"],
            refreshed: [series(status: .backlog), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Untitled reminders all share the empty title — matching on it would
    /// connect records that have nothing to do with each other.
    func testEmptyTitlesNeverMatch() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(title: ""), detachedOccurrence(title: "")],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Running the rule on the post-release state finds nothing: the series
    /// no longer carries a tag, so the refresh the release write triggers
    /// terminates instead of looping.
    func testReleaseIsIdempotent() {
        let afterRelease = [series(status: .backlog), detachedOccurrence()]
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .backlog, "detached": .done],
            previouslySeenIDs: ["series", "detached"],
            refreshed: afterRelease,
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// Two different chores finished elsewhere in the same window: each
    /// series gets its own tag back, independently.
    func testTwoIndependentChoresReleaseIndependently() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["shop": .next, "bath": .inProgress],
            previouslySeenIDs: ["shop", "bath"],
            refreshed: [
                series(id: "shop", title: "Einkaufen"),
                series(id: "bath", title: "Joris baden", status: .inProgress,
                       created: Self.seriesCreated.addingTimeInterval(1)),
                detachedOccurrence(id: "shop-done", title: "Einkaufen"),
                detachedOccurrence(id: "bath-done", title: "Joris baden",
                                   created: Self.seriesCreated.addingTimeInterval(1)),
            ],
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["shop", "bath"])
    }

    // MARK: - Cold start, seeded from the persisted memory

    /// The gap the memory closes: the completion happened while the app was
    /// closed. Seeding the first refresh with the last session's memory makes
    /// it look exactly like any other refresh to the rule.
    func testColdStartWithMemoryOfTheTagReleases() {
        let memory = RecurringTagRelease.Memory(
            seenIDs: ["series", "old-done"],
            taggedStatusByID: ["series": .next])
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: memory.taggedStatusByID,
            previouslySeenIDs: memory.seenIDs,
            refreshed: [series(), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    /// A tag that only came into being while the app was closed has no entry
    /// in the memory — nothing can prove it predates the completion, so it
    /// stays. This is also the upgrade path: no memory yet, no release.
    func testColdStartWithoutMemoryOfTheTagKeepsIt() {
        let memory = RecurringTagRelease.Memory(
            seenIDs: ["series"], taggedStatusByID: [:])
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: memory.taggedStatusByID,
            previouslySeenIDs: memory.seenIDs,
            refreshed: [series(), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    /// The lane changed during downtime — someone re-pulled the card
    /// somewhere. That decision is fresher than the memory; the tag stays.
    func testColdStartWithAChangedLaneKeepsTheTag() {
        let memory = RecurringTagRelease.Memory(
            seenIDs: ["series"], taggedStatusByID: ["series": .inProgress])
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: memory.taggedStatusByID,
            previouslySeenIDs: memory.seenIDs,
            refreshed: [series(status: .next), detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }

    // MARK: - Identity by creation date (10.08.2026)

    /// The headline case, and the forbidden direction: a task created *and*
    /// completed on another device between two refreshes has an identifier
    /// nobody has seen, so it passes the freshness filter. Under the old title
    /// rule it then took the tag off a card somebody had pulled. Its creation
    /// date is its own, so it is not an occurrence of anything.
    func testAForeignSameTitledTaskDoesNotReleaseTheTag() {
        let foreign = detachedOccurrence(
            id: "from-phone", created: Self.seriesCreated.addingTimeInterval(9_999))
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(), foreign],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [], "a namesake must never take a pulled card's tag")
    }

    /// The other half: renaming the series after the completion used to switch
    /// the rule off entirely, so the chore kept its tag every cycle.
    func testARenamedSeriesStillReleases() {
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(title: "Einkaufen neu"), detachedOccurrence(title: "Einkaufen")],
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["series"])
    }

    /// Uniqueness is judged among all live series of the list now, not only
    /// the tagged ones — stricter is the right direction for the one rule that
    /// can move a card without anybody seeing it.
    func testAnUntaggedSeriesSharingTheDateBlocksTheRelease() {
        let twin = series(id: "twin", title: "Etwas anderes", status: .backlog)
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(), twin, detachedOccurrence()],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [], "ambiguous identity means no proof")
    }

    func testAnOccurrenceWithoutACreationDateReleasesNothing() {
        let dateless = RecurringTagRelease.Snapshot(
            id: "detached", title: "Einkaufen", listID: "shared",
            isCompleted: true, isRecurring: false, status: .done, createdAt: nil)
        let released = RecurringTagRelease.releasedSeriesIDs(
            previousStatusByID: ["series": .next],
            previouslySeenIDs: ["series"],
            refreshed: [series(), dateless],
            deliberatelyMoved: [])
        XCTAssertEqual(released, [])
    }
}

/// The persisted half of the release rule: what survives a restart, and how
/// reading degrades when the stored data is missing, foreign, or from another
/// build.
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

    func testMemoryRoundTripsThroughDefaults() {
        let memory = RecurringTagRelease.Memory(
            seenIDs: ["a", "b", "c"],
            taggedStatusByID: ["a": .next, "b": .inProgress])
        memory.save()
        XCTAssertEqual(RecurringTagRelease.Memory.load(), memory)
    }

    /// Fresh install, or first launch of the build that introduced the
    /// memory: nothing stored means an empty memory, which makes the first
    /// session behave like the app always did.
    func testMissingKeyLoadsEmpty() {
        UserDefaults.standard.removeObject(forKey: RecurringTagRelease.Memory.storageKey)
        let memory = RecurringTagRelease.Memory.load()
        XCTAssertTrue(memory.seenIDs.isEmpty)
        XCTAssertTrue(memory.taggedStatusByID.isEmpty)
    }

    func testForeignTypesUnderTheKeyLoadEmpty() {
        UserDefaults.standard.set("not a dictionary", forKey: RecurringTagRelease.Memory.storageKey)
        let memory = RecurringTagRelease.Memory.load()
        XCTAssertTrue(memory.seenIDs.isEmpty)
        XCTAssertTrue(memory.taggedStatusByID.isEmpty)
    }

    /// A raw value from a build that renamed a case must cost only that
    /// entry, not the whole memory.
    func testUnknownStatusRawValueDropsOnlyThatEntry() {
        UserDefaults.standard.set(
            [
                "seen": ["a", "b"],
                "tagged": ["a": "next", "b": "someFutureLane"],
            ],
            forKey: RecurringTagRelease.Memory.storageKey)
        let memory = RecurringTagRelease.Memory.load()
        XCTAssertEqual(memory.seenIDs, ["a", "b"])
        XCTAssertEqual(memory.taggedStatusByID, ["a": .next])
    }

    /// Only working-lane tags are proof material; Backlog and Done entries
    /// never reach the persisted form no matter what the caller passes.
    func testMemoryKeepsOnlyWorkingLaneTags() {
        let memory = RecurringTagRelease.Memory(
            seenIDs: [],
            taggedStatusByID: ["a": .next, "b": .backlog, "c": .done, "d": .inProgress])
        XCTAssertEqual(memory.taggedStatusByID, ["a": .next, "d": .inProgress])
    }

    /// The stored raw values are a persisted contract — renaming a case
    /// silently voids every install's proof (same pin as `wipLimits`).
    func testStatusRawValuesAreStable() {
        XCTAssertEqual(KanbanStatus.next.rawValue, "next")
        XCTAssertEqual(KanbanStatus.inProgress.rawValue, "inProgress")
    }

}
