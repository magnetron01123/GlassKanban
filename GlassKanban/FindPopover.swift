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
        .frame(width: 260)
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
        .font(.system(size: 13))
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
