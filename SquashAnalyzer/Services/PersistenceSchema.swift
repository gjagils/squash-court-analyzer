import Foundation
import SwiftData

// MARK: - Version 0 (App Store 2.0, build 8, March 2026 — unversioned store)

/// The models as shipped in the App Store release. Stores created by 2.0 carry no
/// version identifier; SwiftData matches them to this schema by model shape, so it
/// must stay byte-for-byte equivalent to what 2.0 wrote. Never edit.
enum SquashAnalyzerSchemaV0: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 0)

    static var models: [any PersistentModel.Type] {
        [SavedMatch.self, SavedGame.self, SavedPoint.self, SavedLet.self, SavedPlayer.self, SavedRefereeMatch.self]
    }

    @Model
    final class SavedMatch {
        var id: UUID
        var player1Name: String
        var player2Name: String
        var matchStartingServer: String
        var bestOf: Int
        var savedAt: Date
        @Relationship(deleteRule: .cascade, inverse: \SavedGame.match)
        var games: [SavedGame] = []

        init(id: UUID, player1Name: String, player2Name: String, matchStartingServer: String, bestOf: Int, savedAt: Date) {
            self.id = id
            self.player1Name = player1Name
            self.player2Name = player2Name
            self.matchStartingServer = matchStartingServer
            self.bestOf = bestOf
            self.savedAt = savedAt
        }
    }

    @Model
    final class SavedGame {
        var id: UUID
        var gameNumber: Int
        var player1Name: String
        var player2Name: String
        var player1Score: Int
        var player2Score: Int
        var startingServer: String
        var winner: String?
        var match: SavedMatch?
        var savedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \SavedPoint.game)
        var points: [SavedPoint] = []
        @Relationship(deleteRule: .cascade, inverse: \SavedLet.game)
        var lets: [SavedLet] = []

        init(id: UUID, gameNumber: Int, player1Name: String, player2Name: String, player1Score: Int, player2Score: Int, startingServer: String, winner: String?) {
            self.id = id
            self.gameNumber = gameNumber
            self.player1Name = player1Name
            self.player2Name = player2Name
            self.player1Score = player1Score
            self.player2Score = player2Score
            self.startingServer = startingServer
            self.winner = winner
        }
    }

    @Model
    final class SavedPoint {
        var id: UUID
        var pointNumber: Int
        var scorer: String
        var pointType: String
        var zone: String
        var shotType: String
        var server: String
        var player1Score: Int
        var player2Score: Int
        var timestamp: Date
        var duration: Double
        var game: SavedGame?

        init(id: UUID, pointNumber: Int, scorer: String, pointType: String, zone: String, shotType: String, server: String, player1Score: Int, player2Score: Int, timestamp: Date, duration: Double) {
            self.id = id
            self.pointNumber = pointNumber
            self.scorer = scorer
            self.pointType = pointType
            self.zone = zone
            self.shotType = shotType
            self.server = server
            self.player1Score = player1Score
            self.player2Score = player2Score
            self.timestamp = timestamp
            self.duration = duration
        }
    }

    @Model
    final class SavedLet {
        var id: UUID
        var letNumber: Int
        var requestedBy: String
        var server: String
        var player1Score: Int
        var player2Score: Int
        var timestamp: Date
        var game: SavedGame?

        init(id: UUID, letNumber: Int, requestedBy: String, server: String, player1Score: Int, player2Score: Int, timestamp: Date) {
            self.id = id
            self.letNumber = letNumber
            self.requestedBy = requestedBy
            self.server = server
            self.player1Score = player1Score
            self.player2Score = player2Score
            self.timestamp = timestamp
        }
    }

    @Model
    final class SavedPlayer {
        var id: UUID
        var name: String
        var coachingFocusAreas: [String]
        var coachingNotes: String
        var createdAt: Date

        init(id: UUID, name: String, coachingFocusAreas: [String], coachingNotes: String, createdAt: Date) {
            self.id = id
            self.name = name
            self.coachingFocusAreas = coachingFocusAreas
            self.coachingNotes = coachingNotes
            self.createdAt = createdAt
        }
    }

    @Model
    final class SavedRefereeMatch {
        var player1Name: String
        var player2Name: String
        var bestOf: Int
        var gameResults: [RefereeGameResult]
        var savedAt: Date

        init(player1Name: String, player2Name: String, bestOf: Int, gameResults: [RefereeGameResult], savedAt: Date) {
            self.player1Name = player1Name
            self.player2Name = player2Name
            self.bestOf = bestOf
            self.gameResults = gameResults
            self.savedAt = savedAt
        }
    }
}

// MARK: - Version 1 (TestFlight 2.2 build 5): SavedMatch gains updatedAt, status, coaching fields

