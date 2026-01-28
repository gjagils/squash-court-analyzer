import Foundation
import SwiftData

/// Persisted point model for SwiftData
@Model
final class SavedPoint {
    var id: UUID
    var pointNumber: Int
    var scorer: String  // Player rawValue
    var zone: String  // CourtZone rawValue
    var shotType: String  // ShotType rawValue
    var server: String  // Player rawValue
    var player1Score: Int
    var player2Score: Int
    var timestamp: Date

    var game: SavedGame?

    init(
        id: UUID = UUID(),
        pointNumber: Int,
        scorer: Player,
        zone: CourtZone,
        shotType: ShotType,
        server: Player,
        player1Score: Int,
        player2Score: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.pointNumber = pointNumber
        self.scorer = scorer.rawValue
        self.zone = zone.rawValue
        self.shotType = shotType.rawValue
        self.server = server.rawValue
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    var scorerPlayer: Player {
        Player(rawValue: scorer) ?? .player1
    }

    var pointZone: CourtZone {
        CourtZone(rawValue: zone) ?? .middleMiddle
    }

    var pointShotType: ShotType {
        ShotType(rawValue: shotType) ?? .drive
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
            zone: point.zone,
            shotType: point.shotType,
            server: point.server,
            player1Score: point.player1Score,
            player2Score: point.player2Score,
            timestamp: point.timestamp
        )
    }
}
