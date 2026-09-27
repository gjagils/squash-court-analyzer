import Foundation

/// Represents a let (replay of rally) in squash
public struct LetCall: Identifiable {
    public let id: UUID
    public let requestedBy: Player     // Who requested the let
    public let server: Player          // Who was serving when let was called
    public let timestamp: Date         // When the let was called
    public let player1Score: Int       // Score at time of let
    public let player2Score: Int       // Score at time of let

    public init(id: UUID = UUID(), requestedBy: Player, server: Player, player1Score: Int, player2Score: Int, timestamp: Date = Date()) {
        self.id = id
        self.requestedBy = requestedBy
        self.server = server
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = timestamp
    }
}
