import Foundation

/// Represents a player in the game
enum Player: String, CaseIterable, Identifiable {
    case player1 = "Speler 1"
    case player2 = "Speler 2"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .player1: return "S1"
        case .player2: return "S2"
        }
    }

    var opponent: Player {
        switch self {
        case .player1: return .player2
        case .player2: return .player1
        }
    }
}

/// Represents the current game state
@Observable
class Game {
    // MARK: - Properties
    var player1Name: String = "Speler 1"
    var player2Name: String = "Speler 2"

    var player1Score: Int = 0
    var player2Score: Int = 0

    var currentServer: Player = .player1
    var startingServer: Player = .player1

    var isGameOver: Bool {
        let maxScore = max(player1Score, player2Score)
        let minScore = min(player1Score, player2Score)
        return maxScore >= 11 && (maxScore - minScore) >= 2
    }

    var winner: Player? {
        guard isGameOver else { return nil }
        return player1Score > player2Score ? .player1 : .player2
    }

    // MARK: - Methods
    func score(for player: Player) -> Int {
        switch player {
        case .player1: return player1Score
        case .player2: return player2Score
        }
    }

    func name(for player: Player) -> String {
        switch player {
        case .player1: return player1Name
        case .player2: return player2Name
        }
    }

    func addPoint(to player: Player) {
        guard !isGameOver else { return }

        switch player {
        case .player1:
            player1Score += 1
        case .player2:
            player2Score += 1
        }

        // In squash, service changes when the receiver wins the rally
        if player != currentServer {
            currentServer = player
        }
    }

    func reset() {
        player1Score = 0
        player2Score = 0
        currentServer = startingServer
    }

    func setStartingServer(_ player: Player) {
        startingServer = player
        currentServer = player
    }
}
