import XCTest
import SwiftData
@testable import SquashAnalyzer
import SquashAnalyzerCore

/// "Testgegevens opruimen" on iOS: the same matches as Android's `RoomTestDataStore`
final class TestDataCleanupStoreTests: XCTestCase {
    @MainActor
    private final class Teams: TeamMatchStore {
        var matches: [TeamMatch] = []
        func loadAll() async throws -> [TeamMatch] { matches }
        func save(_ match: TeamMatch) async throws { matches.append(match) }
        func delete(id: UUID) async throws { matches.removeAll { $0.id == id } }
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SquashAnalyzerCurrentSchema.self),
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
    }

    @MainActor
    func testCountsAndRemovesOnlyTheChosenGroupsFromBeforeTheStart() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let previousFolder = RefereeInProgressStore.folder
        RefereeInProgressStore.folder = folder
        defer { RefereeInProgressStore.folder = previousFolder }

        let start = Date()
        let old = start.addingTimeInterval(-86_400)
        // Keep the container: a context whose container is gone crashes SwiftData
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(SavedMatch(player1Name: "Gerd-Jan", player2Name: "Whiskey", matchStartingServer: .player1, savedAt: old))
        context.insert(SavedMatch(player1Name: "Gerd-Jan", player2Name: "Paul", matchStartingServer: .player1, savedAt: old, status: .abandoned))
        let kept = SavedMatch(player1Name: "Gerd-Jan", player2Name: "Paul", matchStartingServer: .player1, savedAt: old)
        context.insert(kept)
        context.insert(SavedMatch(player1Name: "Bob", player2Name: "Whiskey", matchStartingServer: .player1, savedAt: start.addingTimeInterval(60),
                                  status: .inProgress))
        context.insert(SavedRefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, gameResults: [], savedAt: old))
        try context.save()
        let teams = Teams()
        teams.matches = [TeamMatch(date: old, home: "Bombardinos", away: "Squash Delft 8", ownSide: .home)]
        let store = SwiftDataTestDataStore(context: context, teamMatches: teams)

        let counts = try await store.counts(before: start)
        XCTAssertEqual(counts, TestDataCounts(samplePlayers: 1, unfinished: 2, competition: 1))

        try await store.remove([.samplePlayers, .unfinished], before: start)
        let left = try context.fetch(FetchDescriptor<SavedMatch>()).map(\.player2Name).sorted()
        XCTAssertEqual(left, ["Paul", "Whiskey"], "the finished match and the one after the start stay")
        XCTAssertTrue(try context.fetch(FetchDescriptor<SavedRefereeMatch>()).isEmpty)
        XCTAssertEqual(teams.matches.count, 1, "competition was not chosen")
    }
}
