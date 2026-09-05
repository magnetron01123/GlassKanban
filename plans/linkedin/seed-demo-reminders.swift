// Seeds the demo Reminders lists for the LinkedIn video / carousel.
// Creates two LOCAL lists ("Glass Kanban", "Privat") and fills them with the
// tickets from plans/linkedin/konzept.md, then writes the column placement
// (Next / In Progress) straight into the app's columns.json — the app must be
// CLOSED while this runs, it rewrites the file on its own saves.
//
// Build & run (needs Reminders permission for the resulting binary — macOS
// asks once, on first run, for the terminal that launches it):
//   swiftc -O -o /tmp/seed-demo plans/linkedin/seed-demo-reminders.swift
//   /tmp/seed-demo            # creates lists + reminders, writes columns.json
//   /tmp/seed-demo --remove   # deletes both demo lists and their column entries
//
// Written 05.09.2026. Compiled, not yet executed against a real store.

import AppKit
import EventKit
import Foundation

let listNames = ["Glass Kanban", "Privat"]
let listColors: [String: CGColor] = [
    "Glass Kanban": CGColor(red: 0.20, green: 0.48, blue: 0.96, alpha: 1), // blue
    "Privat":       CGColor(red: 0.26, green: 0.72, blue: 0.42, alpha: 1), // green
]

struct Ticket {
    var title: String
    var list: String = "Glass Kanban"
    var lane: String? = nil       // "next" | "inProgress" | nil (= Backlog / Done)
    var priority: Int = 0          // EventKit: 1 = high (!!!), 5 = medium (!!), 9 = low (!)
    var dueInDays: Int? = nil      // relative to today, 9:00
    var completedDaysAgo: Int? = nil
    var weekly = false
    var notes: String? = nil
}

let today = Calendar.current.startOfDay(for: Date())
func date(daysFromToday d: Int, hour: Int = 9) -> Date {
    Calendar.current.date(byAdding: .day, value: d, to: today)!.addingTimeInterval(TimeInterval(hour * 3600))
}

// Order matters only for the app's own sorting (age), not here.
let tickets: [Ticket] = [
    // Show set, 05.09.2026 (v2): built for a tall 1:1 frame at the board's
    // minimum width of 1220 pt. Every title fits without an ellipsis (≤ 28
    // characters, compact cards), one list only so the board carries a single
    // accent colour, and fewer cards so the columns breathe. The recurring
    // card is the one that folds ("1 noch nicht fällig").
    // Backlog
    Ticket(title: "Datenschutzerklärung", priority: 5),
    Ticket(title: "App-Store-Screenshots"),
    Ticket(title: "TestFlight-Beta starten"),
    Ticket(title: "Produktseite bauen"),
    Ticket(title: "Listing-Texte schreiben"),
    Ticket(title: "Einführungspreis festlegen"),
    Ticket(title: "Wochenrückblick", dueInDays: 3, weekly: true),
    // In Bearbeitung — 2 / 2, the LinkedIn card is the one that moves
    Ticket(title: "Doku-Konsistenz prüfen", lane: "inProgress",
           notes: "SPEC, CONCEPT, BACKLOG gegen main lesen"),
    Ticket(title: "LinkedIn-Video aufnehmen", lane: "inProgress", priority: 5, dueInDays: 0,
           notes: "Ein Zug, vier Sekunden, kein Text auf dem Board"),
    // Als Nächstes — 3 / 5
    Ticket(title: "Demo-Liste anlegen", lane: "next",
           notes: "Zwei Listen, glaubwürdige Titel, keine Namen"),
    Ticket(title: "Deep-Link entfernen", lane: "next",
           notes: "x-apple-reminderkit ist undokumentiert"),
    Ticket(title: "Onboarding kürzen", lane: "next",
           notes: "Drei Sätze, kein Coaching, kein Tooltip"),
    // Erledigt — one per day, six consecutive days → streak 6 before the move
    Ticket(title: "iCloud-Sync-Grundlage", completedDaysAgo: 1),
    Ticket(title: "Bildschirm-Zuordnung", completedDaysAgo: 2),
    Ticket(title: "Spalte in eigene Datei", completedDaysAgo: 3),
    Ticket(title: "Deutsche Lokalisierung", completedDaysAgo: 4),
    Ticket(title: "Durchlaufzeit im Rückblick", completedDaysAgo: 5),
    Ticket(title: "WIP-Dialog gebaut", completedDaysAgo: 6),
]

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var granted = false
store.requestFullAccessToReminders { ok, error in
    granted = ok
    if let error { fputs("Access error: \(error)\n", stderr) }
    semaphore.signal()
}
semaphore.wait()
guard granted else { fputs("No Reminders access.\n", stderr); exit(1) }

