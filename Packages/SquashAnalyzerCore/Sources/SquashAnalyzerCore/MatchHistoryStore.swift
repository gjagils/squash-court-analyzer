import Foundation

/// One finished game on a history card ("11-6" in the winner's colour)
public struct HistoryGameScore: Equatable, Sendable {
    public let player1Score: Int
    public let player2Score: Int
    /// Player raw value of the winner
    public let winner: String

    public init(player1Score: Int, player2Score: Int, winner: String) {
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
    }
}

/// One row in the "Afgeronde wedstrijden" list: enough to render a summary,
/// not the full point-by-point record. `kind` is "coach" or "referee".
public struct MatchHistorySummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let player1Name: String
    public let player2Name: String
    public let player1Games: Int
    public let player2Games: Int
    public let status: String
    public let updatedAt: Date
    /// Tracked games in order; games before scoring started and games filled
    /// in later show as "–"
    public let games: [HistoryGameScore]
    public let untrackedBefore: Int
    public let untrackedAfter: Int
    public let bestOf: Int
    /// A picked player earned a badge in this match (medal on the card)
    public let hasBadges: Bool

    public init(id: String, kind: String, player1Name: String, player2Name: String,
                player1Games: Int, player2Games: Int, status: String, updatedAt: Date,
                games: [HistoryGameScore] = [], untrackedBefore: Int = 0, untrackedAfter: Int = 0,
                bestOf: Int = 5, hasBadges: Bool = false) {
        self.id = id
        self.kind = kind
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Games = player1Games
        self.player2Games = player2Games
        self.status = status
        self.updatedAt = updatedAt
        self.games = games
        self.untrackedBefore = untrackedBefore
        self.untrackedAfter = untrackedAfter
        self.bestOf = bestOf
        self.hasBadges = hasBadges
    }

    /// The match winner, when one side reached the games needed
    public var winner: Player? {
        MatchStand(bestOf: bestOf, player1Games: player1Games, player2Games: player2Games).winner
    }

    public var winnerName: String? {
        guard let winner else { return nil }
        return winner == Player.player1 ? player1Name : player2Name
    }

    /// "–, 11-6, 8-11, –": games before scoring, tracked games, filled-in games
    public var gameScoresText: String {
        var parts: [String] = []
        for _ in 0..<untrackedBefore { parts.append("–") }
        for game in games { parts.append("\(game.player1Score)-\(game.player2Score)") }
        for _ in 0..<untrackedAfter { parts.append("–") }
        return parts.joined(separator: ", ")
    }
}

/// History across coach and referee matches, merged and sorted, newest first.
/// A row can be opened (analysis, sharing), deleted, and an incomplete coach
/// match can be finished with "Uitslag aanvullen".
@MainActor
public protocol MatchHistoryStore {
    func loadHistory() async throws -> [MatchHistorySummary]
    func coachMatch(id: String) async throws -> Match?
    func refereeMatch(id: String) async throws -> RefereeMatch?
    /// Saves a coach match again, e.g. after its result was completed
    func saveCoachMatch(_ match: Match) async throws
    /// Removes the match; its badges are marked deleted, as on iOS
    func delete(_ entry: MatchHistorySummary) async throws
}
