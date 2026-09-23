import XCTest

/// Parsing of `calendarItemExternalIdentifier`, the first of the two ways the
/// double-click deep link resolves a reminder. The identifier's format is
/// undocumented, so what counts as a usable one is worth stating explicitly —
/// a wrong answer here builds a URL that silently opens the wrong thing.
final class ReminderDeepLinkTests: XCTestCase {

    private let uuid = "3F2504E0-4F89-11D3-9A0C-0305E82C3301"

    /// The usual iCloud form.
    func testPrefixedIdentifierYieldsTheUUID() {
        XCTAssertEqual(
            ReminderDeepLink.uuidString(fromExternalIdentifier: "x-apple-reminder://\(uuid)"),
            uuid)
    }

    func testBareUUIDIsAccepted() {
        XCTAssertEqual(ReminderDeepLink.uuidString(fromExternalIdentifier: uuid), uuid)
    }

    /// Anything else is rejected rather than passed through: the caller then
    /// falls back to the private backing object, and failing that simply opens
    /// the Reminders app — both better than a URL built from a stray string.
    func testUnknownFormatsAreRejected() {
        XCTAssertNil(ReminderDeepLink.uuidString(fromExternalIdentifier: nil))
        XCTAssertNil(ReminderDeepLink.uuidString(fromExternalIdentifier: ""))
        XCTAssertNil(ReminderDeepLink.uuidString(fromExternalIdentifier: "irgendwas"))
        XCTAssertNil(ReminderDeepLink.uuidString(fromExternalIdentifier: "x-apple-reminder://"))
        // A local (non-CloudKit) reminder hands back an identifier that is not
        // a UUID at all.
        XCTAssertNil(ReminderDeepLink.uuidString(fromExternalIdentifier: "1A2B3C"))
    }
}
