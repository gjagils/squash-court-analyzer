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

    /// Track previous server for undo
    private var previousServers: [Player] = []

    var isGameOver: Bool {
        let maxScore = max(player1Score, player2Score)
        let minScore = min(player1Score, player2Score)
        return maxScore >= 11 && (maxScore - minScore) >= 2
    }

    var winner: Player? {
        guard isGameOver else { return nil }
        return player1Score > player2Score ? .player1 : .player2
    }

    var canUndo: Bool {
        !points.isEmpty
    }

    var lastPoint: Point? {
        points.last
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

        // Save current server for undo
        previousServers.append(currentServer)

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

    /// Undo the last point
    func undoLastPoint() {
        guard let lastPoint = points.popLast() else { return }

        // Restore score
        switch lastPoint.scorer {
        case .player1:
            player1Score -= 1
        case .player2:
            player2Score -= 1
        }

        // Restore previous server
        if let previousServer = previousServers.popLast() {
            currentServer = previousServer
        }

        selectedPlayer = nil
    }

    func reset() {
        player1Score = 0
        player2Score = 0
        currentServer = startingServer
        points = []
        previousServers = []
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

    /// Get win percentage for a player in a specific zone
    func winPercentage(for player: Player, in zone: CourtZone) -> Double {
        let won = points.filter { $0.scorer == player && $0.zone == zone }.count
        let lost = points.filter { $0.scorer == player.opponent && $0.zone == zone }.count
        let total = won + lost
        guard total > 0 else { return 0 }
        return Double(won) / Double(total) * 100
    }

    /// Get total points played in a zone
    func totalPoints(in zone: CourtZone) -> Int {
        points.filter { $0.zone == zone }.count
    }

    /// Get the best zone for a player (highest win count)
    func bestZone(for player: Player) -> CourtZone? {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, count: pointsWon(by: player, in: zone))
        }
        return zoneCounts.max(by: { $0.count < $1.count })?.zone
    }

    /// Get the worst zone for a player (most points lost)
    func worstZone(for player: Player) -> CourtZone? {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, count: pointsWon(by: player.opponent, in: zone))
        }
        return zoneCounts.max(by: { $0.count < $1.count })?.zone
    }

    /// Get recommendation: zones where opponent is weak
    func recommendedZones(against player: Player) -> [CourtZone] {
        // Zones where the opponent loses the most points
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, lostCount: pointsWon(by: player.opponent, in: zone))
        }
        .filter { $0.lostCount > 0 }
        .sorted { $0.lostCount > $1.lostCount }

        return zoneCounts.prefix(3).map { $0.zone }
    }
}
