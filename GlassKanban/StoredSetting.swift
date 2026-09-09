import Foundation

/// Every value this app keeps in `UserDefaults`, and whether it belongs to the
/// user or to the machine it was set on.
///
/// **Why this type exists.** Syncing settings between the user's Macs (see
/// BACKLOG.md, "Gerätesynchronisation über iCloud") needs an answer per key,
/// and an answer kept only in a table in a document is one that a new key
/// silently skips. Here the answer is a `switch` the compiler will not let
/// anybody leave incomplete: adding a case without deciding its scope does not
/// build. That is the same move `check-localization.py` made for the string
/// catalogue — turn an assurance into something that is actually checked.
///
/// **Two of these are not settings.** `columnStorageLocation` and
/// `columnStorageLastFailure` are diagnostics, written by the app and read by
/// a person with `plutil -p`. They live here because this type's promise is
/// "every value this app keeps in `UserDefaults`" — an exception would be the
/// first hole in it — and because they must be classified as travelling or
/// not, exactly like the rest. Why `UserDefaults` and not a log: this app's
/// `os.Logger` output is findable through neither `log show` nor `log stream`
/// (measured 14.08.2026, CLAUDE.md), which is how a board that failed to save
/// every single pull looked healthy for three weeks (08.09.2026, CONCEPT.md).
///
/// Nothing transports anything yet. Until the KV store is wired up (blocked on
/// the Developer Program, measured 14.08.2026), this type only names and
/// classifies what already exists.
enum StoredSetting: String, CaseIterable {

    /// Lists the user switched off in Settings.
    case excludedCalendars = "excludedCalendarIDs"
    /// WIP limit per working lane.
    case wipLimits
    /// Whether completing a task makes the quiet tick.
    case completionSound = "completionSoundEnabled"
    /// Whether Backlog's fold rests at the ripeness line.
    case foldNotYetDue
    /// Light, dark, or follow the system.
    case appearance = "appAppearance"
    /// Which values this board overwrote, so it can recognise its own echo.
    case correctionLedger
    /// Which recurring series have spent their pull.
    case tagReleaseMemory
    /// Where this build writes `columns.json`, and which of the two possible
    /// homes that is. Not a setting — a breadcrumb, and the only one this app
    /// has (see `scope` for why it is kept here rather than logged).
    case columnStorageLocation
    /// The last write of `columns.json` that failed, with its reason. Removed
    /// again by the next write that succeeds.
    case columnStorageLastFailure

    /// The `UserDefaults` key. **A persisted contract**, exactly like
    /// `ColumnState.Lane`'s raw values: renaming one does not migrate a
    /// setting, it silently resets it to the default. Pinned by test.
    var key: String { rawValue }

    enum Scope {
        /// Follows the user to their other Macs.
        case everyDevice
        /// Stays where it was set.
        case thisDevice
    }

    /// Whether this value should travel.
    ///
    /// The reasoning per case is short on purpose; the full argument lives in
    /// BACKLOG.md under "Was wohin gehört".
    var scope: Scope {
        switch self {
        // Policy the user holds, not a property of a machine. A WIP limit that
        // counts per device is not a WIP limit: two Macs at three each allow
        // six started tasks and the friction dialog never fires.
        case .wipLimits: .everyDevice
        // How the backlog reads is a working preference, the same on any desk.
        case .foldNotYetDue: .everyDevice

        // Brightness is a property of the room and the screen, not of the user.
        case .appearance: .thisDevice
        // Headphones on the laptop, silence in the office.
        case .completionSound: .thisDevice
        // Open until measured (M4): `EKCalendar.calendarIdentifier` may differ
        // per machine, and which lists belong on *this* desk is plausibly a
        // device question anyway. Staying put is the reversible answer.
        case .excludedCalendars: .thisDevice

        // Never travels. It records which values *this* board overwrote, so it
        // can recognise its own displaced value coming back. Shared between two
        // Macs, each would answer the other's legitimate edit as if it were a
        // stale foreign write — two boards in a write loop over the user's real
        // data. SPEC.md lists "a second Mac with this app" as a foreign writer
        // precisely so that this stays true.
        case .correctionLedger: .thisDevice
        // Same reason: a record of what this machine did, not of what is.
        case .tagReleaseMemory: .thisDevice

        // Facts about this Mac's sandbox, useless and misleading anywhere
        // else: the other Mac may well have a different answer, and a
        // travelling failure note would accuse the wrong machine.
        case .columnStorageLocation, .columnStorageLastFailure: .thisDevice
        }
    }

    /// The settings that would travel, for the transport to iterate over.
    static var syncable: [StoredSetting] {
        allCases.filter { $0.scope == .everyDevice }
    }
}
