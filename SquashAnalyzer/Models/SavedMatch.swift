import Foundation
import SwiftData

/// Persisted match model for SwiftData
@Model
final class SavedMatch {
    var id: UUID
    var player1Name: String
    var player2Name: String
    var matchStartingServer: String  // Player rawValue
    var bestOf: Int
    var savedAt: Date
    var updatedAt: Date = Date()
    var status: String = MatchStatus.completed.rawValue
    var player1CoachingFocus: [String] = []
    var player2CoachingFocus: [String] = []
    var player1CoachingNotes: String = ""
    var player2CoachingNotes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \SavedGame.match)
    var games: [SavedGame] = []

    init(
        id: UUID = UUID(),
        player1Name: String,
        player2Name: String,
        matchStartingServer: Player,
        bestOf: Int = 5,
        savedAt: Date = Date(),
        updatedAt: Date = Date(),
        status: MatchStatus = .completed
    ) {
        self.id = id
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.matchStartingServer = matchStartingServer.rawValue
        self.bestOf = bestOf
        self.savedAt = savedAt
        self.updatedAt = updatedAt
        self.status = status.rawValue
    }

    // MARK: - Computed Properties

    var startingServer: Player {
        Player(rawValue: matchStartingServer) ?? .player1
    }

    var matchStatus: MatchStatus {
        get { MatchStatus(rawValue: status) ?? .completed }
        set { status = newValue.rawValue }
    }

    var player1GamesWon: Int {
        games.filter { $0.winner == Player.player1.rawValue }.count
    }

    var player2GamesWon: Int {
        games.filter { $0.winner == Player.player2.rawValue }.count
    }

    var gamesToWin: Int {
        (bestOf / 2) + 1
    }

    var isMatchOver: Bool {
        player1GamesWon >= gamesToWin || player2GamesWon >= gamesToWin
    }

    var matchWinner: Player? {
        guard isMatchOver else { return nil }
        return player1GamesWon > player2GamesWon ? .player1 : .player2
    }

    var winnerName: String? {
        guard let winner = matchWinner else { return nil }
        return winner == .player1 ? player1Name : player2Name
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: savedAt)
    }

    var scoreString: String {
        "\(player1GamesWon) - \(player2GamesWon)"
    }

    // MARK: - Conversion to Live Match

    /// Convert this SavedMatch back to a live Match for analysis views
    func toMatch() -> Match {
        let match = Match(id: id)
        match.player1Name = player1Name
        match.player2Name = player2Name
        match.matchStartingServer = startingServer
        match.status = matchStatus
        match.updatedAt = updatedAt
        match.player1CoachingFocus = player1CoachingFocus
        match.player2CoachingFocus = player2CoachingFocus
        match.player1CoachingNotes = player1CoachingNotes
        match.player2CoachingNotes = player2CoachingNotes
        // Replace the default empty game with converted saved games
        match.games = games
            .sorted(by: { $0.gameNumber < $1.gameNumber })
            .map { $0.toGame() }
        match.currentGameIndex = max(0, match.games.count - 1)
        return match
    }

    // MARK: - Factory Method

    /// Create a SavedMatch from a live Match
    static func from(_ match: Match, context: ModelContext) -> SavedMatch {
        let savedMatch = SavedMatch(
            id: match.id,
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            matchStartingServer: match.matchStartingServer,
            bestOf: match.bestOf,
            updatedAt: match.updatedAt,
            status: match.status
        )

        savedMatch.player1CoachingFocus = match.player1CoachingFocus
        savedMatch.player2CoachingFocus = match.player2CoachingFocus
        savedMatch.player1CoachingNotes = match.player1CoachingNotes
        savedMatch.player2CoachingNotes = match.player2CoachingNotes

        context.insert(savedMatch)

        // Convert and save all games
        for (index, game) in match.games.enumerated() {
            let savedGame = SavedGame.from(game, gameNumber: index + 1, context: context)
            savedGame.match = savedMatch
            savedMatch.games.append(savedGame)
        }

        return savedMatch
    }
}
