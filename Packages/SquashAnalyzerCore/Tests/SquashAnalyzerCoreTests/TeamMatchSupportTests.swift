import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The coupling between a tracked match and a partij (Competitie), against a
/// real file store: remembered when started, found again when resumed, let
/// go when thrown away, and filled in at the end (also from the match-day question).
final class TeamMatchSupportTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_793_181_600.0)

    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("teamsupport-\(UUID().uuidString)")
    }

    private func team() -> TeamMatch {
        TeamMatch(date: day, home: "All Inn Squash 8", away: "Squash Delft 8", ownSide: .home)
    }

    @MainActor
    func testAStartedMatchIsFoundAgainWhenResumedAndLetGoWhenThrownAway() async throws {
        let directory = folder()
        let store = JSONFileTeamMatchStore(directory: directory)
        let match = team()
        try await store.save(match)
        let target = TeamTarget.make(team: match, slot: 3, ownIsPlayer1: false, ownName: "Gerd-Jan", opponentName: "Henk")
        let matchId = UUID()

        await TeamMatchSupport.track(target, matchId: matchId, store: store)
        let stored = try await store.loadAll()[0]
        XCTAssertEqual(stored.partijTracking(matchId: matchId.uuidString)?.slot, 3)
        XCTAssertEqual(stored.partij(3).ownPlayer, "Gerd-Jan", "the names it was started with stay with the partij")

        // Resumed after leaving: the same coupling, from the stored team match
        let back = await TeamMatchSupport.target(forMatchId: matchId, store: store)
        XCTAssertEqual(back?.slot, 3)
        XCTAssertEqual(back?.ownIsPlayer1, false)
        XCTAssertEqual(back?.ownPlayer, "Gerd-Jan")
        XCTAssertEqual(back?.teamMatchId, match.id)
        let unknown = await TeamMatchSupport.target(forMatchId: UUID(), store: store)
        XCTAssertNil(unknown)

        // Thrown away or saved as incomplete: the partij is free again
        await TeamMatchSupport.untrack(matchId: matchId, store: store)
        let freed = await TeamMatchSupport.target(forMatchId: matchId, store: store)
        XCTAssertNil(freed)
        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testTheMatchDayQuestionStoresTheTeamMatchAndLinksTheResult() async throws {
        let directory = folder()
        let store = JSONFileTeamMatchStore(directory: directory)
        // A match of the fixtures of Mijn team: not saved yet
        let fixture = team()
        let coach = Match()
        coach.setupMatch(player1: "Gerd-Jan", player2: "Piet", startingServer: .player1,
                         player1CoachingFocus: [], player2CoachingFocus: [], player1GamesBefore: 2, player2GamesBefore: 0)
        for _ in 0..<11 { coach.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive) }
        coach.startNewGame()

        await TeamMatchSupport.linkOnMatchDay(coach: coach, team: fixture, slot: 2, ownIsPlayer1: true, store: store)
        let all = try await store.loadAll()
        XCTAssertEqual(all.count, 1, "stored now")
        let partij = all[0].partij(2)
        XCTAssertEqual(partij.linkedMatchId, coach.id.uuidString)
        XCTAssertEqual(partij.ownPlayer, "Gerd-Jan")
        XCTAssertEqual(partij.ownGames, 3)

        // Answering again for a stored team match does not store a second one
        await TeamMatchSupport.linkOnMatchDay(coach: coach, team: all[0], slot: 4, ownIsPlayer1: true, store: store)
        let again = try await store.loadAll()
        XCTAssertEqual(again.count, 1)
        XCTAssertNotNil(again[0].partijLinked(to: coach.id.uuidString))
        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testADecidedTeamMatchIsNotAskedAboutAgain() async throws {
        let directory = folder()
        let store = JSONFileTeamMatchStore(directory: directory)
        var decided = TeamMatch(date: Date(), home: "A", away: "B", ownSide: .home)
        for slot in 1...4 {
            var partij = decided.partij(slot)
            for _ in 0..<3 { _ = partij.addGame(TeamGame(own: 11, their: 5)) }
            decided.update(partij)
        }
        XCTAssertTrue(decided.isComplete)
        try await store.save(decided)
        let candidate = await TeamMatchSupport.candidate(store: store)
        XCTAssertNil(candidate, "a practice game after the team match does not get the question")
        try? FileManager.default.removeItem(at: directory)
    }
}
