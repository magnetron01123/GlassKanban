import Foundation

/// Which surface a move was made on.
///
/// The board and the menu bar tray watch the same store, so a question the
/// store raises (see `RemindersStore.PendingOverflow`) has to know where it
/// belongs — otherwise the board asks about a card the user moved in the
/// tray, and both surfaces put the same question up at once.
enum MoveSource {
    case board
    case tray
}
