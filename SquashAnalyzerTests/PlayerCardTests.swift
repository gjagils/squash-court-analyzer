import XCTest
import SwiftData
@testable import SquashAnalyzer

final class PlayerCardTests: XCTestCase {
    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SquashAnalyzerCurrentSchema.self),
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        return ModelContext(container)
    }

    private func value(card: UUID, match: UUID = UUID(), deleted: Date? = nil) -> AwardValue {
        AwardValue(cardId: card, badge: .fiveInARow, matchId: match, earnedAt: Date(timeIntervalSince1970: 1_790_000_000),
                   opponentName: "Kristian", awardedBy: "coach-a", deletedAt: deleted)
    }

    func testSnapshotLinkRoundTrip() throws {
        let card = UUID()
        let snapshot = CardSnapshot(cardId: card, name: "Paul Steenks",
                                    awards: [value(card: card), value(card: card, deleted: Date(timeIntervalSince1970: 1_790_000_100))])
        let url = try snapshot.webURL()
        XCTAssertTrue(url.absoluteString.hasPrefix("https://squashanalyzer.com/kaart/#"))
        XCTAssertLessThan(url.absoluteString.count, 1000)

        let decoded = try XCTUnwrap(CardSnapshot(url: url))
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.awards.count, 2)
        XCTAssertEqual(decoded.awards.map(\.id), snapshot.awards.map(\.id))

        let appURL = URL(string: CardSnapshot.appBase + (try snapshot.payload()))!
        XCTAssertEqual(CardSnapshot(url: appURL), snapshot)
        XCTAssertNil(CardSnapshot(url: URL(string: "https://squashanalyzer.com/privacy.html#abc")!))
    }

    @MainActor
    func testMergeAddsNewBadgesAndDeletionWins() throws {
        let context = try makeContext()
        let store = CardStore(context: context)
        let card = UUID(), match = UUID()
        try store.merge([value(card: card, match: match)])
        XCTAssertEqual(try store.preview([value(card: card, match: match)]).new, 0, "known award")

        let deletion = value(card: card, match: match, deleted: Date())
        XCTAssertEqual(try store.preview([deletion]).deleted, 1)
        try store.merge([deletion])
        try store.merge([value(card: card, match: match)])   // an old link does not undo the deletion
        XCTAssertNotNil(try store.awards(onCard: card).first?.deletedAt)
    }

    @MainActor
    func testLinkingMovesThePlayersOwnBadgesOntoTheCard() throws {
        let context = try makeContext()
        let store = CardStore(context: context)
        let paul = SavedPlayer(name: "Paul")
        context.insert(paul)
        let ownMatch = UUID()
        try store.merge([value(card: paul.id, match: ownMatch)])

        let sharedCard = UUID()
        let linked = try store.link(cardId: sharedCard, name: "Paul Steenks", to: paul)
        try store.merge([value(card: sharedCard)])

        XCTAssertEqual(linked.id, paul.id)
        XCTAssertEqual(paul.badgeCardId, sharedCard)
        XCTAssertTrue(try store.awards(onCard: paul.id).isEmpty)
        let onCard = try store.awards(onCard: sharedCard)
        XCTAssertEqual(onCard.count, 2)
        XCTAssertTrue(onCard.contains { $0.matchId == ownMatch })
        XCTAssertEqual(try store.player(forCard: sharedCard)?.id, paul.id)
    }

    @MainActor
    func testLinkingToANewPlayerCreatesIt() throws {
        let context = try makeContext()
        let store = CardStore(context: context)
        let card = UUID()
        let player = try store.link(cardId: card, name: "Kristian Koster", to: nil)
        XCTAssertEqual(player.name, "Kristian Koster")
        XCTAssertEqual(player.badgeCardId, card)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SavedPlayer>()).count, 1)
    }

    @MainActor
    func testSnapshotOfAPlayerContainsDeletedAwards() throws {
        let context = try makeContext()
        let store = CardStore(context: context)
        let paul = SavedPlayer(name: "Paul")
        context.insert(paul)
        try store.merge([value(card: paul.id), value(card: paul.id, deleted: Date())])
        let snapshot = try store.snapshot(for: paul)
        XCTAssertEqual(snapshot.cardId, paul.id)
        XCTAssertEqual(snapshot.awards.count, 2)
        XCTAssertEqual(snapshot.awards.filter { $0.deletedAt != nil }.count, 1)
    }
}
