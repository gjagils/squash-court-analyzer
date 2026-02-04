import Foundation
import SwiftData

/// Persisted let model for SwiftData
@Model
final class SavedLet {
    var id: UUID
    var letNumber: Int
    var requestedBy: String  // Player rawValue
    var server: String  // Player rawValue
    var player1Score: Int
    var player2Score: Int
    var timestamp: Date

    var game: SavedGame?

    init(
        id: UUID = UUID(),
        letNumber: Int,
        requestedBy: Player,
        server: Player,
        player1Score: Int,
        player2Score: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.letNumber = letNumber
        self.requestedBy = requestedBy.rawValue
        self.server = server.rawValue
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    var requestedByPlayer: Player {
        Player(rawValue: requestedBy) ?? .player1
    }

    var serverPlayer: Player {
        Player(rawValue: server) ?? .player1
    }

    // MARK: - Factory Method

    /// Create a SavedLet from a live Let
    static func from(_ letCall: Let, letNumber: Int) -> SavedLet {
        SavedLet(
            letNumber: letNumber,
            requestedBy: letCall.requestedBy,
            server: letCall.server,
            player1Score: letCall.player1Score,
            player2Score: letCall.player2Score,
            timestamp: letCall.timestamp
        )
    }
}
