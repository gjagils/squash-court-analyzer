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

    /// Best of 1, 3 or 5 games (Gerd-Jan, 22 October 2026: a training match is
    /// often shorter than best of 5). Chosen in the match setup; 5 by default
    public var bestOf: Int = 5

    /// The formats the setup offers
    public static let bestOfOptions: [Int] = [1, 3, 5]

    /// A format the app knows, or 5 (an older backup without the field, a stray value)
    public static func validBestOf(_ bestOf: Int) -> Int {
        bestOfOptions.contains(bestOf) ? bestOf : 5
    }

    /// Games needed to win
    public var gamesToWin: Int {
        MatchStand.gamesToWin(bestOf: bestOf) // 3 for best of 5
    }

    /// Number of the first tracked game (1 unless the match was picked up later)
    public var firstGameNumber: Int { 1 + player1GamesBefore + player2GamesBefore }

    /// Match game number for `games[index]`
    public func gameNumber(at index: Int) -> Int { firstGameNumber + index }

    public var currentGameNumber: Int { gameNumber(at: currentGameIndex) }

    /// Neither player may already have won the match, and the games before must fit in best-of
    public static func isValidHeadStart(player1: Int, player2: Int, bestOf: Int = 5) -> Bool {
        let toWin = MatchStand.gamesToWin(bestOf: bestOf)
        return player1 >= 0 && player2 >= 0 && player1 < toWin && player2 < toWin
    }

    // MARK: - Computed Properties

    /// The game being played. Pure: `init` and `startNewGame` make the games, and
    /// `completeResult` never leaves the list empty. Only when `games` was
    /// emptied from outside, a detached empty game is returned (not added).
    public var currentGame: Game {
        if currentGameIndex < games.count { return games[currentGameIndex] }
        if let last = games.last { return last }
        let game = Game()
        game.player1Name = player1Name
        game.player2Name = player2Name
        game.assignStartingServer(matchStartingServer)
        return game
    }

    public var player1GamesWon: Int {
        player1GamesBefore + games.filter { $0.winner == .player1 }.count + player1GamesAfter
    }

    public var player2GamesWon: Int {
        player2GamesBefore + games.filter { $0.winner == .player2 }.count + player2GamesAfter
    }

    private var stand: MatchStand { MatchStand(bestOf: bestOf, player1Games: player1GamesWon, player2Games: player2GamesWon) }

    public var isMatchOver: Bool { stand.isOver }

    public var matchWinner: Player? { stand.winner }

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

    /// Correct the names during the match (Gerd-Jan, 21 October 2026): a typo,
    /// or the real names after a quick start with "Speler 1". The games played
    /// so far follow, so the analysis, the advice and the share text use the
    /// new names. A player picked from Spelers stays linked only under their
    /// own name: another name is another person, so the id and the profile's
    /// coaching focus go, as in the match setup. Empty is the default again.
    public func rename(player1: String, player2: String) {
        let name1 = Match.cleanName(player1, fallback: "Speler 1")
        let name2 = Match.cleanName(player2, fallback: "Speler 2")
        if name1 != player1Name {
            player1Id = nil
            player1CoachingFocus = [String]()
            player1CoachingNotes = ""
        }
        if name2 != player2Name {
            player2Id = nil
            player2CoachingFocus = [String]()
            player2CoachingNotes = ""
        }
        player1Name = name1
        player2Name = name2
        for game in games {
            game.player1Name = name1
            game.player2Name = name2
        }
        updatedAt = Date()
    }

    /// The name without the spaces around it, or the fallback when nothing is left
    static func cleanName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
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
        // An untouched last game goes, but the match always keeps one game
        if games.count > 1, let last = games.last, last.winner == nil, last.points.isEmpty, last.lets.isEmpty {
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
        player2Id: UUID? = nil,
        bestOf: Int = 5
    ) {
        self.player1Id = player1Id
        self.player2Id = player2Id
        self.bestOf = Match.validBestOf(bestOf)
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

    // MARK: - Analysis helpers

    /// Get all points from all games
    public var allPoints: [Point] {
        games.flatMap { $0.points }
    }

    /// Total match duration (sum of all rally durations)
    public func totalMatchDuration() -> TimeInterval {
        allPoints.reduce(0.0) { $0 + $1.duration }
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
                                             rallyWinners: game.points.map { $0.scorer },
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

}
