import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Spelersprofiel: a player's matches over time
final class PlayerTrendTests: XCTestCase {
    private let gerdJan = UUID()
    private let piet = UUID()
    private let klaas = UUID()

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_790_000_000.0 + Double(n) * 86_400.0) }

    /// A coach match Gerd-Jan (player 1) against `opponent`: per game the points
    /// as (Gerd-Jan's winners with this shot, his unforced errors)
    private func coach(against opponent: UUID, name: String = "Piet", won: Bool, drops: Int = 0, errors: Int = 0,
                       gamesBefore: Int = 0) -> Match {
        let match = Match()
        match.setupMatch(player1: "Gerd-Jan", player2: name, startingServer: .player1,
                         player1GamesBefore: won ? gamesBefore : 0, player2GamesBefore: won ? 0 : gamesBefore,
                         player1Id: gerdJan, player2Id: opponent)
        let winner = won ? Player.player1 : Player.player2
        var game = 0
        while !match.isMatchOver {
            let current = match.currentGame
            current.now = { Date(timeIntervalSince1970: 1_790_000_000.0 + Double(current.points.count) * 10.0) }
            current.start(at: Date(timeIntervalSince1970: 1_789_999_990.0))
            if game == 0 {
                for _ in 0..<drops { current.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drop) }
                for _ in 0..<errors {
                    current.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.down)
                }
            }
            while !current.isGameOver {
                current.addPoint(to: winner, pointType: PointType.winner, at: CourtZone.backRight, with: ShotType.drive)
            }
            game += 1
            match.onGameEnd()
        }
        match.status = .completed
        return match
    }

    private func referee(against opponent: UUID, won: Bool) -> RefereeMatch {
        let match = RefereeMatch(player1Name: "Gerd-Jan", player2Name: "Klaas", bestOf: 5, startingServer: .player1)
        match.player1Id = gerdJan
        match.player2Id = opponent
        for game in 0..<3 {
            for _ in 0..<11 { match.awardPoint(to: won ? Player.player1 : Player.player2) }
            if game < 2 { match.confirmNextGame() }
        }
        return match
    }

    func testACoachMatchIsSeenFromThePlayer() throws {
        let match = coach(against: piet, won: true, drops: 4, errors: 2)
        let seen = try XCTUnwrap(PlayerTrendMatch.of(coach: match, playerId: gerdJan.uuidString, date: day(1)))
        XCTAssertEqual(seen.won, true)
        XCTAssertEqual(seen.ownGames, 3)
        XCTAssertEqual(seen.theirGames, 0)
        XCTAssertEqual(seen.opponentName, "Piet")
        XCTAssertEqual(seen.opponentKey, piet.uuidString.lowercased())
        XCTAssertEqual(seen.trackedGames, 3)
        XCTAssertEqual(seen.winners, 33, "11 winners in each of the three games")
        XCTAssertEqual(seen.unforcedErrors, 2)
        XCTAssertEqual(seen.shotsWon[ShotType.drop], 4)
        XCTAssertEqual(seen.errorKinds[ErrorKind.down], 2)
        XCTAssertEqual(seen.zones.won.front, 4)
        XCTAssertTrue(seen.ralliesWon > 0)

        // The same match from the other side, lower case id; and someone who did not play
        let other = try XCTUnwrap(PlayerTrendMatch.of(coach: match, playerId: piet.uuidString.lowercased(), date: day(1)))
        XCTAssertEqual(other.won, false)
        XCTAssertEqual(other.ownGames, 0)
        XCTAssertNil(PlayerTrendMatch.of(coach: match, playerId: klaas.uuidString, date: day(1)))
    }

    func testAHeadStartCountsInTheStandButHasNoPoints() throws {
        let match = coach(against: piet, won: true, gamesBefore: 2)
        let seen = try XCTUnwrap(PlayerTrendMatch.of(coach: match, playerId: gerdJan.uuidString, date: day(1)))
        XCTAssertEqual(seen.ownGames, 3)
        XCTAssertEqual(seen.trackedGames, 1, "only the game that was played point by point")
        XCTAssertEqual(seen.winners, 11)
    }

    func testARefereeMatchHasOnlyTheScore() throws {
        let match = referee(against: klaas, won: false)
        let seen = try XCTUnwrap(PlayerTrendMatch.of(referee: match, playerId: gerdJan.uuidString, date: day(2)))
        XCTAssertFalse(seen.isCoach)
        XCTAssertEqual(seen.won, false)
        XCTAssertEqual(seen.theirGames, 3)
        XCTAssertEqual(seen.trackedGames, 0)

        // Without point types the profile has form and opponents, but no lines, shots or court
        let summary = PlayerTrendSummary(from: [seen], period: .all)
        XCTAssertEqual(summary.form.count, 1)
        XCTAssertTrue(summary.coachMatches.isEmpty)
        XCTAssertTrue(summary.topShots.isEmpty)
        XCTAssertNil(summary.commonError)
        XCTAssertNil(summary.averageRallyWon)
        XCTAssertEqual(summary.opponents, [PlayerTrendOpponent(name: "Klaas", won: 0, lost: 1)])
    }

    func testTheSummaryShowsFormShotsErrorsAndTheChange() throws {
        // Twelve coach matches: errors go down from 4 to 1 in the first game
        var matches: [PlayerTrendMatch] = []
        for n in 0..<12 {
            let match = coach(against: n % 3 == 0 ? klaas : piet, name: n % 3 == 0 ? "Klaas" : "Piet",
                              won: n % 4 != 0, drops: n % 2, errors: n < 6 ? 4 : 1)
            matches.append(try XCTUnwrap(PlayerTrendMatch.of(coach: match, playerId: gerdJan.uuidString, date: day(n))))
        }
        let all = PlayerTrendSummary(from: matches.reversed(), period: .all)
        XCTAssertEqual(all.played, 12)
        XCTAssertEqual(all.matches.first?.date, day(0), "oldest first, whatever order they came in")
        XCTAssertEqual(all.won, 9)
        XCTAssertEqual(all.winPercentage, 75)
        XCTAssertEqual(all.form.count, 10)
        XCTAssertEqual(all.form.last?.date, day(11))
        XCTAssertEqual(all.topShots.first?.shot, ShotType.drive)
        XCTAssertEqual(all.topShots.count, 2)
        XCTAssertEqual(all.commonError, ErrorKind.down)
        XCTAssertEqual(all.opponents.first?.name, "Piet")
        XCTAssertEqual(all.opponents.first?.played, 8)

        let change = try XCTUnwrap(PlayerTrendSummary.change(all.errorsPerGame))
        XCTAssertTrue(change.from > change.to)
        XCTAssertEqual(PlayerTrendChange(from: 3.14, to: 2.0).text, "van 3,1 naar 2,0")

        // The period takes the newest matches
        let last10 = PlayerTrendSummary(from: matches, period: .last10)
        XCTAssertEqual(last10.played, 10)
        XCTAssertEqual(last10.matches.first?.date, day(2))
        XCTAssertNil(PlayerTrendSummary.change([1.0, 2.0, 3.0]), "too few matches to say")
    }

    func testTheCourtSaysWhereThePlayerWinsMost() throws {
        let match = coach(against: piet, won: true, drops: 6)
        let seen = try XCTUnwrap(PlayerTrendMatch.of(coach: match, playerId: gerdJan.uuidString, date: day(1)))
        let summary = PlayerTrendSummary(from: [seen], period: .all)
        XCTAssertEqual(summary.strongestArea, CourtRow.back.inWords, "most winners were drives at the back")
        XCTAssertNil(summary.weakestArea, "Piet won no points with a shot")
    }

    @MainActor
    func testTheHistoryStoreGivesThePlayersMatches() async throws {
        let store = TrendHistoryStore()
        store.coach = [coach(against: piet, won: true)]
        store.referee = [referee(against: klaas, won: true)]
        let other = Match()
        other.setupMatch(player1: "A", player2: "B", startingServer: .player1)
        store.coach.append(other)
        let matches = try await store.trendMatches(forPlayer: gerdJan.uuidString)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches.filter { match in match.isCoach }.count, 1)
    }
}

