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
    public let duration: TimeInterval  // Duration of the rally in seconds (since the previous point or the Start tap); 0 = not timed
    /// The shot was played out of the air ("Uit de lucht"); see `ShotType.volley` for older points
    public let isVolley: Bool
    /// Unforced errors: how it went wrong (nil = not recorded)
    public let errorKind: ErrorKind?

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
        isVolley: Bool = false,
        errorKind: ErrorKind? = nil
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
        self.errorKind = errorKind
    }

    /// Whether the rally was timed. The first rally of a game has no time when
    /// the coach did not tap Start: the warm-up or the break between games
    /// must not count as a rally.
    public var isTimed: Bool { duration > 0.0 }
}

extension Point {
    /// "Winner · Volley drop · Voor Links": the last-point line under the coach buttons
    public var summary: String {
        var parts = [pointType.title]
        if let errorKind { parts.append(errorKind.title) }
        if let shotType { parts.append(shotType.displayName(isVolley: isVolley)) }
        if let zone { parts.append(zone.rawValue) }
        return parts.joined(separator: " · ")
    }
}
