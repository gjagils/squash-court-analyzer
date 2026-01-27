import Foundation

/// Represents a squash match (best of 5 games)
@Observable
class Match {
    // MARK: - Properties
    var player1Name: String = "Speler 1"
    var player2Name: String = "Speler 2"

    /// All games in this match
    var games: [Game] = []

    /// Index of current game being played
    var currentGameIndex: Int = 0

    /// Starting server for the match
    var matchStartingServer: Player = .player1

    /// Best of X games (default 5)
    let bestOf: Int = 5

    /// Games needed to win
    var gamesToWin: Int {
        (bestOf / 2) + 1 // 3 for best of 5
    }

    // MARK: - Computed Properties

    var currentGame: Game {
        guard currentGameIndex < games.count else {
            // Create first game if none exists
            let game = Game()
            game.player1Name = player1Name
            game.player2Name = player2Name
            game.setStartingServer(matchStartingServer)
            games.append(game)
            return game
        }
        return games[currentGameIndex]
    }

    var player1GamesWon: Int {
        games.filter { $0.winner == .player1 }.count
    }

    var player2GamesWon: Int {
        games.filter { $0.winner == .player2 }.count
    }

    var isMatchOver: Bool {
        player1GamesWon >= gamesToWin || player2GamesWon >= gamesToWin
    }

    var matchWinner: Player? {
        guard isMatchOver else { return nil }
        return player1GamesWon > player2GamesWon ? .player1 : .player2
    }

    var completedGames: [Game] {
        games.filter { $0.isGameOver }
    }

    // MARK: - Initialization

    init() {
        startNewGame()
    }

    // MARK: - Methods

    func name(for player: Player) -> String {
        switch player {
        case .player1: return player1Name
        case .player2: return player2Name
        }
    }

    func gamesWon(by player: Player) -> Int {
        switch player {
        case .player1: return player1GamesWon
        case .player2: return player2GamesWon
        }
    }

    /// Start a new game in the match
    func startNewGame() {
        let game = Game()
        game.player1Name = player1Name
        game.player2Name = player2Name

        // Alternate starting server each game, or winner of previous game serves
        if let lastGame = games.last, let lastWinner = lastGame.winner {
            game.setStartingServer(lastWinner)
        } else {
            game.setStartingServer(matchStartingServer)
        }

        games.append(game)
        currentGameIndex = games.count - 1
    }

    /// Called when current game ends - starts next game if match not over
    func onGameEnd() {
        if !isMatchOver {
            startNewGame()
        }
    }

    /// Reset the entire match
    func resetMatch() {
        games = []
        currentGameIndex = 0
        startNewGame()
    }

    /// Setup match with player names and starting server
    func setupMatch(player1: String, player2: String, startingServer: Player) {
        player1Name = player1.isEmpty ? "Speler 1" : player1
        player2Name = player2.isEmpty ? "Speler 2" : player2
        matchStartingServer = startingServer
        resetMatch()
    }

    // MARK: - Analysis helpers

    /// Get all points from all games
    var allPoints: [Point] {
        games.flatMap { $0.points }
    }

    /// Get points for a specific game
    func points(forGame index: Int) -> [Point] {
        guard index < games.count else { return [] }
        return games[index].points
    }

    /// Total points won by player across all games
    func totalPointsWon(by player: Player) -> Int {
        games.reduce(0) { $0 + $1.pointsWon(by: player).count }
    }

    /// Points won by player in a specific zone across all games
    func totalPointsWon(by player: Player, in zone: CourtZone) -> Int {
        games.reduce(0) { $0 + $1.pointsWon(by: player, in: zone) }
    }

    /// Points won by player with a specific shot type across all games
    func totalPointsWon(by player: Player, with shotType: ShotType) -> Int {
        allPoints.filter { $0.scorer == player && $0.shotType == shotType }.count
    }

    /// Most effective shot type for a player
    func mostEffectiveShot(for player: Player) -> ShotType? {
        let shotCounts = ShotType.allCases.map { shotType in
            (shotType: shotType, count: totalPointsWon(by: player, with: shotType))
        }
        return shotCounts.max(by: { $0.count < $1.count })?.shotType
    }

    /// Best zone for a player across all games
    func bestZone(for player: Player) -> CourtZone? {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, count: totalPointsWon(by: player, in: zone))
        }
        return zoneCounts.max(by: { $0.count < $1.count })?.zone
    }
}
