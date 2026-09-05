import XCTest

/// What the URL field keeps and what it turns down. The field and the write
/// share this rule so they cannot disagree — before they did, and the
/// disagreement was silent: text the store refused simply was not there any
/// more the next time the card opened.
final class TicketURLTests: XCTestCase {

    func testAPlainDomainIsStoredUnchanged() {
        XCTAssertEqual(TicketURL.parsed("example.com")?.absoluteString, "example.com")
    }

    func testAFullAddressIsStoredUnchanged() {
        XCTAssertEqual(
            TicketURL.parsed("https://example.com/beleg?nr=7")?.absoluteString,
            "https://example.com/beleg?nr=7")
    }

    func testSurroundingWhitespaceIsTrimmedRatherThanRejected() {
        XCTAssertEqual(TicketURL.parsed("  example.com \n")?.absoluteString, "example.com")
    }

    /// The measured reason the space check exists: since macOS 14
    /// `URL(string:)` percent-encodes what it cannot parse, so prose came back
    /// as "Notiz%20mit%20Leerzeichen" — the user's words, mangled, in a field
    /// they could no longer recognise.
    func testProseIsNotAnAddress() {
        XCTAssertNil(TicketURL.parsed("Notiz mit Leerzeichen"))
        XCTAssertTrue(TicketURL.rejects("Notiz mit Leerzeichen"))
    }

    func testASingleSpaceInsideAnAddressRejectsIt() {
        XCTAssertNil(TicketURL.parsed("https://example.com/mein beleg"))
    }

    /// An umlaut domain is a real, resolvable address — normalised on the way
    /// in, not thrown away. Rejecting it would cost real links to avoid an
    /// unusual spelling.
    func testAnUmlautDomainIsKept() {
        XCTAssertNotNil(TicketURL.parsed("https://münchen.de"))
        XCTAssertFalse(TicketURL.rejects("https://münchen.de"))
    }

    /// Clearing the address is an ordinary edit. A field that complained
    /// about being empty would be complaining about the user's own decision.
    func testAnEmptyFieldIsNotAComplaint() {
        XCTAssertNil(TicketURL.parsed(""))
        XCTAssertFalse(TicketURL.rejects(""))
        XCTAssertFalse(TicketURL.rejects("   "))
    }

    /// Whitespace-only differs from prose: nothing was typed, so nothing is
    /// lost and nothing needs saying.
    func testWhitespaceOnlyStoresNothingAndSaysNothing() {
        XCTAssertNil(TicketURL.parsed("\n\t "))
        XCTAssertFalse(TicketURL.rejects("\n\t "))
    }

    /// The two answers must never contradict each other — that contradiction
    /// is the bug this rule exists to make impossible.
    func testRejectionAndParsingAgreeOnEveryInput() {
        let inputs = [
            "example.com", "https://example.com", "Notiz mit Leerzeichen", "",
            "   ", "münchen.de", "mailto:a@b.de", "x-apple-reminderkit://x",
        ]
        for input in inputs {
            let stored = TicketURL.parsed(input) != nil
            let typed = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            XCTAssertEqual(
                TicketURL.rejects(input), typed && !stored,
                "field and write disagree about \"\(input)\"")
        }
    }
}
