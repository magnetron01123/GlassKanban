import SwiftUI

/// Everything for narrowing the board down, in one place: free text plus the
/// two filters. They are one job for the user — "find a ticket" — and used to
/// sit in the window chrome as separate controls. Gathering them here keeps
/// the board's permanent chrome at two glyphs.
struct FindPopover: View {
    @EnvironmentObject private var store: RemindersStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField

            Divider()

            filterRow(
                "Dringlichkeit",
                systemImage: "flag",
                selection: $store.priorityFilter,
                options: PriorityFilter.allCases)
            filterRow(
                "Fälligkeit",
                systemImage: "calendar",
                selection: $store.dueFilter,
                options: DueFilter.allCases)
            // Last of the three, because it is the one that answers "whose
            // work is this" rather than "how urgent is it" — and the only one
            // that can be off for a reason the settings already cover.
            //
            // Offered when there is a choice to make: with a single list on
            // the board the row could say nothing that "Alle" doesn't. But
            // also whenever something *is* switched off, however few lists
            // are left — otherwise switching the other list off in the
            // settings would take the row away while its filter kept hiding
            // the one list that remains, and the board would sit empty with
            // its cause nowhere on screen.
            if store.boardCalendars.count > 1 || !store.listFilter.isUnrestricted {
                listRow
            }
            // A third row, "Wiederkehrende", used to sit here: the way out of
            // a rule that hid not-yet-due recurring cards. That rule is gone —
            // Backlog now sorts them to its foot and folds there instead — and
            // with nothing hidden the row had no difference left to express.
            // Its one remaining reading, "show me only what is ripe", is what
            // Fälligkeit already does, for every card rather than just the
            // recurring ones.

            // Only offered when there is something to undo — an always-visible
            // reset would be a permanently greyed-out control.
            if store.isFiltering {
                Divider()
                Button("Alles zurücksetzen") {
                    store.resetFilters()
                }
                .buttonStyle(.link)
                .font(BoardText.body)
            }
        }
        .padding(14)
        // Sized to the widest row rather than to the narrowest. This was 300
        // for a third row whose label ("Wiederkehrende") plus value ran off a
        // 260-wide popover; that row is gone, and the two that remain are
        // short. Kept at 300 all the same: the search field is the control
        // this popover exists for, and 260 makes a typed ticket title wrap
        // sooner than it needs to.
        .frame(width: 300)
        // Typing is why the popover opened; asking for a click first would be
        // a wasted step.
        .onAppear { searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Aufgabe finden", text: $store.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Suche löschen")
            }
        }
        // Matches the filter rows directly below it — same popover, same
        // scale. It sat one point larger before, an inline size that had
        // drifted from the token rather than a deliberate distinction.
        .font(BoardText.body)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        // Same recessed wash as a chip, but deliberately not `Board.chipShape`:
        // this is an input control, and a capsule would make it read as a value.
        .background(.quaternary.opacity(Board.chipFill), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    /// The lists, as the same label-plus-menu sentence as the two rows above
    /// — but a menu of checkmarks rather than one choice, because a board
    /// narrowed to "everything except the shared list" is an ordinary thing to
    /// want and a single-choice menu cannot say it.
    ///
    /// Every list starts ticked and is taken away one at a time, rather than
    /// built up from nothing: the board's normal state is "all of them", and a
    /// filter should open showing what is true rather than asking to be filled
    /// in. Offered here are exactly the lists the settings let onto the board
    /// — that pane decides what belongs, permanently; this row decides what to
    /// look at now.
    ///
    /// A menu, not a column of checkboxes in the popover: the popover holds a
    /// fixed set of rows today, and a column would grow it with every list in
    /// Reminders — the one thing this app has no say over.
    private var listRow: some View {
        HStack(spacing: 8) {
            Label("Listen", systemImage: "list.bullet")
                .foregroundStyle(.secondary)
                .fixedSize()
            Spacer()
            Menu(listSummary) {
                ForEach(store.boardCalendars, id: \.calendarIdentifier) { calendar in
                    Toggle(calendar.title, isOn: Binding(
                        get: { store.listFilter.shows(calendar.calendarIdentifier) },
                        set: { _ in store.listFilter.toggle(calendar.calendarIdentifier) }))
                }
                // The way back, and only when there is something to come back
                // from — with every list ticked it would be a command that
                // does nothing. Below the lists, where an action belongs;
                // above them it would read as a fourth list.
                if !store.listFilter.isUnrestricted {
                    Divider()
                    Button("Alle anzeigen") { store.listFilter.showAll() }
                }
            }
            .fixedSize()
            .accessibilityLabel("Listen")
            .accessibilityValue(listSummary)
        }
        .font(BoardText.body)
    }

    /// What the closed menu says: "Alle" while nothing is switched off, the
    /// list's own name while exactly one is left, a count otherwise — a menu
    /// button cannot show three titles, and truncating them into "Arbeit,
    /// Gemeins…" says less than "2 Listen".
    private var listSummary: String {
        guard !store.listFilter.isUnrestricted else { return "Alle" }
        let shown = store.boardCalendars.filter { store.listFilter.shows($0.calendarIdentifier) }
        switch shown.count {
        case 0: return "Keine"
        case 1: return shown[0].title
        default: return GermanPlural.lists(shown.count)
        }
    }

    /// One filter as a label plus a menu, so the row reads like a sentence
    /// ("Dringlichkeit: Hoch") instead of a segmented control that would grow
    /// with every option.
    ///
    /// A `Menu` holding an inline `Picker`, rather than the `Picker` itself.
    /// It shows the same value, opens the same list with the same checkmark,
    /// and is the same control the list row below has to be — a `Picker`
    /// there cannot hold more than one choice. Left as two kinds of control,
    /// the rows wore two different chevrons (⌃⌄ against ⌄) at two widths,
    /// which is the near-miss that makes a set of rows look accidental.
    private func filterRow<F>(
        _ title: String,
        systemImage: String,
        selection: Binding<F>,
        options: [F]
    ) -> some View where F: Hashable & Identifiable & FilterDisplayable {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
                // A label is one word and must stay one line. Without this,
                // a value wide enough to crowd the row makes SwiftUI wrap the
                // label instead of the value — "Wiederkehrende" came out as a
                // column one letter wide rather than simply being cramped.
                .fixedSize()
            Spacer()
            Menu(selection.wrappedValue.displayName) {
                Picker(title, selection: selection) {
                    ForEach(options) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .fixedSize()
            .accessibilityLabel(title)
            .accessibilityValue(selection.wrappedValue.displayName)
        }
        // Set on the row, not on the label: the label was 12pt while the
        // menu keeps the 13pt control default, so a row meant to read as one
        // sentence ("Dringlichkeit: Hoch") was set in two sizes.
        .font(BoardText.body)
    }
}

/// Small protocol so both filter enums share one row builder.
protocol FilterDisplayable {
    var displayName: String { get }
}

extension PriorityFilter: FilterDisplayable {}
extension DueFilter: FilterDisplayable {}
