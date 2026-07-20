import XCTest

/// `BacklogTicketTargeting.targetCalendarIdentifier(...)` — the pure
/// selection rule behind the Backlog "+" button. Prefers Reminders' own
/// default list, falls back to the first list visible on the board so a new
/// ticket is never created somewhere the user can't see it.
final class BacklogTicketCreationTests: XCTestCase {

    func testDefaultCalendarWinsWhenNotExcluded() {
        let result = BacklogTicketTargeting.targetCalendarIdentifier(
            defaultCalendarID: "default",
            excludedIDs: [],
            includedCalendarIDsInDisplayOrder: ["default", "other"])
        XCTAssertEqual(result, "default")
    }

    func testFallsBackToFirstIncludedWhenDefaultIsExcluded() {
        let result = BacklogTicketTargeting.targetCalendarIdentifier(
            defaultCalendarID: "default",
            excludedIDs: ["default"],
            includedCalendarIDsInDisplayOrder: ["other", "third"])
        XCTAssertEqual(result, "other")
    }

    func testFallsBackToFirstIncludedWhenNoDefaultExists() {
        let result = BacklogTicketTargeting.targetCalendarIdentifier(
            defaultCalendarID: nil,
            excludedIDs: [],
            includedCalendarIDsInDisplayOrder: ["other"])
        XCTAssertEqual(result, "other")
    }

    func testNilWhenDefaultExcludedAndNothingElseIncluded() {
        let result = BacklogTicketTargeting.targetCalendarIdentifier(
            defaultCalendarID: "default",
            excludedIDs: ["default"],
            includedCalendarIDsInDisplayOrder: [])
        XCTAssertNil(result)
    }

    func testNilWhenNoDefaultAndNothingIncluded() {
        let result = BacklogTicketTargeting.targetCalendarIdentifier(
            defaultCalendarID: nil,
            excludedIDs: [],
            includedCalendarIDsInDisplayOrder: [])
        XCTAssertNil(result)
    }
}
