import XCTest

/// The board's own record of each card's T-shirt size.
///
/// Pins what makes the file as trustworthy as `columns.json`: a removal is a
/// statement that survives a merge, one broken entry never costs the rest,
/// and the stored letters never change under a user's data.
final class SizeStateTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - The rule

    func testAnUnsizedCardHasNoSize() {
        XCTAssertNil(SizeState().size(of: "never seen"))
    }

    func testASizeIsRecordedWithItsMoment() {
        var state = SizeState()
        state.set(.medium, for: "shop", at: t0)
        XCTAssertEqual(state.size(of: "shop"), .medium)
        XCTAssertEqual(state.entries["shop"]?.at, t0)
    }

    /// Re-setting the same size is not a decision; its date must not move, or
    /// it would outrank a real change made on another Mac.
    func testSettingTheSameSizeAgainKeepsTheMoment() {
        var state = SizeState()
        state.set(.large, for: "shop", at: t0)
        state.set(.large, for: "shop", at: t0.addingTimeInterval(60))
        XCTAssertEqual(state.entries["shop"]?.at, t0)
    }

    /// Removing leaves a dated tombstone, so a merge cannot resurrect the size.
    func testRemovingLeavesATombstone() {
        var state = SizeState()
        state.set(.small, for: "shop", at: t0)
        state.set(nil, for: "shop", at: t0.addingTimeInterval(60))
        XCTAssertNil(state.size(of: "shop"))
        XCTAssertEqual(state.entries["shop"], .init(size: nil, at: t0.addingTimeInterval(60)))
    }

    /// Clearing a card that never had a size says nothing and stores nothing.
    func testRemovingFromAnUnsizedCardStoresNothing() {
        var state = SizeState()
        state.set(nil, for: "shop", at: t0)
        XCTAssertTrue(state.entries.isEmpty)
    }

    func testRekeyingCarriesTheSizeToTheNewIdentity() {
        var state = SizeState()
        state.set(.medium, for: "old", at: t0)
        state.rekey(from: "old", to: "new")
        XCTAssertNil(state.size(of: "old"))
        XCTAssertEqual(state.size(of: "new"), .medium)
    }

    func testPruningDropsOnlyExpiredTombstones() {
        var state = SizeState()
        state.set(.large, for: "kept", at: t0)
        state.set(.small, for: "gone", at: t0)
        state.set(nil, for: "gone", at: t0)
        state.set(.small, for: "fresh", at: t0)
        let later = t0.addingTimeInterval(SizeState.tombstoneRetention + 60)
        state.set(nil, for: "fresh", at: later)
        state.prune(now: later)
        XCTAssertEqual(state.size(of: "kept"), .large, "a size never expires")
        XCTAssertNil(state.entries["gone"])
        XCTAssertNotNil(state.entries["fresh"], "a recent removal is still remembered")
    }

    func testTheCapKeepsTheNewestDecisions() {
        var state = SizeState()
        for index in 0...SizeState.maxEntries {
            state.set(.small, for: "card\(index)", at: t0.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(state.entries.count, SizeState.maxEntries)
        XCTAssertNil(state.entries["card0"], "the oldest decision goes first")
        XCTAssertNotNil(state.entries["card\(SizeState.maxEntries)"])
    }

    // MARK: - Merging two Macs

    func testTheNewerDecisionWins() {
        var mine = SizeState(), theirs = SizeState()
        mine.set(.small, for: "shop", at: t0)
        theirs.set(.large, for: "shop", at: t0.addingTimeInterval(60))
        XCTAssertEqual(SizeState.merged(mine, theirs, now: t0).size(of: "shop"), .large)
        XCTAssertEqual(SizeState.merged(theirs, mine, now: t0).size(of: "shop"), .large)
    }

    func testANewerRemovalBeatsAnOlderSize() {
        var mine = SizeState(), theirs = SizeState()
        mine.set(.medium, for: "shop", at: t0)
        theirs.set(.medium, for: "shop", at: t0)
        theirs.set(nil, for: "shop", at: t0.addingTimeInterval(60))
        XCTAssertNil(SizeState.merged(mine, theirs, now: t0).size(of: "shop"))
    }

    func testATieBetweenASizeAndARemovalGoesToTheRemoval() {
        let mine = SizeState(entries: ["shop": .init(size: .large, at: t0)])
        let theirs = SizeState(entries: ["shop": .init(size: nil, at: t0)])
        XCTAssertNil(SizeState.merged(mine, theirs, now: t0).size(of: "shop"))
        XCTAssertNil(SizeState.merged(theirs, mine, now: t0).size(of: "shop"))
    }

    func testATieBetweenTwoSizesIsTheSameOnBothMacs() {
        let mine = SizeState(entries: ["shop": .init(size: .large, at: t0)])
        let theirs = SizeState(entries: ["shop": .init(size: .small, at: t0)])
        XCTAssertEqual(
            SizeState.merged(mine, theirs, now: t0),
            SizeState.merged(theirs, mine, now: t0))
    }

    func testACardOnlyOneMacSizedIsKept() {
        var mine = SizeState()
        mine.set(.medium, for: "shop", at: t0)
        XCTAssertEqual(SizeState.merged(mine, SizeState(), now: t0).size(of: "shop"), .medium)
        XCTAssertEqual(SizeState.merged(SizeState(), mine, now: t0).size(of: "shop"), .medium)
    }

    // MARK: - Persistence

    private func temporaryURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SizeStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("sizes.json")
    }

    func testTheStateSurvivesARoundTrip() throws {
        let url = try temporaryURL()
        var state = SizeState()
        state.set(.small, for: "a", at: t0)
        state.set(.large, for: "b", at: t0)
        state.set(nil, for: "b", at: t0.addingTimeInterval(1))
        XCTAssertTrue(state.save(to: url))
        XCTAssertEqual(SizeState.load(from: url), state)
    }

    func testAMissingFileReadsAsEmpty() throws {
        XCTAssertEqual(SizeState.load(from: try temporaryURL()), SizeState())
        XCTAssertEqual(SizeState.load(from: nil), SizeState())
    }

    func testGarbageReadsAsEmpty() throws {
        let url = try temporaryURL()
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(SizeState.load(from: url), SizeState())
    }

    func testAnUnknownVersionIsDiscarded() throws {
        let url = try temporaryURL()
        try Data(#"{"v": 99, "sizes": {"a": {"size": "m", "at": 1}}}"#.utf8).write(to: url)
        XCTAssertEqual(SizeState.load(from: url), SizeState())
    }

    /// One unreadable entry costs only itself — and an unknown letter is not
    /// misread as a removal.
    func testOneBrokenEntryCostsOnlyItself() throws {
        let url = try temporaryURL()
        let json = #"{"v": 1, "sizes": {"a": {"size": "m", "at": 1}, "b": {"size": "xxl", "at": 1}, "c": "junk", "d": {"at": 1}}}"#
        try Data(json.utf8).write(to: url)
        let loaded = SizeState.load(from: url)
        XCTAssertEqual(loaded.size(of: "a"), .medium)
        XCTAssertNil(loaded.entries["b"])
        XCTAssertNil(loaded.entries["c"])
        XCTAssertEqual(loaded.entries["d"], .init(size: nil, at: Date(timeIntervalSince1970: 1)))
    }

    /// The raw values are what `sizes.json` holds. Renaming one would silently
    /// drop every stored size of that kind.
    func testSizeRawValuesAreStable() {
        XCTAssertEqual(TicketSize.allCases.map(\.rawValue), ["s", "m", "l"])
        XCTAssertEqual(TicketSize.allCases.map(\.letter), ["S", "M", "L"])
    }
}
