import XCTest

/// The board's own record of which card was pulled into which lane.
///
/// It exists because the previous form — a hashtag in the reminder's notes —
/// could be written by anyone with Reminders access, and was (measured
/// 12.–13.08.2026: a stale calendar client put `#next` back onto a series
/// nobody had pulled). These tests pin the properties that make the
/// replacement trustworthy: every doubt resolves to Backlog, the format cannot
/// express a completion, and one broken entry never costs the rest.
final class ColumnStateTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - The rule

    func testAnUnknownCardRestsInBacklog() {
        XCTAssertNil(ColumnState().lane(of: "never seen"))
        XCTAssertNil(ColumnState().pulledAt("never seen"))
    }

    func testAPullIsRecordedWithItsMoment() {
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        XCTAssertEqual(state.lane(of: "shop"), .next)
        XCTAssertEqual(state.pulledAt("shop"), t0)
    }

    /// Backlog is the absence of an entry, so a move back to it is a removal.
    /// Two ways to say "resting" would be two things that could drift apart.
    func testPullingIntoBacklogRemovesTheEntry() {
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        state.pull("shop", into: nil, at: t0.addingTimeInterval(60))
        XCTAssertNil(state.lane(of: "shop"))
        XCTAssertTrue(state.pulls.isEmpty)
    }

    /// A refresh re-confirming the lane a card already sits in must not make
    /// an old card look freshly pulled.
    func testReRecordingTheSameLaneKeepsTheOriginalMoment() {
        var state = ColumnState()
        state.pull("shop", into: .inProgress, at: t0)
        state.pull("shop", into: .inProgress, at: t0.addingTimeInterval(86_400))
        XCTAssertEqual(state.pulledAt("shop"), t0, "the dwell time may not reset on its own")
    }

    func testMovingBetweenWorkingLanesRestartsTheDwellTime() {
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        state.pull("shop", into: .inProgress, at: t0.addingTimeInterval(86_400))
        XCTAssertEqual(state.lane(of: "shop"), .inProgress)
        XCTAssertEqual(state.pulledAt("shop"), t0.addingTimeInterval(86_400))
    }

    func testReleasingSendsTheCardBackToBacklog() {
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        state.release("shop")
        XCTAssertNil(state.lane(of: "shop"))
    }

    /// EventKit hands out a fresh identifier when a deleted reminder is
    /// written back. Without rekeying, undoing a deletion would lose the lane.
    func testRekeyingCarriesThePullToTheNewIdentifier() {
        var state = ColumnState()
        state.pull("old", into: .inProgress, at: t0)
        state.rekey(from: "old", to: "new")
        XCTAssertNil(state.lane(of: "old"))
        XCTAssertEqual(state.lane(of: "new"), .inProgress)
        XCTAssertEqual(state.pulledAt("new"), t0, "rekeying is not re-pulling")
    }

    func testRekeyingAnUnknownIdentifierInventsNothing() {
        var state = ColumnState()
        state.rekey(from: "never seen", to: "new")
        XCTAssertTrue(state.pulls.isEmpty)
    }

    /// The storage format cannot express Backlog or Done — completion lives in
    /// EventKit, where everyone else reads it, and Backlog is the absence of
    /// an entry.
    func testOnlyWorkingLanesExist() {
        XCTAssertEqual(Set(ColumnState.Lane.allCases.map(\.rawValue)), ["next", "inProgress"])
    }

    /// The raw values are a persisted contract: renaming a case would send
    /// every pulled card on every install back to Backlog (same pin as
    /// `wipLimits`).
    func testLaneRawValuesAreStable() {
        XCTAssertEqual(ColumnState.Lane.next.rawValue, "next")
        XCTAssertEqual(ColumnState.Lane.inProgress.rawValue, "inProgress")
    }

    // MARK: - Bounds

    /// The only limit is the count. No expiry by age: a card may legitimately
    /// sit in a working lane for months, and an age limit would quietly push
    /// it back to Backlog.
    func testAnOldPullSurvivesIndefinitely() {
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        state.pull("other", into: .next, at: t0.addingTimeInterval(365 * 24 * 60 * 60))
        XCTAssertEqual(state.lane(of: "shop"), .next)
    }

    func testTheFileIsCappedOldestPullFirst() {
        var state = ColumnState()
        for index in 0...ColumnState.maxPulls {
            state.pull("card-\(index)", into: .next, at: t0.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(state.pulls.count, ColumnState.maxPulls)
        XCTAssertNil(state.lane(of: "card-0"), "the oldest pull is the one to go")
        XCTAssertEqual(state.lane(of: "card-\(ColumnState.maxPulls)"), .next)
    }

    // MARK: - The one-off import, stamped per list

    /// Per list, not per installation: a single flag would be set after the
    /// first refresh, and that refresh does not see a list switched off in
    /// Settings or an account that syncs in minutes later. Their tags would be
    /// lost for good.
    func testImportIsStampedPerList() {
        var state = ColumnState()
        XCTAssertFalse(state.hasImported(listID: "shared"))
        state.markImported(listID: "shared", at: t0)
        XCTAssertTrue(state.hasImported(listID: "shared"))
        XCTAssertFalse(state.hasImported(listID: "private"), "another list still has to be imported")
    }

    // MARK: - Persistence

    /// A temporary directory per test: unlike the UserDefaults suites, nothing
    /// here touches the developer's real state, so nothing has to be restored
    /// and the tests cannot depend on each other's order.
    private func temporaryURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ColumnStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("columns.json")
    }

    func testStateRoundTripsThroughTheFile() throws {
        let url = try temporaryURL()
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        state.pull("bath", into: .inProgress, at: t0.addingTimeInterval(30))
        state.markImported(listID: "shared", at: t0.addingTimeInterval(60))
        XCTAssertTrue(state.save(to: url))
        XCTAssertEqual(ColumnState.load(from: url), state)
    }

    func testAMissingFileLoadsEmpty() throws {
        XCTAssertEqual(ColumnState.load(from: try temporaryURL()), ColumnState())
    }

    func testGarbageInTheFileLoadsEmpty() throws {
        let url = try temporaryURL()
        try Data("kein JSON, nur Text".utf8).write(to: url)
        XCTAssertEqual(ColumnState.load(from: url), ColumnState())
    }

    /// A truncated write — the failure a non-atomic save would leave behind.
    func testATruncatedFileLoadsEmpty() throws {
        let url = try temporaryURL()
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        state.save(to: url)
        try Data(try Data(contentsOf: url).prefix(12)).write(to: url)
        XCTAssertEqual(ColumnState.load(from: url), ColumnState())
    }

    /// A payload from a build this one does not know is discarded rather than
    /// guessed at — every card rests in Backlog, which one drag repairs.
    func testAnUnknownFormatVersionLoadsEmpty() throws {
        let url = try temporaryURL()
        try Data(#"{"v": 99, "pulls": {}}"#.utf8).write(to: url)
        XCTAssertEqual(ColumnState.load(from: url), ColumnState())
    }

    /// One unreadable entry costs that entry, never the rest — the same
    /// tolerance `CorrectionLedger` reads its fields with. A `Codable` round
    /// trip would throw away all two hundred pulls over one bad line.
    func testABrokenEntryIsDroppedAndTheRestSurvives() throws {
        let url = try temporaryURL()
        try Data(#"""
        {"v": 1, "pulls": {
            "good": {"lane": "next", "at": 1800000000},
            "unknownLane": {"lane": "someFutureLane", "at": 1800000000},
            "laneIsBacklog": {"lane": "backlog", "at": 1800000000},
            "noDate": {"lane": "next"},
            "notAnObject": "nonsense"
        }}
        """#.utf8).write(to: url)
        let loaded = ColumnState.load(from: url)
        XCTAssertEqual(loaded.pulls.count, 1)
        XCTAssertEqual(loaded.lane(of: "good"), .next)
        XCTAssertNil(loaded.lane(of: "laneIsBacklog"), "a lane this build cannot express is not a lane")
    }

    func testSavingToNowhereFailsQuietly() {
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        XCTAssertFalse(state.save(to: nil), "a storage failure is reported, never thrown at the user")
    }
}
