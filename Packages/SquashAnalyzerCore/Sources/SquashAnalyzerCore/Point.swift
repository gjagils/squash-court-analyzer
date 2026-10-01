import Foundation

/// Represents a single point scored in a game
public struct Point: Identifiable {
    public let id: UUID
    public let scorer: Player          // Who scored the point
    public let pointType: PointType    // How the point was won
    public let zone: CourtZone?        // Where the point was won (nil for unforced errors)
    public let shotType: ShotType?     // Type of winning shot (nil for unforced errors)
    public let server: Player          // Who was serving
    public let player1Score: Int       // Score after this point
    public let player2Score: Int       // Score after this point
    public let timestamp: Date         // When the point was scored
    public let duration: TimeInterval  // Duration of the rally in seconds (time since previous point or game start)
    /// The shot was played out of the air ("Uit de lucht"); see `ShotType.volley` for older points
    public let isVolley: Bool

    public init(
        id: UUID = UUID(),
        scorer: Player,
        pointType: PointType = .winner,
        zone: CourtZone? = nil,
        shotType: ShotType? = nil,
        server: Player,
        player1Score: Int,
        player2Score: Int,
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        isVolley: Bool = false
    ) {
        self.id = id
        self.scorer = scorer
        self.pointType = pointType
        self.zone = zone
        self.shotType = shotType
        self.server = server
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = timestamp
        self.duration = duration
        self.isVolley = isVolley
    }
}
