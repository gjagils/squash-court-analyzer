import XCTest
import SwiftData
@testable import SquashAnalyzer

final class ScoringAndPersistenceTests: XCTestCase {
    func testGameEndsAtElevenWithTwoPointLead() {
        let engine = ScoringEngine()
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 11, player2: 9)))
        XCTAssertFalse(engine.isGameOver(SquashScore(player1: 11, player2: 10)))
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 15, player2: 13)))
    }

    func testServiceChangesAndUndoRestoresIt() {
        let game = Game()
        game.setStartingServer(.player1)
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, .player2)
        XCTAssertEqual(game.player2Score, 1)

        game.undoLastPoint()
        XCTAssertEqual(game.currentServer, .player1)
        XCTAssertEqual(game.player2Score, 0)
    }

    func testEmptyStatisticsHaveNoInventedBestResult() {
        let game = Game()
        XCTAssertNil(game.bestZone(for: .player1))
        XCTAssertNil(game.bestShotType(for: .player1))
        XCTAssertNil(game.worstZone(for: .player1))
    }

    func testUnforcedErrorScoresImmediately() {
        let game = Game()
        game.selectPlayer(.player1)
        game.selectPointType(.unforcedError)
        XCTAssertEqual(game.player1Score, 1)
        XCTAssertEqual(game.points.last?.pointType, .unforcedError)
        XCTAssertNil(game.points.last?.zone)
    }

    @MainActor
    func testRepositoryUpsertsOneMatchAndRestoresIt() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [config]
        )
        let repository = SwiftDataMatchRepository(context: container.mainContext)
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        match.currentGame.addPoint(to: .player1, pointType: .winner, at: .frontLeft, with: .drive)

        try repository.upsert(match)
        match.currentGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        try repository.upsert(match)

        let saved = try container.mainContext.fetch(FetchDescriptor<SavedMatch>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.games.count, 1)
        XCTAssertEqual(saved.first?.games.first?.points.count, 2)
        XCTAssertEqual(try repository.mostRecentInProgressMatch()?.id, match.id)
    }

    @MainActor
    func testBackupRejectsInvalidChecksumBeforeImport() throws {
        let data = try ExportService.exportFullBackup(players: [], matches: [], standaloneGames: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        let tampered = BackupEnvelope(
            formatVersion: envelope.formatVersion,
            schemaVersion: envelope.schemaVersion,
            appVersion: envelope.appVersion,
            createdAt: envelope.createdAt,
            checksum: "incorrect",
            payload: envelope.payload
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let tamperedData = try encoder.encode(tampered)

        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [config])
        XCTAssertThrowsError(try ExportService.importFullBackup(tamperedData, context: container.mainContext))
    }
}
