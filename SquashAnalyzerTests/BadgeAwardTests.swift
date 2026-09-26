import XCTest
import SwiftData
@testable import SquashAnalyzer

final class BadgeAwardTests: XCTestCase {
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SquashAnalyzerCurrentSchema.self),
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
    }

    @MainActor
    private func makePlayer(_ name: String, in context: ModelContext) -> SavedPlayer {
        let player = SavedPlayer(name: name)
        context.insert(player)
        return player
    }

    private func win(_ count: Int, for player: Player, in match: Match) {
        for _ in 0..<count {
            match.currentGame.addPoint(to: player, pointType: .winner, at: nil, with: nil)
        }
    }

    @MainActor
    private func awards(in context: ModelContext) throws -> [SavedBadgeAward] {
        try context.fetch(FetchDescriptor<SavedBadgeAward>())
    }

    func testAwardIdIsDeterministic() {
        let card = UUID(), match = UUID()
        XCTAssertEqual(SavedBadgeAward.awardId(cardId: card, badge: .fiveInARow, matchId: match),
                       SavedBadgeAward.awardId(cardId: card, badge: .fiveInARow, matchId: match))
        XCTAssertNotEqual(SavedBadgeAward.awardId(cardId: card, badge: .fiveInARow, matchId: match),
                          SavedBadgeAward.awardId(cardId: card, badge: .fiveInARow, matchId: UUID()))
    }

    func testPickedPlayerOnlyCountsWhileTheNameIsUnchanged() {
        let pick = PickedPlayer(id: UUID(), name: "Paul Steenks")
        XCTAssertEqual(pick.id(for: "Paul Steenks "), pick.id)
        XCTAssertNil(pick.id(for: "Paul"))
    }

    @MainActor
    func testPickedPlayerEarnsOneAwardPerMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paul = makePlayer("Paul", in: context)
        let repository = SwiftDataMatchRepository(context: context)
        let match = Match()
        match.setupMatch(player1: "Paul", player2: "Typed", startingServer: .player1, player1Id: paul.id)

        win(4, for: .player1, in: match)
        try repository.upsert(match)
        XCTAssertTrue(try awards(in: context).isEmpty)

        win(1, for: .player1, in: match)
        try repository.upsert(match)
        win(5, for: .player2, in: match)          // typed-in player earns nothing
        win(3, for: .player1, in: match)          // a longer run is still one award
        try repository.upsert(match)

        let stored = try awards(in: context)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.cardId, paul.id)
        XCTAssertEqual(stored.first?.matchId, match.id)
        XCTAssertEqual(stored.first?.opponentName, "Typed")
        XCTAssertEqual(try context.fetch(FetchDescriptor<SavedMatch>()).first?.player1Id, paul.id)
    }

    @MainActor
    func testUndoTakesBackAnAwardButADeletedOneStaysDeleted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paul = makePlayer("Paul", in: context)
        let repository = SwiftDataMatchRepository(context: context)
        let match = Match()
        match.setupMatch(player1: "Paul", player2: "B", startingServer: .player1, player1Id: paul.id)

        win(5, for: .player1, in: match)
        try repository.upsert(match)
        match.currentGame.undoLastPoint()
        try repository.upsert(match)
        XCTAssertTrue(try awards(in: context).isEmpty, "the run was undone")

        win(1, for: .player1, in: match)
        try repository.upsert(match)
        let award = try XCTUnwrap(awards(in: context).first)
        award.deletedAt = Date()
        try context.save()

        win(1, for: .player1, in: match)
        try repository.upsert(match)
        let stored = try awards(in: context)
        XCTAssertEqual(stored.count, 1)
        XCTAssertNotNil(stored.first?.deletedAt, "recomputing does not bring a deleted badge back")
    }

    @MainActor
    func testDiscardingAMatchRemovesItsAwards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paul = makePlayer("Paul", in: context)
        let repository = SwiftDataMatchRepository(context: context)
        let match = Match()
        match.setupMatch(player1: "Paul", player2: "B", startingServer: .player1, player1Id: paul.id)
        win(5, for: .player1, in: match)
        try repository.upsert(match)

        try repository.delete(match)
        XCTAssertTrue(try awards(in: context).isEmpty)
    }

    @MainActor
    func testLinkedCardReceivesTheAward() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paul = makePlayer("Paul", in: context)
        let card = UUID()
        paul.cardId = card
        let referee = RefereeMatch(player1Name: "Paul", player2Name: "B", bestOf: 5, startingServer: .player1)
        referee.player1Id = paul.id
        for _ in 0..<5 { referee.awardPoint(to: .player1) }

        try BadgeAwarder(context: context).syncAwards(matchId: referee.id, playerIds: referee.playerIds,
                                                     playerNames: [.player1: "Paul", .player2: "B"],
                                                     input: referee.badgeInput)
        try context.save()
        XCTAssertEqual(try awards(in: context).map(\.cardId), [card])
    }

    @MainActor
    func testBackupKeepsAwardsDeletionsAndPlayerLinks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paul = makePlayer("Paul", in: context)
        paul.cardId = UUID()
        let repository = SwiftDataMatchRepository(context: context)
        let match = Match()
        match.setupMatch(player1: "Paul", player2: "B", startingServer: .player1, player1Id: paul.id)
        win(5, for: .player1, in: match)
        try repository.upsert(match)
        let deleted = SavedBadgeAward(cardId: paul.badgeCardId, badge: .fiveInARow, matchId: UUID(),
                                      earnedAt: Date(), opponentName: "C", awardedBy: "x")
        deleted.deletedAt = Date()
        context.insert(deleted)
        try context.save()

        let data = try ExportService.exportFullBackup(
            players: try context.fetch(FetchDescriptor<SavedPlayer>()),
            matches: try context.fetch(FetchDescriptor<SavedMatch>()),
            standaloneGames: [],
            badgeAwards: try awards(in: context)
        )

        let restored = try makeContainer()
        _ = try ExportService.replaceWithBackup(data, context: restored.mainContext)
        let restoredAwards = try awards(in: restored.mainContext)
        XCTAssertEqual(restoredAwards.count, 2)
        XCTAssertEqual(restoredAwards.filter(\.isActive).count, 1)
        XCTAssertEqual(Set(restoredAwards.map(\.id)), Set(try awards(in: context).map(\.id)))
        XCTAssertEqual(try restored.mainContext.fetch(FetchDescriptor<SavedPlayer>()).first?.cardId, paul.cardId)
        XCTAssertEqual(try restored.mainContext.fetch(FetchDescriptor<SavedMatch>()).first?.player1Id, paul.id)
    }
}
