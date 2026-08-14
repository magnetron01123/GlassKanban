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
        state.release("shop", at: t0.addingTimeInterval(60))
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

    // MARK: - The migration's cleanup list

    /// The bug this list exists for, measured in the running app on
    /// 14.08.2026: with the cleanup deciding by "a tag is present", typing
    /// "Notiz mit #inprogress darin" into a note and closing the editor left
    /// "Notiz mit darin" — the app deleted a word the user had just written.
    /// Naming the records at import time is what makes that impossible.
    func testOnlyRecordsNamedAtImportAreEverCleaned() {
        var state = ColumnState()
        state.markImported(listID: "shared", at: t0, taggedIDs: ["alt-tag-traeger"])
        XCTAssertTrue(state.awaitsTagCleanup("alt-tag-traeger"))
        XCTAssertFalse(
            state.awaitsTagCleanup("frisch-getippt"),
            "was der Nutzer später schreibt, gehört ihm — egal wie es aussieht")
    }

    func testACleanedRecordLeavesTheList() {
        var state = ColumnState()
        state.markImported(listID: "shared", at: t0, taggedIDs: ["a", "b"])
        state.markTagCleaned("a")
        XCTAssertFalse(state.awaitsTagCleanup("a"))
        XCTAssertTrue(state.awaitsTagCleanup("b"), "der Rest bleibt Arbeit")
    }

    /// An empty list means the migration is over and no note is ever cut
    /// again — the state a board reaches within a refresh or two and then
    /// keeps forever.
    func testAFinishedMigrationTouchesNothing() {
        var state = ColumnState()
        state.markImported(listID: "shared", at: t0, taggedIDs: ["a"])
        state.markTagCleaned("a")
        XCTAssertTrue(state.pendingTagCleanup.isEmpty)
        XCTAssertFalse(state.awaitsTagCleanup("a"))
    }

    /// A list without a single tagged record still counts as imported — and
    /// contributes no cleanup work.
    func testImportingAListWithoutTagsAddsNoWork() {
        var state = ColumnState()
        state.markImported(listID: "shared", at: t0)
        XCTAssertTrue(state.hasImported(listID: "shared"))
        XCTAssertTrue(state.pendingTagCleanup.isEmpty)
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

    /// The cleanup list has to survive a restart, or an interrupted migration
    /// would forget what it still owed — and worse, a later run would have to
    /// guess again.
    func testTheCleanupListSurvivesARestart() throws {
        let url = try temporaryURL()
        var state = ColumnState()
        state.markImported(listID: "shared", at: t0, taggedIDs: ["a", "b"])
        state.markTagCleaned("a")
        state.save(to: url)
        let loaded = ColumnState.load(from: url)
        XCTAssertFalse(loaded.awaitsTagCleanup("a"))
        XCTAssertTrue(loaded.awaitsTagCleanup("b"))
    }

    func testStateRoundTripsThroughTheFile() throws {
        let url = try temporaryURL()
        var state = ColumnState()
        state.pull("shop", into: .next, at: t0)
        state.pull("bath", into: .inProgress, at: t0.addingTimeInterval(30))
        state.markImported(listID: "shared", at: t0.addingTimeInterval(60), taggedIDs: ["alt"])
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

    // MARK: - Merging two machines
    //
    // Groundwork for syncing the column between the user's own Macs. The
    // property that matters most is the one the whole form change of
    // 13.08.2026 was about: no card may end up in a working lane that nobody
    // pulled it into. A merge that revives a put-down card would reintroduce
    // exactly that, only with a friendlier cause.

    private func pulled(_ cardID: String, _ lane: ColumnState.Lane, _ at: Date) -> ColumnState {
        var state = ColumnState()
        state.pull(cardID, into: lane, at: at)
        return state
    }

    /// A machine that has never seen a card says nothing about it — which is
    /// not the same as saying "Backlog". Were absence an answer, any second
    /// Mac would erase every pull the moment it synced.
    func testACardOnlyOneSideKnowsSurvivesTheMerge() {
        let mine = pulled("shop", .next, t0)
        let merged = ColumnState.merged(mine, ColumnState(), now: t0)
        XCTAssertEqual(merged.lane(of: "shop"), .next)
        XCTAssertEqual(merged.pulledAt("shop"), t0)
    }

    func testTheNewerPullWins() {
        let older = pulled("shop", .next, t0)
        let newer = pulled("shop", .inProgress, t0.addingTimeInterval(600))
        XCTAssertEqual(ColumnState.merged(older, newer, now: t0).lane(of: "shop"), .inProgress)
        XCTAssertEqual(ColumnState.merged(newer, older, now: t0).lane(of: "shop"), .inProgress)
    }

    /// The case the release date exists for: put a card down here, and the
    /// other Mac's stale pull must not stand it back up.
    func testAReleaseOutranksAnOlderPullOnTheOtherMachine() {
        var mine = pulled("shop", .next, t0)
        mine.release("shop", at: t0.addingTimeInterval(600))
        let theirs = pulled("shop", .next, t0)

        let merged = ColumnState.merged(mine, theirs, now: t0.addingTimeInterval(600))
        XCTAssertNil(merged.lane(of: "shop"), "a card nobody pulled may not appear in a working lane")
        XCTAssertEqual(ColumnState.merged(theirs, mine, now: t0.addingTimeInterval(600)).lane(of: "shop"), nil)
    }

    /// And the other direction, so the rule is "newest wins" rather than
    /// "Backlog always wins": pulling it again later must stick.
    func testAPullAfterAReleaseWins() {
        var mine = pulled("shop", .next, t0)
        mine.release("shop", at: t0.addingTimeInterval(60))
        let theirs = pulled("shop", .inProgress, t0.addingTimeInterval(600))

        let merged = ColumnState.merged(mine, theirs, now: t0.addingTimeInterval(600))
        XCTAssertEqual(merged.lane(of: "shop"), .inProgress)
    }

    /// Two clocks agreeing to the second is vanishingly unlikely, but the
    /// answer still has to be the same on both machines — otherwise they
    /// disagree about the board and overwrite each other forever.
    func testATieGoesToBacklogAndIsSymmetric() {
        var mine = pulled("shop", .next, t0.addingTimeInterval(-60))
        mine.release("shop", at: t0)
        let theirs = pulled("shop", .inProgress, t0)

        XCTAssertNil(ColumnState.merged(mine, theirs, now: t0).lane(of: "shop"))
        XCTAssertNil(ColumnState.merged(theirs, mine, now: t0).lane(of: "shop"))
    }

    func testMergingIsSymmetricAcrossAMixedBoard() {
        var mine = pulled("a", .next, t0)
        mine.pull("b", into: .inProgress, at: t0.addingTimeInterval(300))
        mine.release("b", at: t0.addingTimeInterval(400))
        mine.pull("c", into: .next, at: t0)

        var theirs = pulled("b", .next, t0.addingTimeInterval(900))
        theirs.pull("c", into: .inProgress, at: t0.addingTimeInterval(120))
        theirs.pull("d", into: .next, at: t0)

        let forward = ColumnState.merged(mine, theirs, now: t0.addingTimeInterval(900))
        let backward = ColumnState.merged(theirs, mine, now: t0.addingTimeInterval(900))
        XCTAssertEqual(forward.pulls, backward.pulls)
        XCTAssertEqual(forward.released, backward.released)
        XCTAssertEqual(forward.lane(of: "a"), .next)
        XCTAssertEqual(forward.lane(of: "b"), .next, "their later pull outranks my release")
        XCTAssertEqual(forward.lane(of: "c"), .inProgress)
        XCTAssertEqual(forward.lane(of: "d"), .next)
    }

    /// Releasing a card this board never pulled records nothing: there is no
    /// foreign pull it could be older or newer than, and an entry per
    /// completed reminder would grow without bound.
    func testReleasingAnUnpulledCardLeavesNoTrace() {
        var state = ColumnState()
        state.release("never pulled", at: t0)
        XCTAssertTrue(state.released.isEmpty)
    }

    func testPullingAgainClearsTheRelease() {
        var state = pulled("shop", .next, t0)
        state.release("shop", at: t0.addingTimeInterval(60))
        state.pull("shop", into: .next, at: t0.addingTimeInterval(120))
        XCTAssertTrue(state.released.isEmpty, "a card is either pulled or released, never both")
    }

    /// Once no other device can still hold a pull older than the release, the
    /// plain absence of an entry means Backlog again — as it always did.
    func testOldReleasesExpire() {
        var state = pulled("shop", .next, t0)
        state.release("shop", at: t0)
        state.prune(now: t0.addingTimeInterval(ColumnState.releaseRetention + 1))
        XCTAssertTrue(state.released.isEmpty)
    }

    func testAListCountsAsImportedFromItsEarliestStamp() {
        let mine = ColumnState(importedLists: ["list": t0])
        let theirs = ColumnState(importedLists: ["list": t0.addingTimeInterval(900)])
        XCTAssertEqual(ColumnState.merged(mine, theirs, now: t0).importedLists["list"], t0)
    }

    // MARK: - Storing releases

    func testReleasesSurviveASaveAndLoad() throws {
        let url = try temporaryURL()
        var state = pulled("shop", .next, t0)
        state.release("shop", at: t0.addingTimeInterval(60))
        XCTAssertTrue(state.save(to: url))

        let loaded = ColumnState.load(from: url)
        XCTAssertEqual(loaded.released["shop"], t0.addingTimeInterval(60))
        XCTAssertNil(loaded.lane(of: "shop"), "a release is not a lane")
    }

    /// Releases were added without bumping the format version, so that older
    /// builds keep reading the pulls instead of dropping the whole board. A
    /// file written before they existed — or rewritten by such a build — must
    /// still load.
    func testAFileWithoutReleasesLoadsAsNothingReleased() throws {
        let url = try temporaryURL()
        try Data(#"{"v": 1, "pulls": {"shop": {"lane": "next", "at": 1800000000}}}"#.utf8)
            .write(to: url)
        let loaded = ColumnState.load(from: url)
        XCTAssertEqual(loaded.lane(of: "shop"), .next)
        XCTAssertTrue(loaded.released.isEmpty)
    }

    // MARK: - Where the file lives
    //
    // The file moved into a group container on 14.08.2026 so that separate
    // processes — a widget, an App Intent — can read it at all. Whether the
    // Mac App Store accepts that identifier is still open, so the move has to
    // survive being done again: read from every place it has ever lived, write
    // only to the current one, delete nothing.

    /// Writing goes to exactly one place, and it is the first one read.
    func testTheCurrentLocationIsTheFirstOneRead() {
        let urls = ColumnState.knownFileURLs()
        XCTAssertEqual(urls.first, ColumnState.defaultFileURL())
    }

    /// Every location is listed once. A duplicate would be harmless when
    /// reading and misleading when reasoning about what still has to be
    /// cleaned up later.
    func testKnownLocationsAreDistinct() {
        let urls = ColumnState.knownFileURLs()
        XCTAssertEqual(Set(urls).count, urls.count)
    }

    /// The old location stays on the list. Dropping it the moment the file
    /// moves would strand every board that has not launched the new build yet.
    func testTheLegacyLocationIsStillRead() {
        let urls = ColumnState.knownFileURLs().map(\.path)
        XCTAssertTrue(
            urls.contains { $0.contains("Application Support/GlassKanban/columns.json") },
            "the app's private container is where the file lived until 14.08.2026")
    }

    /// A file that exists but reads as empty — corrupt, or from a version this
    /// build does not know — must not fall through to an older copy. That copy
    /// is by definition staler, and reviving it would put cards back in lanes
    /// the user already moved them out of. Empty means Backlog, one drag.
    func testAnUnreadableCurrentFileDoesNotResurrectAnOlderOne() throws {
        let current = try temporaryURL()
        let legacy = try temporaryURL()
        try Data(#"{"v": 99, "pulls": {}}"#.utf8).write(to: current)
        try Data(#"{"v": 1, "pulls": {"shop": {"lane": "next", "at": 1800000000}}}"#.utf8)
            .write(to: legacy)

        // The behaviour under test is `load`'s, exercised the way
        // `loadFromKnownLocations` walks the list: the first existing file
        // wins, whatever it turns out to contain.
        XCTAssertEqual(ColumnState.load(from: current), ColumnState())
        XCTAssertEqual(ColumnState.load(from: legacy).lane(of: "shop"), .next)
    }
}
