import Foundation

// MARK: - Onderlinge stand (3.2)

/// How two players did against each other in the finished matches on this
/// device, for "Kies speler": "3-1 tegen Bas". Matched on the names as saved
/// with the match (the history has no player ids), without case.
public struct HeadToHead: Equatable, Sendable {
    /// Matches won by the first player
    public let wins: Int
    /// Matches won by the other one
    public let losses: Int

    public init(wins: Int, losses: Int) {
        self.wins = wins
        self.losses = losses
    }

    public var played: Int { wins + losses }

    /// The record of `player` against `opponent`; matches without a winner do not count
    public static func record(of player: String, against opponent: String, in history: [MatchHistorySummary]) -> HeadToHead {
        let name = player.trimmingCharacters(in: .whitespaces).lowercased()
        let other = opponent.trimmingCharacters(in: .whitespaces).lowercased()
        var wins = 0
        var losses = 0
        if name.isEmpty || other.isEmpty || name == other { return HeadToHead(wins: 0, losses: 0) }
        for match in history {
            guard let winner = match.winner else { continue }
            let first = match.player1Name.trimmingCharacters(in: .whitespaces).lowercased()
            let second = match.player2Name.trimmingCharacters(in: .whitespaces).lowercased()
            var side: Player? = nil
            if first == name && second == other { side = Player.player1 }
            if second == name && first == other { side = Player.player2 }
            guard let side else { continue }
            if winner == side { wins += 1 } else { losses += 1 }
        }
        return HeadToHead(wins: wins, losses: losses)
    }

    /// "3-1 tegen Bas"
    public func text(against opponent: String) -> String {
        L10n.text("%@-%@ tegen %@", String(wins), String(losses), opponent)
    }
}
