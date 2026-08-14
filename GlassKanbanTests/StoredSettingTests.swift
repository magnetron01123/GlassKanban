import XCTest

/// What the app stores in `UserDefaults`, and which of it follows the user to
/// another Mac.
///
/// The classification lives in a `switch` rather than in a document so that a
/// new setting cannot quietly skip the question — that part the compiler
/// enforces. What it cannot enforce is that the keys keep matching what is
/// already on disk, and that the two records which must never travel never
/// start travelling. That is what these tests are for.
final class StoredSettingTests: XCTestCase {

    /// **A persisted contract.** These strings are what is already written in
    /// every user's defaults; renaming one does not migrate the setting, it
    /// silently resets it to the default and looks like the app forgot.
    func testKeysArePinnedToWhatIsAlreadyStored() {
        XCTAssertEqual(StoredSetting.excludedCalendars.key, "excludedCalendarIDs")
        XCTAssertEqual(StoredSetting.wipLimits.key, "wipLimits")
        XCTAssertEqual(StoredSetting.completionSound.key, "completionSoundEnabled")
        XCTAssertEqual(StoredSetting.foldNotYetDue.key, "foldNotYetDue")
        XCTAssertEqual(StoredSetting.appearance.key, "appAppearance")
        XCTAssertEqual(StoredSetting.correctionLedger.key, "correctionLedger")
        XCTAssertEqual(StoredSetting.tagReleaseMemory.key, "tagReleaseMemory")
    }

    func testKeysAreDistinct() {
        let keys = StoredSetting.allCases.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "two settings sharing a key would overwrite each other")
    }

    /// The `CorrectionLedger` records which values *this* board displaced, so
    /// it can recognise its own value coming back. Shared between two Macs,
    /// each would answer the other's legitimate edit as a stale foreign write —
    /// two boards in a write loop over the user's real reminders. SPEC.md lists
    /// "a second Mac with this app" as a foreign writer exactly so this holds.
    func testTheRecordsOfWhatThisMachineDidNeverTravel() {
        XCTAssertEqual(StoredSetting.correctionLedger.scope, .thisDevice)
        XCTAssertEqual(StoredSetting.tagReleaseMemory.scope, .thisDevice)
        XCTAssertFalse(StoredSetting.syncable.contains(.correctionLedger))
        XCTAssertFalse(StoredSetting.syncable.contains(.tagReleaseMemory))
    }

    /// A WIP limit that counts per device is not a WIP limit: two Macs at three
    /// each allow six started tasks, and the friction dialog never fires.
    func testThePoliciesTheUserSetsTravel() {
        XCTAssertEqual(StoredSetting.wipLimits.scope, .everyDevice)
        XCTAssertEqual(StoredSetting.foldNotYetDue.scope, .everyDevice)
    }

    /// Screen and room, not user — and `excludedCalendars` stays put until
    /// `EKCalendar.calendarIdentifier` has been measured across two Macs (M4).
    func testWhatBelongsToTheMachineStaysOnIt() {
        XCTAssertEqual(StoredSetting.appearance.scope, .thisDevice)
        XCTAssertEqual(StoredSetting.completionSound.scope, .thisDevice)
        XCTAssertEqual(StoredSetting.excludedCalendars.scope, .thisDevice)
    }

    /// Guards the list the future transport will iterate over: if a new setting
    /// is added as travelling, this test is where that decision gets noticed.
    func testExactlyTheExpectedSettingsTravel() {
        XCTAssertEqual(Set(StoredSetting.syncable), [.wipLimits, .foldNotYetDue])
    }
}