@MainActor
private final class TrendHistoryStore: MatchHistoryStore {
    var coach: [Match] = []
    var referee: [RefereeMatch] = []

    func loadHistory() async throws -> [MatchHistorySummary] {
        var result: [MatchHistorySummary] = []
        for match in coach {
            result.append(MatchHistorySummary(id: match.id.uuidString, kind: "coach", player1Name: match.player1Name, player2Name: match.player2Name,
                                              player1Games: match.player1GamesWon, player2Games: match.player2GamesWon, status: "completed",
                                              updatedAt: Date(timeIntervalSince1970: 1_790_000_000.0)))
        }
        for match in referee {
            result.append(MatchHistorySummary(id: match.id.uuidString, kind: "referee", player1Name: match.player1Name, player2Name: match.player2Name,
                                              player1Games: match.player1TotalGames, player2Games: match.player2TotalGames, status: "completed",
                                              updatedAt: Date(timeIntervalSince1970: 1_790_000_000.0)))
        }
        return result
    }

    func coachMatch(id: String) async throws -> Match? {
        for match in coach where match.id.uuidString == id { return match }
        return nil
    }

    func refereeMatch(id: String) async throws -> RefereeMatch? {
        for match in referee where match.id.uuidString == id { return match }
        return nil
    }

    func saveCoachMatch(_ match: Match) async throws {}
    func delete(_ entry: MatchHistorySummary) async throws {}
}
