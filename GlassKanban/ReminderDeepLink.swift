import EventKit
import os.log

/// Resolves the URL that opens one specific reminder in the Reminders app.
///
/// Background: the (undocumented) scheme is
/// `x-apple-reminderkit://REMCDReminder/<UUID>`, but the UUID it expects is
/// the Reminders-internal record UUID — NOT EventKit's
/// `calendarItemIdentifier`. Two resolution paths, in order:
///
/// 1. `calendarItemExternalIdentifier`: for CloudKit-backed (iCloud)
///    reminders this is typically "x-apple-reminder://<UUID>".
/// 2. The private backing-object chain (backingObject → _reminder → …uuid),
///    the same workaround the open-source app "Reminders MenuBar" uses in
///    production on macOS 26. Private API — acceptable for this personal,
///    non-App-Store app; if Apple changes it, the caller falls back to
///    simply opening the Reminders app.
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
        if let uuid = backingUUID(of: reminder) {
            log.notice("resolved via private backing object")
            return uuid.uuidString
        }
        return nil
    }

    private static func backingUUID(of reminder: EKReminder) -> UUID? {
        guard let backing = perform("backingObject", on: reminder),
              let rem = perform("_reminder", on: backing) else { return nil }
        for idSelector in ["reminderID", "objectID"] {
            if let idObject = perform(idSelector, on: rem),
               let uuid = perform("uuid", on: idObject) as? UUID {
                return uuid
            }
        }
        return perform("uuid", on: rem) as? UUID
    }

    private static func perform(_ name: String, on object: AnyObject) -> AnyObject? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }
}
