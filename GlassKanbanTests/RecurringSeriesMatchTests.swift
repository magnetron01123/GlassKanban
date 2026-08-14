import XCTest

/// Which live series a completed reminder belongs to.
///
/// Matched on the creation date, because a detached occurrence carries the
/// *series'* — measured bit for bit against real EventKit on 10.08.2026,
/// through the app's own completion, over an iCloud round trip, and from a
/// phone. An ordinary task that merely shares the title carries its own.
final class RecurringSeriesMatchTests: XCTestCase {

    private let seriesCreated = Date(timeIntervalSinceReferenceDate: 808_083_284.719828010)
    private let ownCreated = Date(timeIntervalSinceReferenceDate: 808_083_284.719745040)

    private func series(
        id: String = "series", listID: String = "shared", created: Date? = nil
    ) -> RecurringSeriesMatch.Record {
        RecurringSeriesMatch.Record(
            id: id, listID: listID, createdAt: created ?? seriesCreated,
            isCompleted: false, isRecurring: true)
    }

    private func occurrence(
        id: String = "detached", listID: String = "shared", created: Date? = nil
    ) -> RecurringSeriesMatch.Record {
        RecurringSeriesMatch.Record(
            id: id, listID: listID, createdAt: created ?? seriesCreated,
            isCompleted: true, isRecurring: false)
    }

    func testAnOccurrenceFindsItsSeries() {
        let match = RecurringSeriesMatch.seriesID(
            of: occurrence(), among: [series(), occurrence()])
        XCTAssertEqual(match, "series")
    }

    /// The "too sharp" failure: a one-off named exactly like a live series
    /// could never be restored from Erledigt. It has its own creation date, so
    /// it is not an occurrence of anything.
    func testAOneOffWithTheSameTitleIsNotAnOccurrence() {
        let oneOff = occurrence(id: "one-off", created: ownCreated)
        XCTAssertNil(RecurringSeriesMatch.seriesID(of: oneOff, among: [series()]))
    }

    /// The "too blunt" failure: renaming the series after the completion used
    /// to disable the guard entirely. Titles play no part here, so it does
    /// not matter what either record is called.
    func testARenamedSeriesStillMatches() {
        let match = RecurringSeriesMatch.seriesID(of: occurrence(), among: [series()])
        XCTAssertEqual(match, "series", "the title is not part of identity")
    }

    func testTheSameCreationDateInAnotherListDoesNotMatch() {
        let elsewhere = series(id: "other-list-series", listID: "private")
        XCTAssertNil(RecurringSeriesMatch.seriesID(of: occurrence(), among: [elsewhere]))
    }

    /// Two live series sharing a creation date make the match ambiguous. Fail
    /// closed — a wrong answer either strands a card in Erledigt or takes a
    /// tag off work somebody pulled.
    func testTwoSeriesWithTheSameCreationDateYieldNothing() {
        let match = RecurringSeriesMatch.seriesID(
            of: occurrence(), among: [series(id: "a"), series(id: "b")])
        XCTAssertNil(match)
    }

    func testAnOccurrenceWithoutACreationDateMatchesNothing() {
        let undated = RecurringSeriesMatch.Record(
            id: "detached", listID: "shared", createdAt: nil,
            isCompleted: true, isRecurring: false)
        XCTAssertNil(RecurringSeriesMatch.seriesID(of: undated, among: [series()]))
    }

    func testASeriesWithoutACreationDateIsNeverACandidate() {
        let undatedSeries = RecurringSeriesMatch.Record(
            id: "series", listID: "shared", createdAt: nil,
            isCompleted: false, isRecurring: true)
        XCTAssertNil(RecurringSeriesMatch.seriesID(of: occurrence(), among: [undatedSeries]))
    }

    /// An open reminder is not an occurrence of anything, whatever its date.
    func testAnOpenRecordIsNotAnOccurrence() {
        let open = RecurringSeriesMatch.Record(
            id: "open", listID: "shared", createdAt: seriesCreated,
            isCompleted: false, isRecurring: false)
        XCTAssertNil(RecurringSeriesMatch.seriesID(of: open, among: [series()]))
    }

