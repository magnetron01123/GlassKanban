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

    private func series(
        id: String = "series", title: String = "Einkaufen", listID: String = "shared",
        status: KanbanStatus = .next, isRecurring: Bool = true
    ) -> RecurringTagRelease.Snapshot {
        RecurringTagRelease.Snapshot(
            id: id, title: title, listID: listID,
            isCompleted: false, isRecurring: isRecurring, status: status)
    }

    private func detachedOccurrence(
        id: String = "detached", title: String = "Einkaufen", listID: String = "shared"
    ) -> RecurringTagRelease.Snapshot {
        RecurringTagRelease.Snapshot(
            id: id, title: title, listID: listID,
            isCompleted: true, isRecurring: false, status: .done)
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

    /// Two same-titled live series in one list make the match ambiguous.
    /// Fail closed: a kept tag costs one drag, a wrongly released one breaks
    /// the pull principle.
    func testTwoSameTitledSeriesInOneListReleaseNothing() {
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
                series(id: "bath", title: "Joris baden", status: .inProgress),
                detachedOccurrence(id: "shop-done", title: "Einkaufen"),
                detachedOccurrence(id: "bath-done", title: "Joris baden"),
            ],
            deliberatelyMoved: [])
        XCTAssertEqual(released, ["shop", "bath"])
    }
}
