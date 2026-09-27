import Foundation
import Observation

public enum MatchStatus: String, Codable, CaseIterable {
    case inProgress
    case completed
    case abandoned
}

/// Represents a squash match (best of 5 games)
@Observable
public class Match: Identifiable {
    public let id: UUID
    public var status: MatchStatus = .inProgress
    public var updatedAt: Date = Date()
    // MARK: - Properties
    public var player1Name: String = "Speler 1"
    public var player2Name: String = "Speler 2"

    /// Coaching focus areas for each player (from saved player profiles)
    public var player1CoachingFocus: [String] = []
    public var player2CoachingFocus: [String] = []
    public var player1CoachingNotes: String = ""
    public var player2CoachingNotes: String = ""

    /// `SavedPlayer.id` of a player picked from "Kies speler"; only those earn badges
    public var player1Id: UUID? = nil
    public var player2Id: UUID? = nil

    /// All games in this match
    public var games: [Game] = []

    /// Index of current game being played
    public var currentGameIndex: Int = 0

    /// Starting server for the match
    public var matchStartingServer: Player = .player1

    /// Games already won when tracking started at game 2 or later ("later instappen").
    /// They count towards the stand but have no games of their own.
    public var player1GamesBefore: Int = 0
    public var player2GamesBefore: Int = 0

    /// Games won after tracking stopped, filled in afterwards ("uitslag aanvullen").
    /// Like the games before, they count towards the stand but have no games of their own.
    public var player1GamesAfter: Int = 0
    public var player2GamesAfter: Int = 0

    /// Best of X games (default 5)
    public let bestOf: Int = 5

    /// Games needed to win
    public var gamesToWin: Int {
        (bestOf / 2) + 1 // 3 for best of 5
    }

    /// Number of the first tracked game (1 unless the match was picked up later)
    public var firstGameNumber: Int { 1 + player1GamesBefore + player2GamesBefore }

    /// Match game number for `games[index]`
    public func gameNumber(at index: Int) -> Int { firstGameNumber + index }

    public var currentGameNumber: Int { gameNumber(at: currentGameIndex) }

    /// Neither player may already have won the match, and the games before must fit in best-of
    public static func isValidHeadStart(player1: Int, player2: Int, bestOf: Int = 5) -> Bool {
        let toWin = (bestOf / 2) + 1
        return player1 >= 0 && player2 >= 0 && player1 < toWin && player2 < toWin
    }

    // MARK: - Computed Properties

    public var currentGame: Game {
        guard currentGameIndex < games.count else {
            // Create first game if none exists
            let game = Game()
            game.player1Name = player1Name
            game.player2Name = player2Name
            game.assignStartingServer(matchStartingServer)
            games.append(game)
            return game
        }
        return games[currentGameIndex]
    }

    public var player1GamesWon: Int {
        player1GamesBefore + games.filter { $0.winner == .player1 }.count + player1GamesAfter
    }

    public var player2GamesWon: Int {
        player2GamesBefore + games.filter { $0.winner == .player2 }.count + player2GamesAfter
    }

    public var isMatchOver: Bool {
        player1GamesWon >= gamesToWin || player2GamesWon >= gamesToWin
    }

    public var matchWinner: Player? {
        guard isMatchOver else { return nil }
        return player1GamesWon > player2GamesWon ? .player1 : .player2
    }

    public var completedGames: [Game] {
        games.filter { $0.isGameOver }
    }

    // MARK: - Initialization

    public init(id: UUID = UUID()) {
        self.id = id
        startNewGame()
    }

    // MARK: - Methods

    public func name(for player: Player) -> String {
        switch player {
        case .player1: return player1Name
        case .player2: return player2Name
        }
    }

    public func gamesWon(by player: Player) -> Int {
        switch player {
        case .player1: return player1GamesWon
        case .player2: return player2GamesWon
        }
    }

    /// Start a new game in the match
    public func startNewGame() {
        let game = Game()
        game.player1Name = player1Name
        game.player2Name = player2Name

        // The Links/Rechts hand-out boxes hold for the whole match
        if let lastGame = games.last {
            game.player1PreferredSide = lastGame.player1PreferredSide
            game.player2PreferredSide = lastGame.player2PreferredSide
        }

        // Alternate starting server each game, or winner of previous game serves
        if let lastGame = games.last, let lastWinner = lastGame.winner {
            game.assignStartingServer(lastWinner)
        } else {
            game.assignStartingServer(matchStartingServer)
        }

        games.append(game)
        currentGameIndex = games.count - 1
        updatedAt = Date()
    }