/// Frozen copy of the models as they were when version 1 shipped. Never edit these;
/// add a new VersionedSchema and a MigrationStage instead.
enum SquashAnalyzerSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SavedMatch.self, SavedGame.self, SavedPoint.self, SavedLet.self, SavedPlayer.self, SavedRefereeMatch.self]
    }

    @Model
    final class SavedMatch {
        var id: UUID
        var player1Name: String
        var player2Name: String
        var matchStartingServer: String
        var bestOf: Int
        var savedAt: Date
        var updatedAt: Date = Date()
        var status: String = MatchStatus.completed.rawValue
        var player1CoachingFocus: [String] = []
        var player2CoachingFocus: [String] = []
        var player1CoachingNotes: String = ""
        var player2CoachingNotes: String = ""
        @Relationship(deleteRule: .cascade, inverse: \SavedGame.match)
        var games: [SavedGame] = []

        init(id: UUID, player1Name: String, player2Name: String, matchStartingServer: String, bestOf: Int, savedAt: Date) {
            self.id = id
            self.player1Name = player1Name
            self.player2Name = player2Name
            self.matchStartingServer = matchStartingServer
            self.bestOf = bestOf
            self.savedAt = savedAt
        }
    }

    @Model
    final class SavedGame {
        var id: UUID
        var gameNumber: Int
        var player1Name: String
        var player2Name: String
        var player1Score: Int
        var player2Score: Int
        var startingServer: String
        var winner: String?
        var match: SavedMatch?
        var savedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \SavedPoint.game)
        var points: [SavedPoint] = []
        @Relationship(deleteRule: .cascade, inverse: \SavedLet.game)
        var lets: [SavedLet] = []

        init(id: UUID, gameNumber: Int, player1Name: String, player2Name: String, player1Score: Int, player2Score: Int, startingServer: String, winner: String?) {
            self.id = id
            self.gameNumber = gameNumber
            self.player1Name = player1Name
            self.player2Name = player2Name
            self.player1Score = player1Score
            self.player2Score = player2Score
            self.startingServer = startingServer
            self.winner = winner
        }
    }

    @Model
    final class SavedPoint {
        var id: UUID
        var pointNumber: Int
        var scorer: String
        var pointType: String
        var zone: String
        var shotType: String
        var server: String
        var player1Score: Int
        var player2Score: Int
        var timestamp: Date
        var duration: Double
        var game: SavedGame?

        init(id: UUID, pointNumber: Int, scorer: String, pointType: String, zone: String, shotType: String, server: String, player1Score: Int, player2Score: Int, timestamp: Date, duration: Double) {
            self.id = id
            self.pointNumber = pointNumber
            self.scorer = scorer
            self.pointType = pointType
            self.zone = zone
            self.shotType = shotType
            self.server = server
            self.player1Score = player1Score
            self.player2Score = player2Score
            self.timestamp = timestamp
            self.duration = duration
        }
    }

    @Model
    final class SavedLet {
        var id: UUID
        var letNumber: Int
        var requestedBy: String
        var server: String
        var player1Score: Int
        var player2Score: Int
        var timestamp: Date
        var game: SavedGame?

        init(id: UUID, letNumber: Int, requestedBy: String, server: String, player1Score: Int, player2Score: Int, timestamp: Date) {
            self.id = id
            self.letNumber = letNumber
            self.requestedBy = requestedBy
            self.server = server
            self.player1Score = player1Score
            self.player2Score = player2Score
            self.timestamp = timestamp
        }
    }

    @Model
    final class SavedPlayer {
        var id: UUID
        var name: String
        var coachingFocusAreas: [String]
        var coachingNotes: String
        var createdAt: Date

        init(id: UUID, name: String, coachingFocusAreas: [String], coachingNotes: String, createdAt: Date) {
            self.id = id
            self.name = name
            self.coachingFocusAreas = coachingFocusAreas
            self.coachingNotes = coachingNotes
            self.createdAt = createdAt
        }
    }

    @Model
    final class SavedRefereeMatch {
        var player1Name: String
        var player2Name: String
        var bestOf: Int
        var gameResults: [RefereeGameResult]
        var savedAt: Date

        init(player1Name: String, player2Name: String, bestOf: Int, gameResults: [RefereeGameResult], savedAt: Date) {
            self.player1Name = player1Name
            self.player2Name = player2Name
            self.bestOf = bestOf
            self.gameResults = gameResults
            self.savedAt = savedAt
        }
    }
}

// MARK: - Version 2 (current): SavedPlayer.photoData

/// The live model classes. Adding the optional `photoData` attribute is a
/// lightweight migration from version 1.
enum SquashAnalyzerSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SavedMatch.self, SavedGame.self, SavedPoint.self, SavedLet.self, SavedPlayer.self, SavedRefereeMatch.self]
    }
}

/// Alias for the schema the app runs on; bump when a new version is added.
typealias SquashAnalyzerCurrentSchema = SquashAnalyzerSchemaV2

enum SquashAnalyzerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SquashAnalyzerSchemaV0.self, SquashAnalyzerSchemaV1.self, SquashAnalyzerSchemaV2.self]
    }

    static var stages: [MigrationStage] { [v0ToV1, v1ToV2] }

    /// New SavedMatch attributes all have defaults, so this is a lightweight migration.
    static let v0ToV1 = MigrationStage.lightweight(
        fromVersion: SquashAnalyzerSchemaV0.self,
        toVersion: SquashAnalyzerSchemaV1.self
    )

    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: SquashAnalyzerSchemaV1.self,
        toVersion: SquashAnalyzerSchemaV2.self
    )
}

enum PersistenceRecovery {
    /// Copies the existing store files to a dated recovery folder. Originals are
    /// deliberately never deleted, even when opening or migration fails.
    static func preserveStoreFiles() -> URL? {
        let manager = FileManager.default
        guard let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let files = try? manager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) else {
            return nil
        }

        let storeFiles = files.filter {
            $0.pathExtension == "store" ||
            $0.lastPathComponent.hasSuffix(".store-shm") ||
            $0.lastPathComponent.hasSuffix(".store-wal")
        }
        guard !storeFiles.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let recoveryDirectory = appSupport
            .appendingPathComponent("Recovery", isDirectory: true)
            .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)

        do {
            try manager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
            for source in storeFiles {
                try manager.copyItem(at: source, to: recoveryDirectory.appendingPathComponent(source.lastPathComponent))
            }
            return recoveryDirectory
        } catch {
            return nil
        }
    }
}
