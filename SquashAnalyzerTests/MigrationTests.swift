import XCTest
import SwiftData
@testable import SquashAnalyzer

/// Guards the upgrade path from the App Store release: a store written by 2.0
/// (plain Schema, models as frozen in SquashAnalyzerSchemaV0) must open with the
/// current schema and migration plan without losing data.
final class MigrationTests: XCTestCase {
    @MainActor
    func testStoreFromAppStore20MigratesToCurrentSchema() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("v0-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }

        // 1. Write data exactly the way 2.0 did: unversioned Schema([...]) with the V0 models.
        do {
            typealias V0 = SquashAnalyzerSchemaV0
            let schema = Schema([V0.SavedMatch.self, V0.SavedGame.self, V0.SavedPoint.self, V0.SavedLet.self, V0.SavedPlayer.self, V0.SavedRefereeMatch.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)])
            let context = container.mainContext

            let match = V0.SavedMatch(id: UUID(), player1Name: "Niels", player2Name: "Paul", matchStartingServer: "player1", bestOf: 5, savedAt: Date())
            context.insert(match)
            let game = V0.SavedGame(id: UUID(), gameNumber: 1, player1Name: "Niels", player2Name: "Paul", player1Score: 11, player2Score: 7, startingServer: "player1", winner: "player1")
            game.match = match
            match.games.append(game)
            let point = V0.SavedPoint(id: UUID(), pointNumber: 1, scorer: "player1", pointType: "Winner", zone: "frontLeft", shotType: "drop", server: "player1", player1Score: 1, player2Score: 0, timestamp: Date(), duration: 4)
            point.game = game
            game.points.append(point)
            let letCall = V0.SavedLet(id: UUID(), letNumber: 1, requestedBy: "player2", server: "player1", player1Score: 1, player2Score: 0, timestamp: Date())
            letCall.game = game
            game.lets.append(letCall)
            context.insert(V0.SavedPlayer(id: UUID(), name: "Niels", coachingFocusAreas: ["Backhand"], coachingNotes: "", createdAt: Date()))
            context.insert(V0.SavedRefereeMatch(player1Name: "A", player2Name: "B", bestOf: 3,
                                                 gameResults: [RefereeGameResult(number: 1, player1Score: 11, player2Score: 3, winner: .player1)], savedAt: Date()))
            try context.save()
        }

        // 2. Open it the way the app does today.
        let container = try ModelContainer(
            for: Schema(versionedSchema: SquashAnalyzerCurrentSchema.self),
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)]
        )
        let context = container.mainContext

        let matches = try context.fetch(FetchDescriptor<SavedMatch>())
        XCTAssertEqual(matches.count, 1)
        let migrated = try XCTUnwrap(matches.first)
        XCTAssertEqual(migrated.player1Name, "Niels")
        XCTAssertEqual(migrated.matchStatus, .completed, "2.0 matches were only saved when finished")
        XCTAssertEqual(migrated.games.count, 1)
        XCTAssertEqual(migrated.games.first?.points.count, 1)
        XCTAssertEqual(migrated.games.first?.lets.count, 1)

        let players = try context.fetch(FetchDescriptor<SavedPlayer>())
        XCTAssertEqual(players.map(\.name), ["Niels"])
        XCTAssertNil(players.first?.photoData)

        XCTAssertEqual(try context.fetch(FetchDescriptor<SavedRefereeMatch>()).count, 1)

        // 3. The migrated store keeps working for new-schema features.
        players.first?.photoData = Data([0xFF, 0xD8])
        try context.save()
    }
}
