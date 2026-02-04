import Foundation

/// Represents a let (replay of rally) in squash
struct Let: Identifiable {
    let id = UUID()
    let requestedBy: Player     // Who requested the let
    let server: Player          // Who was serving when let was called
    let timestamp: Date         // When the let was called
    let player1Score: Int       // Score at time of let
    let player2Score: Int       // Score at time of let

    init(requestedBy: Player, server: Player, player1Score: Int, player2Score: Int) {
        self.requestedBy = requestedBy
        self.server = server
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = Date()
    }
}
