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

    /// One filter as a label plus a menu, so the row reads like a sentence
    /// ("Dringlichkeit: Hoch") instead of a segmented control that would grow
    /// with every option.
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
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        // Set on the row, not on the label: the label was 12pt while the
        // Picker kept the 13pt control default, so a row meant to read as one
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
