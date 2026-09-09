import XCTest

/// The one EventKit refusal the board reports as a fact instead of as its own
/// failure: the system declining to move a task between two lists.
///
/// Measured 09.09.2026 — see `ReminderWriteFailure` for the whole finding. The
/// short version: two of six lists on the measured account refuse every move,
/// in both directions, and nothing on `EKCalendar` says which ones in advance.
/// These tests pin the recognition, because getting it wrong is silent in both
/// directions: too narrow and the user sees a raw `com.apple.reminderkit`
/// number again, too wide and a genuine save failure is dressed up as a
/// harmless fact and the edit is quietly lost.
final class ReminderWriteFailureTests: XCTestCase {

    private func error(domain: String, code: Int) -> NSError {
        NSError(domain: domain, code: code)
    }

    /// **A contract with Apple, not with us.** These two values are what
    /// EventKit hands back; they are pinned so that a well-meant "tidy-up"
    /// cannot silently turn the message back into a number.
    func testTheRefusalIsIdentifiedByDomainAndCode() {
        XCTAssertEqual(ReminderWriteFailure.reminderKitDomain, "com.apple.reminderkit")
        XCTAssertEqual(ReminderWriteFailure.listMoveRefusedCode, -3002)
    }

    func testTheListRefusalIsRecognised() {
        XCTAssertTrue(ReminderWriteFailure.isListMoveRefused(
            error(domain: "com.apple.reminderkit", code: -3002)))
    }

    /// The same number in another domain is a different fault entirely, and
    /// has to keep reporting itself as one — otherwise a real, losable write
    /// failure would show up as "the card stays in its list" and the user's
    /// edit would be gone with a reassuring message on top.
    func testTheSameCodeInAnotherDomainIsNotIt() {
        XCTAssertFalse(ReminderWriteFailure.isListMoveRefused(
            error(domain: "com.apple.eventkit", code: -3002)))
        XCTAssertFalse(ReminderWriteFailure.isListMoveRefused(
            error(domain: NSCocoaErrorDomain, code: -3002)))
    }

    /// And every other ReminderKit fault stays an ordinary failure: a
    /// read-only list, a deleted reminder, a store that will not commit.
    func testOtherReminderKitFailuresAreNotIt() {
        for code in [-3001, -3003, 0, 4097] {
            XCTAssertFalse(
                ReminderWriteFailure.isListMoveRefused(
                    error(domain: "com.apple.reminderkit", code: code)),
                "\(code) is not the list refusal")
        }
    }

    /// Matched on the numbers, never on the text: Apple's message is localised
    /// and Apple's to reword, and a board that reads it would start reporting
    /// raw error numbers again the first time it changed.
    func testTheMessageTextIsNotWhatIsMatchedOn() {
        let withoutMessage = error(domain: "com.apple.reminderkit", code: -3002)
        let withForeignMessage = NSError(
            domain: "com.apple.reminderkit", code: -3002,
            userInfo: [NSLocalizedDescriptionKey: "völlig anderer Wortlaut"])
        XCTAssertTrue(ReminderWriteFailure.isListMoveRefused(withoutMessage))
        XCTAssertTrue(ReminderWriteFailure.isListMoveRefused(withForeignMessage))
    }
}