    /// Number of the first game without a tracked result (an unfinished game counts as untracked)
    public var firstUnrecordedGameNumber: Int {
        firstGameNumber + games.filter { $0.winner != nil }.count
    }

    /// Whether `winners` (one per game from `firstUnrecordedGameNumber` on) decide the
    /// match exactly with their last game
    public func isValidResultCompletion(_ winners: [Player]) -> Bool {
        guard !isMatchOver, !winners.isEmpty else { return false }
        var p1 = player1GamesWon, p2 = player2GamesWon
        for (index, winner) in winners.enumerated() {
            if winner == .player1 { p1 += 1 } else { p2 += 1 }
            let decided = p1 >= gamesToWin || p2 >= gamesToWin
            if decided != (index == winners.count - 1) { return false }
        }
        return true
    }

    /// Finish an incomplete match with only the winners of the games that were not
    /// tracked. An unfinished game without rallies is dropped; one with rallies keeps
    /// them for analysis and its winner is the first of `winners`.
    @discardableResult
    public func completeResult(with winners: [Player]) -> Bool {
        guard isValidResultCompletion(winners) else { return false }
        if let last = games.last, last.winner == nil, last.points.isEmpty, last.lets.isEmpty {
            games.removeLast()
        }
        player1GamesAfter = winners.filter { $0 == .player1 }.count
        player2GamesAfter = winners.count - player1GamesAfter
        currentGameIndex = max(0, games.count - 1)
        status = .completed
        updatedAt = Date()
        return true
    }

    /// Called when current game ends - starts next game if match not over
    public func onGameEnd() {
        if !isMatchOver {
            startNewGame()
        }
    }

    /// Reset the entire match
    public func resetMatch() {
        games = []
        currentGameIndex = 0
        player1GamesAfter = 0
        player2GamesAfter = 0
        startNewGame()
        status = .inProgress
    }

    /// Setup match with player names and starting server
    public func setupMatch(
        player1: String,
        player2: String,
        startingServer: Player,
        player1CoachingFocus: [String] = [],
        player1CoachingNotes: String = "",
        player2CoachingFocus: [String] = [],
        player2CoachingNotes: String = "",
        player1GamesBefore: Int = 0,
        player2GamesBefore: Int = 0,
        player1Id: UUID? = nil,
        player2Id: UUID? = nil
    ) {
        self.player1Id = player1Id
        self.player2Id = player2Id
        player1Name = player1.isEmpty ? "Speler 1" : player1
        player2Name = player2.isEmpty ? "Speler 2" : player2
        matchStartingServer = startingServer
        self.player1CoachingFocus = player1CoachingFocus
        self.player1CoachingNotes = player1CoachingNotes
        self.player2CoachingFocus = player2CoachingFocus
        self.player2CoachingNotes = player2CoachingNotes
        let validHeadStart = Self.isValidHeadStart(player1: player1GamesBefore, player2: player2GamesBefore, bestOf: bestOf)
        self.player1GamesBefore = validHeadStart ? player1GamesBefore : 0
        self.player2GamesBefore = validHeadStart ? player2GamesBefore : 0
        resetMatch()
    }

    /// Get coaching focus for a player
    public func coachingFocus(for player: Player) -> [String] {
        player == .player1 ? player1CoachingFocus : player2CoachingFocus
    }

    /// Get coaching notes for a player
    public func coachingNotes(for player: Player) -> String {
        player == .player1 ? player1CoachingNotes : player2CoachingNotes
    }

    // MARK: - Analysis helpers

    /// Get all points from all games
    public var allPoints: [Point] {
        games.flatMap { $0.points }
    }

    /// Get points for a specific game
    public func points(forGame index: Int) -> [Point] {
        guard index < games.count else { return [] }
        return games[index].points
    }

    /// Total points won by player across all games
    public func totalPointsWon(by player: Player) -> Int {
        games.reduce(0) { $0 + $1.pointsWon(by: player).count }
    }

    /// Points won by player in a specific zone across all games
    public func totalPointsWon(by player: Player, in zone: CourtZone) -> Int {
        games.reduce(0) { $0 + $1.pointsWon(by: player, in: zone) }
    }

    /// Points won by player with a specific shot type across all games
    public func totalPointsWon(by player: Player, with shotType: ShotType) -> Int {
        allPoints.filter { $0.scorer == player && $0.shotType == shotType }.count
    }

