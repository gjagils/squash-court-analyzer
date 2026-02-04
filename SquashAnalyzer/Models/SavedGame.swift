import Foundation
import SwiftData

/// Persisted game model for SwiftData
@Model
final class SavedGame {
    var id: UUID
    var gameNumber: Int
    var player1Name: String
    var player2Name: String
    var player1Score: Int
    var player2Score: Int
    var startingServer: String  // Player rawValue
    var winner: String?  // Player rawValue (nil if game not finished)

    var match: SavedMatch?

    @Relationship(deleteRule: .cascade, inverse: \SavedPoint.game)
    var points: [SavedPoint] = []

    @Relationship(deleteRule: .cascade, inverse: \SavedLet.game)
    var lets: [SavedLet] = []

    init(
        id: UUID = UUID(),
        gameNumber: Int,
        player1Name: String,
        player2Name: String,
        player1Score: Int,
        player2Score: Int,
        startingServer: Player,
        winner: Player? = nil
    ) {
        self.id = id
        self.gameNumber = gameNumber
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.startingServer = startingServer.rawValue
        self.winner = winner?.rawValue
    }

    // MARK: - Computed Properties

    var gameStartingServer: Player {
        Player(rawValue: startingServer) ?? .player1
    }

    var gameWinner: Player? {
        guard let winnerRaw = winner else { return nil }
        return Player(rawValue: winnerRaw)
    }

    var isGameOver: Bool {
        let maxScore = max(player1Score, player2Score)
        let minScore = min(player1Score, player2Score)
        return maxScore >= 11 && (maxScore - minScore) >= 2
    }

    var scoreString: String {
        "\(player1Score) - \(player2Score)"
    }

    // MARK: - Analysis Methods

    func pointsWon(by player: Player) -> [SavedPoint] {
        points.filter { $0.scorerPlayer == player }
    }

    func pointsWon(by player: Player, in zone: CourtZone) -> Int {
        points.filter { $0.scorerPlayer == player && $0.pointZone == zone }.count
    }

    func pointsWon(by player: Player, with shotType: ShotType) -> Int {
        points.filter { $0.scorerPlayer == player && $0.pointShotType == shotType }.count
    }

    // MARK: - Duration Analysis

    /// Average duration of points won by a player
    func averageDurationWon(by player: Player) -> TimeInterval? {
        let wonPoints = pointsWon(by: player)
        guard !wonPoints.isEmpty else { return nil }
        let totalDuration = wonPoints.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(wonPoints.count)
    }

    /// Average duration of points lost by a player
    func averageDurationLost(by player: Player) -> TimeInterval? {
        let lostPoints = points.filter { $0.scorerPlayer == player.opponent }
        guard !lostPoints.isEmpty else { return nil }
        let totalDuration = lostPoints.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(lostPoints.count)
    }

    /// Total game duration (sum of all rally durations)
    func totalGameDuration() -> TimeInterval {
        points.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Conversion to Live Game

    /// Convert this SavedGame back to a live Game for analysis views
    func toGame() -> Game {
        let game = Game()
        game.player1Name = player1Name
        game.player2Name = player2Name
        game.player1Score = player1Score
        game.player2Score = player2Score
        game.setStartingServer(gameStartingServer)
        game.points = points
            .sorted(by: { $0.pointNumber < $1.pointNumber })
            .map { sp in
                Point(
                    scorer: sp.scorerPlayer,
                    zone: sp.pointZone,
                    shotType: sp.pointShotType,
                    server: sp.serverPlayer,
                    player1Score: sp.player1Score,
                    player2Score: sp.player2Score,
                    duration: sp.duration
                )
            }
        game.lets = lets
            .sorted(by: { $0.letNumber < $1.letNumber })
            .map { sl in
                Let(
                    requestedBy: sl.requestedByPlayer,
                    server: sl.serverPlayer,
                    player1Score: sl.player1Score,
                    player2Score: sl.player2Score
                )
            }
        return game
    }

    // MARK: - Factory Method

    /// Create a SavedGame from a live Game
    static func from(_ game: Game, gameNumber: Int, context: ModelContext) -> SavedGame {
        let savedGame = SavedGame(
            gameNumber: gameNumber,
            player1Name: game.player1Name,
            player2Name: game.player2Name,
            player1Score: game.player1Score,
            player2Score: game.player2Score,
            startingServer: game.startingServer,
            winner: game.winner
        )

        context.insert(savedGame)

        // Convert and save all points
        for (index, point) in game.points.enumerated() {
            let savedPoint = SavedPoint.from(point, pointNumber: index + 1)
            savedPoint.game = savedGame
            savedGame.points.append(savedPoint)
            context.insert(savedPoint)
        }

        // Convert and save all lets
        for (index, letCall) in game.lets.enumerated() {
            let savedLet = SavedLet.from(letCall, letNumber: index + 1)
            savedLet.game = savedGame
            savedGame.lets.append(savedLet)
            context.insert(savedLet)
        }

        return savedGame
    }

    // MARK: - Let Analysis

    /// Get all lets requested by a player
    func letsRequested(by player: Player) -> [SavedLet] {
        lets.filter { $0.requestedByPlayer == player }
    }

    /// Total number of lets in this game
    var totalLets: Int {
        lets.count
    }
}
