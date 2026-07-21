import EventKit
import os.log

/// Resolves the URL that opens one specific reminder in the Reminders app.
///
/// Background: the (undocumented) scheme is
/// `x-apple-reminderkit://REMCDReminder/<UUID>`, but the UUID it expects is
/// the Reminders-internal record UUID — NOT EventKit's
/// `calendarItemIdentifier`. The only public source for that UUID is
/// `calendarItemExternalIdentifier`, which for CloudKit-backed (iCloud/
/// CalDAV/Exchange) reminders is typically "x-apple-reminder://<UUID>".
///
/// Local ("On My Mac") reminders have no external identifier at all — there
/// is no public API that exposes their internal UUID — so this resolves to
/// `nil` for them and the caller falls back to simply opening the Reminders
/// app. That is an acceptable gap here: editing a reminder's content no
/// longer depends on this deep link (see `TicketEditSheet`), so this is now
/// only a shortcut into the native app, not the sole way to reach a
/// reminder's content. An earlier version of this resolver used a private,
/// reflection-based fallback (`backingObject` → `_reminder` → `uuid`, the
/// same trick the open-source app "Reminders MenuBar" uses) to cover this
/// gap — removed once the in-app editor made it unnecessary, since Mac App
/// Store Guideline 2.5.1 prohibits private/undocumented API use.
enum ReminderDeepLink {

    private static let log = Logger(subsystem: "com.davidtrogemann.GlassKanban", category: "deeplink")

    static func url(for reminder: EKReminder) -> URL? {
        guard let uuid = internalUUIDString(of: reminder) else {
            log.notice("no internal UUID resolved for \(reminder.calendarItemIdentifier, privacy: .public)")
            return nil
        }
        // "/details" opens the reminder's edit popover instead of merely
        // navigating to its list.
        return URL(string: "x-apple-reminderkit://REMCDReminder/\(uuid)/details")
    }

    private static func internalUUIDString(of reminder: EKReminder) -> String? {
        if let external = reminder.calendarItemExternalIdentifier {
            if let range = external.range(of: "x-apple-reminder://") {
                log.notice("resolved via external identifier (prefixed)")
                return String(external[range.upperBound...])
            }
            if UUID(uuidString: external) != nil {
                log.notice("resolved via external identifier (bare UUID)")
                return external
            }
            log.notice("external identifier has unexpected format: \(external, privacy: .public)")
        }
        return nil
    }
}
