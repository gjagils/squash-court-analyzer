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
        XCTAssertEqual(migrated.player1GamesBefore, 0, "V3 head start defaults to a full match")
        XCTAssertEqual(migrated.player2GamesBefore, 0)
        XCTAssertEqual(migrated.player1GamesAfter, 0, "V4 filled-in result defaults to none")
        XCTAssertEqual(migrated.player2GamesAfter, 0)

        let players = try context.fetch(FetchDescriptor<SavedPlayer>())
        XCTAssertEqual(players.map(\.name), ["Niels"])
        XCTAssertNil(players.first?.photoData)

        let refereeMatches = try context.fetch(FetchDescriptor<SavedRefereeMatch>())
        XCTAssertEqual(refereeMatches.count, 1)
        XCTAssertEqual(refereeMatches.first?.player2GamesBefore, 0)
        XCTAssertEqual(refereeMatches.first?.player1GamesWon, 1)

        // 3. The migrated store keeps working for new-schema features.
        players.first?.photoData = Data([0xFF, 0xD8])
        try context.save()
    }

    /// TestFlight builds 11–12 wrote version 4; opening it must keep the data and
    /// leave the new badge fields empty.
    @MainActor
    func testStoreFromVersion4MigratesToBadges() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("v4-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        let matchId = UUID()

        do {
            typealias V4 = SquashAnalyzerSchemaV4
            let container = try ModelContainer(
                for: Schema(versionedSchema: V4.self),
                configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)]
            )
            let context = container.mainContext
            let match = V4.SavedMatch(id: matchId, player1Name: "Paul", player2Name: "Kristian", matchStartingServer: "Speler 1", bestOf: 5, savedAt: Date())
            match.player1GamesAfter = 2
            context.insert(match)
            context.insert(V4.SavedPlayer(id: UUID(), name: "Paul", coachingFocusAreas: [], coachingNotes: "", createdAt: Date()))
            context.insert(V4.SavedRefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, gameResults: [], savedAt: Date()))
            try context.save()
        }

        let container = try ModelContainer(
            for: Schema(versionedSchema: SquashAnalyzerCurrentSchema.self),
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)]
        )
        let context = container.mainContext

        let match = try XCTUnwrap(context.fetch(FetchDescriptor<SavedMatch>()).first)
        XCTAssertEqual(match.id, matchId)
        XCTAssertEqual(match.player1GamesAfter, 2)
        XCTAssertNil(match.player1Id)
        XCTAssertNil(match.player2Id)

        let player = try XCTUnwrap(context.fetch(FetchDescriptor<SavedPlayer>()).first)
        XCTAssertNil(player.cardId)
        XCTAssertEqual(player.badgeCardId, player.id)

        let referee = try XCTUnwrap(context.fetch(FetchDescriptor<SavedRefereeMatch>()).first)
        XCTAssertNil(referee.matchId)

        context.insert(SavedBadgeAward(cardId: player.id, badge: .fiveInARow, matchId: matchId,
                                       earnedAt: Date(), opponentName: "Kristian", awardedBy: "test"))
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<SavedBadgeAward>()).count, 1)
    }
}
