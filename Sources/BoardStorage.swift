import Foundation

/// Where the board's own files live — `columns.json`, `sizes.json` — and how
/// that place is chosen.
///
/// Pulled out of `ColumnState` when the second file arrived, so both files
/// always land in the same directory by the same rule. A copy of this logic
/// would drift, and the one thing it must never do is drift: the choice below
/// is what silently lost every column on quit for three weeks (see
/// `chooseDirectory`).
enum BoardStorage {

    /// The container the board's own files live in.
    ///
    /// In one place on purpose. Whether the Mac App Store accepts this form or
    /// insists on a `<TeamID>.group.…` prefix is not yet settled (no team to
    /// ask with — see BACKLOG.md), and a change here must stay a one-line
    /// change plus one more entry in each file's known locations, never a data
    /// migration. The iOS form is chosen so the planned iOS app can use the
    /// same one.
    static let appGroupIdentifier = "group.com.davidtrogemann.GlassKanban"

    /// The folder both homes put the files in.
    static let directoryName = "GlassKanban"

    /// One of the two places the files can live, and which one this build
    /// actually got.
    ///
    /// Named rather than reduced to a bare `URL` because the answer is the
    /// diagnostic: "which home did this build end up with" is the question
    /// that went unanswered for three weeks (see the note on
    /// `chooseDirectory`), and a `URL` alone does not say whether it is the
    /// intended one or the fallback.
    enum Location: Equatable {
        /// The shared container, reachable by a widget or an App Intent.
        case groupContainer(URL)
        /// The app's own sandbox — reachable by nothing else, but writable.
        case applicationSupport(URL)

        /// The directory the files go in.
        var directory: URL {
            switch self {
            case .groupContainer(let url), .applicationSupport(let url): url
            }
        }

        /// One of the board's files in this directory.
        func fileURL(named fileName: String) -> URL {
            directory.appendingPathComponent(fileName)
        }
    }

    /// Picks the directory the files are written to: the group container when
    /// it can be written, otherwise the app's own Application Support.
    ///
    /// **Writability, not the existence of a path, is the question — and this
    /// is why.** Until 08.09.2026 the choice was a `??` between
    /// `containerURL(forSecurityApplicationGroupIdentifier:)` and Application
    /// Support, on the assumption that a build without the
    /// `com.apple.security.application-groups` entitlement (this one — see
    /// `project.yml`) would get `nil` and fall back. It does not: the method
    /// answers with `~/Library/Group Containers/<id>/` whether or not the
    /// entitlement is in the signature, and the sandbox then refuses every
    /// write to it. The fallback therefore never fired, every save failed,
    /// and because the only trace was an `os.Logger` line this app's output
    /// cannot be found in (CLAUDE.md), the board silently lost every column on
    /// quit for three weeks. Measured and re-measured 08.09.2026; the whole
    /// story is in CONCEPT.md.
    ///
    /// Only the group container is probed. Application Support is inside this
    /// process's own sandbox — if that is unwritable the app has no storage at
    /// all, and there is nothing further to fall back to.
    static func chooseDirectory(
        groupContainer: URL?,
        applicationSupport: URL?,
        isWritable: (URL) -> Bool
    ) -> Location? {
        if let groupContainer {
            let directory = groupContainer.appendingPathComponent(
                directoryName, isDirectory: true)
            if isWritable(directory) { return .groupContainer(directory) }
        }
        if let applicationSupport {
            return .applicationSupport(
                applicationSupport.appendingPathComponent(
                    directoryName, isDirectory: true))
        }
        return nil
    }

    /// Answers whether this process may write into `directory` — by writing.
    ///
    /// Nothing cheaper is honest. `isWritableFile(atPath:)` reports POSIX
    /// permissions, which say yes for a group container the sandbox will
    /// still refuse; the refusal happens at write time, in a place no
    /// permission bit records. The probe therefore does exactly what a save
    /// does — create the directory, write a file atomically — and removes its
    /// file again.
    static func directoryAcceptsWrites(
        _ directory: URL, fileManager: FileManager = .default
    ) -> Bool {
        do {
            try fileManager.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let probe = directory.appendingPathComponent(".write-probe")
            try Data().write(to: probe, options: .atomic)
            try? fileManager.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    /// Where this build writes, probed against the real file system.
    ///
    /// The group container is preferred, because a widget, a Live Activity and
    /// an App Intent each run in their own process and cannot see inside the
    /// app's own sandbox. None of them exist yet; moving the files while it is
    /// cheap is the point, since doing it later means migrating live user data.
    ///
    /// A container keyed to this app's identifier is not a second writer in
    /// the sense the board guards against (that is any EventKit client
    /// rewriting a reminder's notes): no other program can reach it. What
    /// syncing it does admit is a second *instance of this app* — the user's
    /// own other Mac — which is what each file's `merged(_:_:now:)` is for.
    static func defaultLocation(
        fileManager: FileManager = .default
    ) -> Location? {
        chooseDirectory(
            groupContainer: fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier),
            applicationSupport: try? fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true),
            isWritable: { directoryAcceptsWrites($0, fileManager: fileManager) })
    }

    /// The named file this build writes to, or nil if it has nowhere to write.
    static func defaultFileURL(
        named fileName: String, fileManager: FileManager = .default
    ) -> URL? {
        guard let location = defaultLocation(fileManager: fileManager)
        else { return nil }
        try? fileManager.createDirectory(
            at: location.directory, withIntermediateDirectories: true)
        return location.fileURL(named: fileName)
    }
}
