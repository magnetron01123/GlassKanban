import Foundation

/// Where the arrow keys move the focus on the board.
///
/// Takes the board as plain columns of card IDs, so the rules can be read and
/// tested without a view, EventKit or a running app in the picture.
enum BoardNavigation {

    enum Direction {
        case up, down, left, right
    }

    /// The card focus should move to, or nil to leave it where it is.
    ///
    /// - Up and down walk within a lane and stop at its ends instead of
    ///   wrapping: the columns are places, and springing from the last card
    ///   back to the first loses the sense of where you are.
    /// - Left and right cross to the nearest lane that actually holds cards,
    ///   keeping the row where it exists. An empty lane is stepped over rather
    ///   than swallowing the keypress.
    /// - With nothing focused yet, any arrow key lands on the first card, so
    ///   the keyboard has a way onto the board.
    static func target(
        from cardID: String?,
        direction: Direction,
        lanes: [[String]]
    ) -> String? {
        guard let position = position(of: cardID, in: lanes) else {
            return firstCard(in: lanes)
        }
        switch direction {
        case .up:
            let row = position.row - 1
            return row >= 0 ? lanes[position.lane][row] : nil
        case .down:
            let row = position.row + 1
            return row < lanes[position.lane].count ? lanes[position.lane][row] : nil
        case .left:
            return neighbour(of: position, step: -1, in: lanes)
        case .right:
            return neighbour(of: position, step: 1, in: lanes)
        }
    }

    private static func position(of cardID: String?, in lanes: [[String]]) -> (lane: Int, row: Int)? {
        guard let cardID else { return nil }
        for (lane, cards) in lanes.enumerated() {
            if let row = cards.firstIndex(of: cardID) {
                return (lane, row)
            }
        }
        return nil
    }

    private static func firstCard(in lanes: [[String]]) -> String? {
        lanes.first(where: { !$0.isEmpty })?.first
    }

    /// The card in the next lane that holds any, at the same row if it reaches
    /// that far — otherwise its last card, so a short lane still catches the
    /// focus instead of dropping it.
    private static func neighbour(
        of position: (lane: Int, row: Int),
        step: Int,
        in lanes: [[String]]
    ) -> String? {
        var lane = position.lane + step
        while lanes.indices.contains(lane) {
            let cards = lanes[lane]
            if !cards.isEmpty {
                return cards[min(position.row, cards.count - 1)]
            }
            lane += step
        }
        return nil
    }
}