    func testANonRecurringCandidateIsIgnored() {
        let plain = RecurringSeriesMatch.Record(
            id: "plain", listID: "shared", createdAt: seriesCreated,
            isCompleted: false, isRecurring: false)
        XCTAssertNil(RecurringSeriesMatch.seriesID(of: occurrence(), among: [plain]))
    }

    func testACompletedCandidateIsIgnored() {
        let otherOccurrence = occurrence(id: "older-turn")
        XCTAssertNil(RecurringSeriesMatch.seriesID(
            of: occurrence(), among: [otherOccurrence]))
    }

    /// Equality, never nearness. The measurement showed reminders written in
    /// one commit differ by microseconds, so a tolerance window would make
    /// them each other's occurrences.
    func testAMicrosecondApartIsNotAMatch() {
        let almost = series(created: seriesCreated.addingTimeInterval(0.000_018))
        XCTAssertNil(RecurringSeriesMatch.seriesID(of: occurrence(), among: [almost]))
    }

    // MARK: - Re-opened turns (11.08.2026)

    /// An open record carrying its series' creation date to the microsecond.
    /// Measured: only un-ticking a finished turn produces this.
    private func revived(
        id: String = "revived", listID: String = "shared", created: Date? = nil
    ) -> RecurringSeriesMatch.Record {
        RecurringSeriesMatch.Record(
            id: id, listID: listID, createdAt: created ?? seriesCreated,
            isCompleted: false, isRecurring: false)
    }

    func testAReopenedTurnIsRecognised() {
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(among: [series(), revived()])
        XCTAssertEqual(ids, ["revived"])
    }

    /// The headline: an ordinary open task must never be mistaken for one.
    /// It carries its own creation date, whatever it is called.
    func testAnOrdinaryOpenTaskIsLeftAlone() {
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(
            among: [series(), revived(id: "own", created: ownCreated)])
        XCTAssertEqual(ids, [])
    }

    /// A finished turn is the normal, expected state — it belongs in Erledigt
    /// and is not what this rule looks for.
    func testACompletedOccurrenceIsNotRevived() {
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(among: [series(), occurrence()])
        XCTAssertEqual(ids, [])
    }

    /// The series itself is open and shares its own date; hiding it would
    /// take the actual chore off the board.
    func testTheSeriesItselfIsNeverHidden() {
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(among: [series()])
        XCTAssertEqual(ids, [])
    }

    /// Without a live series there is nothing the record could be a turn of —
    /// after the series is deleted it is an ordinary task again and reappears.
    func testWithoutALiveSeriesNothingIsHidden() {
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(among: [revived()])
        XCTAssertEqual(ids, [])
    }

    func testAnotherListDoesNotCount() {
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(
            among: [series(), revived(listID: "private")])
        XCTAssertEqual(ids, [])
    }

    /// Two series sharing a creation date make the match ambiguous, and
    /// ambiguity is shown rather than hidden — the same direction every other
    /// doubt in this type falls in.
    func testAmbiguityIsShownNotHidden() {
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(
            among: [series(id: "a"), series(id: "b"), revived()])
        XCTAssertEqual(ids, [])
    }

    func testARecordWithoutACreationDateIsShown() {
        let dateless = RecurringSeriesMatch.Record(
            id: "dateless", listID: "shared", createdAt: nil,
            isCompleted: false, isRecurring: false)
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(among: [series(), dateless])
        XCTAssertEqual(ids, [])
    }

    /// Several chores re-opened at once are each judged on their own series.
    func testTwoIndependentRevivalsAreBothFound() {
        let other = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let ids = RecurringSeriesMatch.revivedOccurrenceIDs(among: [
            series(id: "s1"),
            series(id: "s2", created: other),
            revived(id: "r1"),
            revived(id: "r2", created: other),
        ])
        XCTAssertEqual(ids, ["r1", "r2"])
    }
}
