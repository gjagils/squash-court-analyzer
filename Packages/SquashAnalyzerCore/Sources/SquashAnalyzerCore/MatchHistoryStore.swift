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

/// Read-only history across both coach and referee matches, merged and sorted.
public protocol MatchHistoryStore: Sendable {
    func loadHistory() async throws -> [MatchHistorySummary]
}
