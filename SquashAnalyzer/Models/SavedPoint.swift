import Foundation
import SwiftData

/// Persisted point model for SwiftData
@Model
final class SavedPoint {
    var id: UUID
    var pointNumber: Int
    var scorer: String      // Player rawValue
    var pointType: String   // PointType rawValue (default "Winner" for old data)
    var zone: String        // CourtZone rawValue (empty string for unforced errors)
    var shotType: String    // ShotType rawValue (empty string for unforced errors)
    var server: String      // Player rawValue
    var player1Score: Int
    var player2Score: Int
    var timestamp: Date
    var duration: Double    // Rally duration in seconds

    var game: SavedGame?

    init(
        id: UUID = UUID(),
        pointNumber: Int,
        scorer: Player,
        pointType: PointType,
        zone: CourtZone?,
        shotType: ShotType?,
        server: Player,
        player1Score: Int,
        player2Score: Int,
        timestamp: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.pointNumber = pointNumber
        self.scorer = scorer.rawValue
        self.pointType = pointType.rawValue
        self.zone = zone?.rawValue ?? ""
        self.shotType = shotType?.rawValue ?? ""
        self.server = server.rawValue
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = timestamp
        self.duration = duration
    }

    // MARK: - Computed Properties

    var scorerPlayer: Player {
        Player(rawValue: scorer) ?? .player1
    }

    var savedPointType: PointType {
        PointType(rawValue: pointType) ?? .winner
    }

    var pointZone: CourtZone? {
        zone.isEmpty ? nil : CourtZone(rawValue: zone)
    }

    var pointShotType: ShotType? {
        shotType.isEmpty ? nil : ShotType(rawValue: shotType)
    }

    var serverPlayer: Player {
        Player(rawValue: server) ?? .player1
    }

    // MARK: - Factory Method

    /// Create a SavedPoint from a live Point
    static func from(_ point: Point, pointNumber: Int) -> SavedPoint {
        SavedPoint(
            pointNumber: pointNumber,
            scorer: point.scorer,
            pointType: point.pointType,
            zone: point.zone,
            shotType: point.shotType,
            server: point.server,
            player1Score: point.player1Score,
            player2Score: point.player2Score,
            timestamp: point.timestamp,
            duration: point.duration
        )
    }
}
