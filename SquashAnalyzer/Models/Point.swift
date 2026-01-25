import Foundation

/// Represents a single point scored in a game
struct Point: Identifiable {
    let id = UUID()
    let scorer: Player          // Who scored the point
    let zone: CourtZone         // Where the point was won
    let server: Player          // Who was serving
    let player1Score: Int       // Score after this point
    let player2Score: Int       // Score after this point
    let timestamp: Date         // When the point was scored

    init(scorer: Player, zone: CourtZone, server: Player, player1Score: Int, player2Score: Int) {
        self.scorer = scorer
        self.zone = zone
        self.server = server
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = Date()
    }
}
