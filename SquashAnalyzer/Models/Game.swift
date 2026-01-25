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

    /// All points scored in this game (for analysis)
    var points: [Point] = []

    /// Currently selected player (for scoring flow)
    var selectedPlayer: Player? = nil

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

    /// Select a player (first step of scoring)
    func selectPlayer(_ player: Player) {
        guard !isGameOver else { return }
        selectedPlayer = player
    }

    /// Clear the selected player
    func clearSelection() {
        selectedPlayer = nil
    }

    /// Add a point with location (second step of scoring)
    func addPoint(to player: Player, at zone: CourtZone) {
        guard !isGameOver else { return }

        // Update score
        switch player {
        case .player1:
            player1Score += 1
        case .player2:
            player2Score += 1
        }

        // Record the point
        let point = Point(
            scorer: player,
            zone: zone,
            server: currentServer,
            player1Score: player1Score,
            player2Score: player2Score
        )
        points.append(point)

        // In squash, service changes when the receiver wins the rally
        if player != currentServer {
            currentServer = player
        }

        // Clear selection after scoring
        selectedPlayer = nil
    }

    /// Legacy method for adding point without location
    func addPoint(to player: Player) {
        addPoint(to: player, at: .middleLeft) // Default zone
    }

    func reset() {
        player1Score = 0
        player2Score = 0
        currentServer = startingServer
        points = []
        selectedPlayer = nil
    }

    func setStartingServer(_ player: Player) {
        startingServer = player
        currentServer = player
    }

    // MARK: - Analysis helpers

    /// Get all points won by a player
    func pointsWon(by player: Player) -> [Point] {
        points.filter { $0.scorer == player }
    }

    /// Get points won in a specific zone by a player
    func pointsWon(by player: Player, in zone: CourtZone) -> Int {
        points.filter { $0.scorer == player && $0.zone == zone }.count
    }

    /// Get all points lost by a player (won by opponent)
    func pointsLost(by player: Player) -> [Point] {
        points.filter { $0.scorer == player.opponent }
    }
}
