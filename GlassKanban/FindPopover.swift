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
            // Same row shape as the two filters above, because it answers the
            // same kind of question — only its resting value differs (see
            // `RecurringFilter`). The glyph is the one already on the cards.
            filterRow(
                "Wiederkehrende",
                systemImage: "repeat",
                selection: $store.recurringFilter,
                options: RecurringFilter.allCases)

            // Only offered when there is something to undo — an always-visible
            // reset would be a permanently greyed-out control.
            if store.canResetFindSettings {
                Divider()
                Button("Alles zurücksetzen") {
                    store.resetFilters()
                }
                .buttonStyle(.link)
                .font(BoardText.body)
            }
        }
        .padding(14)
        // Sized to the widest row rather than to the narrowest: "Wiederkehrende"
        // beside its value needs more than the 260 the two short labels were
        // happy with, and at 260 the third row's menu ran off the edge. Set
        // once here so a future row does not have to rediscover this.
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
extension RecurringFilter: FilterDisplayable {}
