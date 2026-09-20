import Foundation

enum MatchStatus: String, Codable, CaseIterable {
    case inProgress
    case completed
    case abandoned
}

/// Represents a squash match (best of 5 games)
@Observable
class Match: Identifiable {
    let id: UUID
    var status: MatchStatus = .inProgress
    var updatedAt: Date = Date()
    // MARK: - Properties
    var player1Name: String = "Speler 1"
    var player2Name: String = "Speler 2"

    /// Coaching focus areas for each player (from saved player profiles)
    var player1CoachingFocus: [String] = []
    var player2CoachingFocus: [String] = []
    var player1CoachingNotes: String = ""
    var player2CoachingNotes: String = ""

    /// All games in this match
    var games: [Game] = []

    /// Index of current game being played
    var currentGameIndex: Int = 0

    /// Starting server for the match
    var matchStartingServer: Player = .player1

    /// Games already won when tracking started at game 2 or later ("later instappen").
    /// They count towards the stand but have no games of their own.
    var player1GamesBefore: Int = 0
    var player2GamesBefore: Int = 0

    /// Best of X games (default 5)
    let bestOf: Int = 5

    /// Games needed to win
    var gamesToWin: Int {
        (bestOf / 2) + 1 // 3 for best of 5
    }

    /// Number of the first tracked game (1 unless the match was picked up later)
    var firstGameNumber: Int { 1 + player1GamesBefore + player2GamesBefore }

    /// Match game number for `games[index]`
    func gameNumber(at index: Int) -> Int { firstGameNumber + index }

    var currentGameNumber: Int { gameNumber(at: currentGameIndex) }

    /// Neither player may already have won the match, and the games before must fit in best-of
    static func isValidHeadStart(player1: Int, player2: Int, bestOf: Int = 5) -> Bool {
        let toWin = (bestOf / 2) + 1
        return player1 >= 0 && player2 >= 0 && player1 < toWin && player2 < toWin
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
        player1GamesBefore + games.filter { $0.winner == .player1 }.count
    }

    var player2GamesWon: Int {
        player2GamesBefore + games.filter { $0.winner == .player2 }.count
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

    init(id: UUID = UUID()) {
        self.id = id
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

        // The Links/Rechts hand-out boxes hold for the whole match
        if let lastGame = games.last {
            game.player1PreferredSide = lastGame.player1PreferredSide
            game.player2PreferredSide = lastGame.player2PreferredSide
        }

        // Alternate starting server each game, or winner of previous game serves
        if let lastGame = games.last, let lastWinner = lastGame.winner {
            game.setStartingServer(lastWinner)
        } else {
            game.setStartingServer(matchStartingServer)
        }

        games.append(game)
        currentGameIndex = games.count - 1
        updatedAt = Date()
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
        status = .inProgress
    }

    /// Setup match with player names and starting server
    func setupMatch(
        player1: String,
        player2: String,
        startingServer: Player,
        player1CoachingFocus: [String] = [],
        player1CoachingNotes: String = "",
        player2CoachingFocus: [String] = [],
        player2CoachingNotes: String = "",
        player1GamesBefore: Int = 0,
        player2GamesBefore: Int = 0
    ) {
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
    func coachingFocus(for player: Player) -> [String] {
        player == .player1 ? player1CoachingFocus : player2CoachingFocus
    }

    /// Get coaching notes for a player
    func coachingNotes(for player: Player) -> String {
        player == .player1 ? player1CoachingNotes : player2CoachingNotes
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
        guard let best = zoneCounts.max(by: { $0.count < $1.count }), best.count > 0 else { return nil }
        return best.zone
    }

    // MARK: - Duration Analysis

    /// Average duration of points won by a player across all games
    func averageDurationWon(by player: Player) -> TimeInterval? {
        let wonPoints = allPoints.filter { $0.scorer == player }
        guard !wonPoints.isEmpty else { return nil }
        let totalDuration = wonPoints.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(wonPoints.count)
    }

    /// Average duration of points lost by a player across all games
    func averageDurationLost(by player: Player) -> TimeInterval? {
        let lostPoints = allPoints.filter { $0.scorer == player.opponent }
        guard !lostPoints.isEmpty else { return nil }
        let totalDuration = lostPoints.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(lostPoints.count)
    }

    /// Average point duration across all games
    func averagePointDuration() -> TimeInterval? {
        guard !allPoints.isEmpty else { return nil }
        let totalDuration = allPoints.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(allPoints.count)
    }

    /// Total match duration (sum of all rally durations)
    func totalMatchDuration() -> TimeInterval {
        allPoints.reduce(0) { $0 + $1.duration }
    }

    /// Win percentage for short rallies across all games
    func shortRallyWinPercentage(for player: Player) -> Double? {
        guard allPoints.count >= 2 else { return nil }
        let sortedDurations = allPoints.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let shortRallies = allPoints.filter { $0.duration < medianDuration }
        guard !shortRallies.isEmpty else { return nil }

        let won = shortRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(shortRallies.count) * 100
    }

    /// Win percentage for long rallies across all games
    func longRallyWinPercentage(for player: Player) -> Double? {
        guard allPoints.count >= 2 else { return nil }
        let sortedDurations = allPoints.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let longRallies = allPoints.filter { $0.duration >= medianDuration }
        guard !longRallies.isEmpty else { return nil }

        let won = longRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(longRallies.count) * 100
    }

    // MARK: - Export

    /// Short WhatsApp update for the game-over / match-over overlay: the game just
    /// played and the stand in games, in the same style as the referee's short text.
    var whatsAppText: String {
        let finished = games.enumerated().filter { $0.element.winner != nil }
        let p1 = player1GamesWon, p2 = player2GamesWon
        var lines: [String] = []

        if isMatchOver {
            lines.append("🏸 *Squash · Wedstrijd klaar*")
            lines.append("🏆 " + boldLeaderLine(p1: p1, p2: p2))
        } else {
            let number = finished.last.map { gameNumber(at: $0.offset) } ?? currentGameNumber
            lines.append("🏸 *Squash · Game \(number) klaar*")
            if let game = finished.last?.element {
                lines.append("Game: " + boldLeaderLine(p1: game.player1Score, p2: game.player2Score))
            }
            lines.append("Games: " + boldLeaderLine(p1: p1, p2: p2))
        }

        if !finished.isEmpty {
            var scores = finished.map { "\($0.element.player1Score)-\($0.element.player2Score)" }.joined(separator: " · ")
            if firstGameNumber > 1 { scores += " (vanaf game \(firstGameNumber))" }
            lines.append(scores)
        }
        return lines.joined(separator: "\n")
    }

    /// "Jan 3 – 1 Piet" with the winner (or leader) in bold, in player order
    private func boldLeaderLine(p1: Int, p2: Int) -> String {
        let name1 = p1 > p2 ? "*\(player1Name)*" : player1Name
        let name2 = p2 > p1 ? "*\(player2Name)*" : player2Name
        return "\(name1) \(p1) – \(p2) \(name2)"
    }

    // MARK: - Let Analysis

    /// Get all lets from all games
    var allLets: [LetCall] {
        games.flatMap { $0.lets }
    }

    /// Total number of lets in the match
    var totalLets: Int {
        allLets.count
    }

    /// Lets requested by a specific player across all games
    func letsRequested(by player: Player) -> [LetCall] {
        allLets.filter { $0.requestedBy == player }
    }
}
