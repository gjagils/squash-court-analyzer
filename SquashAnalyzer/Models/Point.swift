import Foundation

/// Represents a single point scored in a game
struct Point: Identifiable {
    let id = UUID()
    let scorer: Player          // Who scored the point
    let pointType: PointType    // How the point was won
    let zone: CourtZone?        // Where the point was won (nil for unforced errors)
    let shotType: ShotType?     // Type of winning shot (nil for unforced errors)
    let server: Player          // Who was serving
    let player1Score: Int       // Score after this point
    let player2Score: Int       // Score after this point
    let timestamp: Date         // When the point was scored
    let duration: TimeInterval  // Duration of the rally in seconds (time since previous point or game start)

    init(
        scorer: Player,
        pointType: PointType = .winner,
        zone: CourtZone? = nil,
        shotType: ShotType? = nil,
        server: Player,
        player1Score: Int,
        player2Score: Int,
        duration: TimeInterval = 0
    ) {
        self.scorer = scorer
        self.pointType = pointType
        self.zone = zone
        self.shotType = shotType
        self.server = server
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = Date()
        self.duration = duration
    }
}