let remove = CommandLine.arguments.contains("--remove")
let existing = store.calendars(for: .reminder).filter { listNames.contains($0.title) }

// --- columns.json (the app's own store; same schema as ColumnState.save) ---
let columnsURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Containers/com.davidtrogemann.GlassKanban/Data/Library/Application Support/GlassKanban/columns.json")

func loadColumns() -> [String: Any] {
    if let data = try? Data(contentsOf: columnsURL),
       let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
       root["v"] as? Int == 1 { return root }
    return ["v": 1, "pulls": [:], "importedLists": [:], "pendingTagCleanup": [], "released": [:]]
}
func saveColumns(_ root: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    try FileManager.default.createDirectory(at: columnsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: columnsURL, options: .atomic)
}
func demoReminderIDs(in calendars: [EKCalendar]) -> [String] {
    var ids: [String] = []
    let sem = DispatchSemaphore(value: 0)
    store.fetchReminders(matching: store.predicateForReminders(in: calendars)) { rs in
        ids = (rs ?? []).map(\.calendarItemIdentifier); sem.signal()
    }
    sem.wait()
    return ids
}
let appRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.davidtrogemann.GlassKanban" }
guard !appRunning else { fputs("Quit Glass Kanban first — it owns columns.json.\n", stderr); exit(1) }

if remove {
    var root = loadColumns()
    var pulls = root["pulls"] as? [String: Any] ?? [:]
    for id in demoReminderIDs(in: existing) { pulls.removeValue(forKey: id) }
    root["pulls"] = pulls
    try saveColumns(root)
    for cal in existing {
        try store.removeCalendar(cal, commit: false)
        print("removed list \(cal.title)")
    }
    try store.commit()
    print("columns.json cleaned")
    exit(0)
}

guard existing.isEmpty else {
    fputs("Demo lists already exist — run with --remove first.\n", stderr)
    exit(1)
}

guard let localSource = store.sources.first(where: { $0.sourceType == .local })
        ?? store.sources.first(where: { $0.sourceType == .calDAV }) else {
    fputs("No usable source.\n", stderr); exit(1)
}

var calendars: [String: EKCalendar] = [:]
for name in listNames {
    let cal = EKCalendar(for: .reminder, eventStore: store)
    cal.title = name
    cal.source = localSource
    cal.cgColor = listColors[name]
    try store.saveCalendar(cal, commit: false)
    calendars[name] = cal
}

var lanes: [(id: String, lane: String)] = [] // in ticket order
for t in tickets {
    let r = EKReminder(eventStore: store)
    r.title = t.title
    r.calendar = calendars[t.list]!
    r.priority = t.priority
    r.notes = t.notes
    if let d = t.dueInDays {
        let due = date(daysFromToday: d)
        r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        r.addAlarm(EKAlarm(absoluteDate: due))
    }
    if t.weekly {
        r.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil))
    }
    if let ago = t.completedDaysAgo {
        r.isCompleted = true
        r.completionDate = date(daysFromToday: -ago, hour: 17)
    }
    try store.save(r, commit: false)
    if let lane = t.lane { lanes.append((r.calendarItemIdentifier, lane)) }
}
try store.commit()
print("created \(tickets.count) reminders in \(listNames.joined(separator: ", ")) (source: \(localSource.title))")

// Column placement. `at` staggers by an hour per card so the app's age sort
// keeps the order of the `tickets` array (oldest pull on top).
var root = loadColumns()
var pulls = root["pulls"] as? [String: Any] ?? [:]
let base = Date().timeIntervalSince1970 - 3600 * 24
for (index, entry) in lanes.enumerated() {
    pulls[entry.id] = ["lane": entry.lane, "at": base + Double(index) * 3600]
}
root["pulls"] = pulls
try saveColumns(root)
print("columns.json: \(lanes.count) pulls written to \(columnsURL.path)")