    /// Most effective shot type for a player
    public func mostEffectiveShot(for player: Player) -> ShotType? {
        let shotCounts = ShotType.allCases.map { shotType in
            (shotType: shotType, count: totalPointsWon(by: player, with: shotType))
        }
        guard let best = shotCounts.max(by: { $0.count < $1.count }) else { return nil }
        return best.shotType
    }

    /// Best zone for a player across all games
    public func bestZone(for player: Player) -> CourtZone? {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, count: totalPointsWon(by: player, in: zone))
        }
        guard let best = zoneCounts.max(by: { $0.count < $1.count }), best.count > 0 else { return nil }
        return best.zone
    }

    // MARK: - Duration Analysis

    /// Average duration of points won by a player across all games
    public func averageDurationWon(by player: Player) -> TimeInterval? {
        let wonPoints = allPoints.filter { $0.scorer == player }
        guard !wonPoints.isEmpty else { return nil }
        let totalDuration = wonPoints.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(wonPoints.count)
    }

    /// Average duration of points lost by a player across all games
    public func averageDurationLost(by player: Player) -> TimeInterval? {
        let lostPoints = allPoints.filter { $0.scorer == player.opponent }
        guard !lostPoints.isEmpty else { return nil }
        let totalDuration = lostPoints.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(lostPoints.count)
    }

    /// Average point duration across all games
    public func averagePointDuration() -> TimeInterval? {
        guard !allPoints.isEmpty else { return nil }
        let totalDuration = allPoints.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(allPoints.count)
    }

    /// Total match duration (sum of all rally durations)
    public func totalMatchDuration() -> TimeInterval {
        allPoints.reduce(0.0) { $0 + $1.duration }
    }

    /// Win percentage for short rallies across all games
    public func shortRallyWinPercentage(for player: Player) -> Double? {
        guard allPoints.count >= 2 else { return nil }
        let sortedDurations = allPoints.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let shortRallies = allPoints.filter { $0.duration < medianDuration }
        guard !shortRallies.isEmpty else { return nil }

        let won = shortRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(shortRallies.count) * 100
    }

    /// Win percentage for long rallies across all games
    public func longRallyWinPercentage(for player: Player) -> Double? {
        guard allPoints.count >= 2 else { return nil }
        let sortedDurations = allPoints.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let longRallies = allPoints.filter { $0.duration >= medianDuration }
        guard !longRallies.isEmpty else { return nil }

        let won = longRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(longRallies.count) * 100
    }

    // MARK: - Export

    /// Default WhatsApp text (the short style); the share sheet lets the user pick another
    public var whatsAppText: String { shareText(style: .compact) }

    public func shareText(style: MatchShareStyle) -> String { shareReport.text(style: style) }

    /// The match as the share texts see it (shared with referee mode). Games
    /// before tracking started and filled-in games count in the stand only.
    public var shareReport: MatchShareReport {
        let played = games.enumerated().filter { !$0.element.points.isEmpty || $0.element.winner != nil }
        let firstPoint = allPoints.min { $0.timestamp < $1.timestamp }
        return MatchShareReport(
            player1Name: player1Name,
            player2Name: player2Name,
            bestOf: bestOf,
            firstGameNumber: firstGameNumber,
            player1Games: player1GamesWon,
            player2Games: player2GamesWon,
            matchWinner: matchWinner,
            games: played.map { index, game in
                let duration = game.points.reduce(0.0) { $0 + $1.duration }
                return MatchShareReport.Game(number: gameNumber(at: index), player1Score: game.player1Score,
                                             player2Score: game.player2Score, winner: game.winner,
                                             duration: duration > 0 ? duration : nil,
                                             rallyWinners: game.points.map(\.scorer),
                                             strokes: game.points.filter { $0.pointType == .stroke }.count)
            },
            startedAt: firstPoint.map { $0.timestamp.addingTimeInterval(-$0.duration) } ?? Date(),
            duration: totalMatchDuration()
        )
    }

    // MARK: - Let Analysis

    /// Get all lets from all games
    public var allLets: [LetCall] {
        games.flatMap { $0.lets }
    }

    /// Total number of lets in the match
    public var totalLets: Int {
        allLets.count
    }

    /// Lets requested by a specific player across all games
    public func letsRequested(by player: Player) -> [LetCall] {
        allLets.filter { $0.requestedBy == player }
    }
}
