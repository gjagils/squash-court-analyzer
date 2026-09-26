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
    /// Games already won when scoring started at game 2 or later (0 for a full match)
    var player1GamesBefore: Int = 0
    var player2GamesBefore: Int = 0
    /// Identifies the match for its badge awards (nil for matches saved before badges)
    var matchId: UUID? = nil
    /// `SavedPlayer.id` of a player picked from "Kies speler" (nil for a typed-in name)
    var player1Id: UUID? = nil
    var player2Id: UUID? = nil

    init(
        player1Name: String,
        player2Name: String,
        bestOf: Int,
        gameResults: [RefereeGameResult],
        savedAt: Date = Date(),
        player1GamesBefore: Int = 0,
        player2GamesBefore: Int = 0
    ) {
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.bestOf = bestOf
        self.gameResults = gameResults
        self.savedAt = savedAt
        self.player1GamesBefore = player1GamesBefore
        self.player2GamesBefore = player2GamesBefore
    }

    var player1GamesWon: Int { player1GamesBefore + gameResults.filter { $0.winnerRaw == Player.player1.rawValue }.count }
    var player2GamesWon: Int { player2GamesBefore + gameResults.filter { $0.winnerRaw == Player.player2.rawValue }.count }
    var gamesToWin: Int { (bestOf / 2) + 1 }

    var winnerName: String? {
        if player1GamesWon >= gamesToWin { return player1Name }
        if player2GamesWon >= gamesToWin { return player2Name }
        return nil
    }

    /// "11-3, 11-8", with a dash per game played before scoring started
    var gameScoresText: String {
        let untracked = Array(repeating: "–", count: player1GamesBefore + player2GamesBefore)
        let scored = gameResults.sorted { $0.number < $1.number }
            .map { "\($0.player1Score)-\($0.player2Score)" }
        return (untracked + scored).joined(separator: ", ")
    }

    var matchScoreText: String { "\(player1GamesWon)-\(player2GamesWon)" }
}
