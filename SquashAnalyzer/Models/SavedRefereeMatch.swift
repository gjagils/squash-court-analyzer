import Foundation
import SwiftData

/// One game result inside a saved referee match
struct RefereeGameResult: Codable {
    let number: Int
    let player1Score: Int
    let player2Score: Int
    let winnerRaw: String   // Player.rawValue

    init(number: Int, player1Score: Int, player2Score: Int, winner: Player) {
        self.number = number
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winnerRaw = winner.rawValue
    }
}

/// Persisted referee match (score-only, no tactical data)
@Model
final class SavedRefereeMatch {
    var player1Name: String
    var player2Name: String
    var bestOf: Int
    var gameResults: [RefereeGameResult]
    var savedAt: Date

    init(
        player1Name: String,
        player2Name: String,
        bestOf: Int,
        gameResults: [RefereeGameResult],
        savedAt: Date = Date()
    ) {
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.bestOf = bestOf
        self.gameResults = gameResults
        self.savedAt = savedAt
    }

    var player1GamesWon: Int { gameResults.filter { $0.winnerRaw == Player.player1.rawValue }.count }
    var player2GamesWon: Int { gameResults.filter { $0.winnerRaw == Player.player2.rawValue }.count }
    var gamesToWin: Int { (bestOf / 2) + 1 }

    var winnerName: String? {
        if player1GamesWon >= gamesToWin { return player1Name }
        if player2GamesWon >= gamesToWin { return player2Name }
        return nil
    }

    var gameScoresText: String {
        gameResults.sorted { $0.number < $1.number }
            .map { "\($0.player1Score)-\($0.player2Score)" }
            .joined(separator: ", ")
    }

    var matchScoreText: String { "\(player1GamesWon)-\(player2GamesWon)" }
}
