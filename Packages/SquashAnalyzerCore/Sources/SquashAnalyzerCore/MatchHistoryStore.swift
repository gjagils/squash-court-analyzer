import Foundation

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

    public init(id: String, kind: String, player1Name: String, player2Name: String,
                player1Games: Int, player2Games: Int, status: String, updatedAt: Date) {
        self.id = id
        self.kind = kind
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Games = player1Games
        self.player2Games = player2Games
        self.status = status
        self.updatedAt = updatedAt
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
