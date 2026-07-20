import Foundation

/// Pure selection rule behind the Backlog "+" button: which Reminders list a
/// newly created ticket should land in. No EventKit dependency, so it is
/// testable without a live `EKEventStore` (see `RemindersStore.createBacklogTicket()`).
enum BacklogTicketTargeting {

    /// Prefers Reminders' own default list, unless it is hidden from the
    /// board — then the first list the board actually shows, so the new
    /// ticket is never created somewhere the user can't see it.
    static func targetCalendarIdentifier(
        defaultCalendarID: String?,
        excludedIDs: Set<String>,
        includedCalendarIDsInDisplayOrder: [String]
    ) -> String? {
        if let defaultCalendarID, !excludedIDs.contains(defaultCalendarID) {
            return defaultCalendarID
        }
        return includedCalendarIDsInDisplayOrder.first
    }
}
