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

    @Relationship(deleteRule: .cascade, inverse: \SavedGame.match)
    var games: [SavedGame] = []

    init(
        id: UUID = UUID(),
        player1Name: String,
        player2Name: String,
        matchStartingServer: Player,
        bestOf: Int = 5,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.matchStartingServer = matchStartingServer.rawValue
        self.bestOf = bestOf
        self.savedAt = savedAt
    }

    // MARK: - Computed Properties

    var startingServer: Player {
        Player(rawValue: matchStartingServer) ?? .player1
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

    // MARK: - Factory Method

    /// Create a SavedMatch from a live Match
    static func from(_ match: Match, context: ModelContext) -> SavedMatch {
        let savedMatch = SavedMatch(
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            matchStartingServer: match.matchStartingServer,
            bestOf: match.bestOf
        )

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
