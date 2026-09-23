import Foundation

/// Why EventKit refused a write, in the one case where the reason changes what
/// the board should say.
///
/// **The case, measured 09.09.2026.** Moving a card to another list fails on
/// some lists with `com.apple.reminderkit` −3002, whose own debug text reads
/// "Moving between lists is unsupported in this account". It is not this app's
/// doing: the same move, from a plain command-line tool with its own
/// `EKEventStore`, is refused exactly the same way. Two of six lists on the
/// measured account sit behind it and refuse in both directions, against every
/// other list; the remaining four move between each other without complaint.
///
/// **Which lists these are cannot be asked in advance.** `EKCalendar` declares
/// 36 Objective-C properties and not one of them differs between a refusing
/// list and a moving one — `allowsContentModifications`, `immutable`,
/// `subscribed` and `type` all read identically. Its private bridge
/// (`backingObject`, an `EKFrozenReminderCalendar`) carries fifteen more, none
/// about sharing or ownership. That state lives in ReminderKit, which only
/// private API reaches — and private API is a rejected App Store submission
/// (RELEASE.md). So the board finds out the way everyone else does: by trying.
/// `remctl`, a Reminders tool that does use private API, does the same.
///
/// The consequence for the user is small and worth stating plainly rather than
/// working around: the card stays in its list, and the message says why. What
/// is deliberately **not** built is the copy-and-delete substitute other tools
/// fall back on — it is not a move but a rebuild, and it costs the capture
/// date, which `RecurringSeriesMatch` needs to the microsecond and the
/// statistics window needs for its lead time (CONCEPT.md).
enum ReminderWriteFailure {

    /// ReminderKit's domain, as it appears in the error EventKit hands back.
    static let reminderKitDomain = "com.apple.reminderkit"

    /// "Moving between lists is unsupported in this account."
    static let listMoveRefusedCode = -3002

    /// Whether this error is the system refusing to move a task between lists.
    ///
    /// Matched on domain *and* code, never on the message: the message is
    /// localised and Apple's to change, and −3002 in some other domain is a
    /// different fault that must keep reporting itself as one.
    static func isListMoveRefused(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == reminderKitDomain && error.code == listMoveRefusedCode
    }
}
