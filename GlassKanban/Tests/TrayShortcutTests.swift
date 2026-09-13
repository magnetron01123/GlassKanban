import XCTest

/// The global shortcut, as a value: what counts as usable, how it is written
/// down, and what happens to something unreadable.
final class TrayShortcutTests: XCTestCase {

    private func shortcut(
        _ code: UInt16 = 40,
        _ modifiers: TrayShortcut.Modifiers = [.command, .option],
        _ label: String = "K"
    ) -> TrayShortcut {
        TrayShortcut(keyCode: code, modifiers: modifiers, label: label)
    }

    // MARK: - What may be registered

    /// One of ⌃⌥⌘ has to be there. ⇧K is a capital K, and registering it
    /// would take that letter away from every text field on the Mac.
    func testAShortcutNeedsACarryingModifier() {
        XCTAssertTrue(shortcut(40, [.command]).isValid)
        XCTAssertTrue(shortcut(40, [.option]).isValid)
        XCTAssertTrue(shortcut(40, [.control]).isValid)
        XCTAssertTrue(shortcut(40, [.command, .shift]).isValid)
        XCTAssertFalse(shortcut(40, []).isValid)
        XCTAssertFalse(shortcut(40, [.shift]).isValid)
    }

    /// A combination with nothing to show for it cannot be taken back by the
    /// user, because the field would look empty either way.
    func testAShortcutWithoutALabelIsNotValid() {
        XCTAssertFalse(shortcut(40, [.command], "").isValid)
    }

    // MARK: - How it reads

    /// The order every macOS menu prints, so the pane reads like the system.
    func testTheModifierSignsFollowTheSystemsOrder() {
        let all = shortcut(40, [.command, .shift, .option, .control])
        XCTAssertEqual(all.modifierGlyphs, "⌃⌥⇧⌘")
        XCTAssertEqual(all.displayString, "⌃⌥⇧⌘K")
        XCTAssertEqual(shortcut(40, [.command, .option]).displayString, "⌥⌘K")
    }

    /// The label travels with the shortcut rather than being derived from the
    /// key code: the same physical key types "Z" on a German layout and "Y"
    /// on an American one.
    func testTheLabelIsTheOneThatWasRecorded() {
        XCTAssertEqual(shortcut(16, [.command], "Z").displayString, "⌘Z")
        XCTAssertEqual(shortcut(16, [.command], "Y").displayString, "⌘Y")
    }

    // MARK: - Written down and read back

    func testAShortcutSurvivesTheRoundTrip() {
        for modifiers in [
            TrayShortcut.Modifiers([.command]),
            [.command, .option],
            [.control, .shift, .command],
            [.control, .option, .shift, .command],
        ] as [TrayShortcut.Modifiers] {
            let original = shortcut(40, modifiers)
            XCTAssertEqual(TrayShortcut.parse(original.stored), original)
        }
    }

    /// A label that is itself the separator must not cut the stored value in
    /// half — the German layout has that key, and it is a plausible shortcut.
    func testAPipeAsTheKeyLabelSurvives() {
        let original = shortcut(42, [.control, .command], "|")
        XCTAssertEqual(TrayShortcut.parse(original.stored), original)
    }

    /// Anything this version cannot read leaves the user with no shortcut —
    /// never with a different one they did not choose.
    func testUnreadableTextIsNoShortcut() {
        XCTAssertNil(TrayShortcut.parse(""))
        XCTAssertNil(TrayShortcut.parse("cmd+opt|K"))
        XCTAssertNil(TrayShortcut.parse("cmd+opt|notanumber|K"))
        XCTAssertNil(TrayShortcut.parse("cmd+hyper|40|K"))
        XCTAssertNil(TrayShortcut.parse("cmd+opt|40|"))
    }

    /// Stored text that describes an unusable combination is refused on the
    /// way back in, not just on the way out — an older build, a hand-edited
    /// plist or a synced value must not be able to register a bare letter.
    func testAnInvalidCombinationDoesNotComeBackFromStorage() {
        XCTAssertNil(TrayShortcut.parse("|40|K"))
        XCTAssertNil(TrayShortcut.parse("shift|40|K"))
    }
}
