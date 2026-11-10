import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Competition badges (4.0, T7): Teamspeler and Matchwinnaar from the team matches
final class TeamBadgesTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_792_706_400.0)
    private let now = Date(timeIntervalSince1970: 1_800_000_000.0)

    private let win: [(Int, Int)] = [(11, 5), (11, 6), (11, 7)]
    private let loss: [(Int, Int)] = [(5, 11), (6, 11), (7, 11)]

    private func partij(_ slot: Int, _ name: String, _ scores: [(Int, Int)]) -> TeamPartij {
        var partij = TeamPartij(slot: slot, ownPlayer: name, opponentPlayer: "Zij\(slot)")
        for score in scores { XCTAssertTrue(partij.addGame(TeamGame(own: score.0, their: score.1))) }
        return partij
    }

    private func match(day: Int, _ partijen: [TeamPartij], fixture: String? = nil, updated: Double = 0) -> TeamMatch {
        let date = start.addingTimeInterval(Double(day) * 86_400.0)
        return TeamMatch(date: date, home: "All Inn 8", away: "Delft 8", ownSide: .home, fixtureId: fixture,
                         partijen: partijen, updatedAt: date.addingTimeInterval(updated))
    }

    private func badges(_ awards: [TeamBadges.Award], _ name: String) -> [BadgeKind] {
        TeamBadges.awards(for: name, in: awards).map { award in award.badge }
    }

    func testTeamPlayerTiersAtThirdEighthAndFifteenthPartij() {
        var matches: [TeamMatch] = []
        for day in 0..<15 {
            matches.append(match(day: day + 1, [partij(1, "Kees de Vries", day % 2 == 0 ? win : loss)]))
        }
        let awards = TeamBadges.awards(from: matches, start: start, now: now)
        let kees = TeamBadges.awards(for: "kees  de vries", in: awards).filter { award in award.badge.family == BadgeKind.teamPlayer }
        XCTAssertEqual(kees.map { award in award.badge }, [BadgeKind.teamPlayer, BadgeKind.teamPlayerSilver, BadgeKind.teamPlayerGold])
        XCTAssertEqual(kees[0].matchId, TeamBadges.partijId(teamMatchId: matches[2].id, slot: 1))
        XCTAssertEqual(kees[1].earnedAt, matches[7].date)
        XCTAssertEqual(kees[2].matchId, TeamBadges.partijId(teamMatchId: matches[14].id, slot: 1))
    }

    func testOpenPartijenWalkoversDefaultNamesAndOldMatchesDoNotCount() {
        var walkover = TeamPartij(slot: 2, ownPlayer: "Kees")
        XCTAssertTrue(walkover.walkover(ownWins: true))
        let open = partij(3, "Kees", [(11, 5)])
        let defaultName = partij(4, "All Inn 8 E4", win)
        let before = TeamMatch(date: start.addingTimeInterval(-86_400.0), home: "All Inn 8", away: "Delft 8", ownSide: .home,
                               partijen: [partij(1, "Kees", win)])
        let matches = [match(day: 1, [walkover, open, defaultName]), before, match(day: 2, [partij(1, "Kees", win)])]
        let entries = TeamBadges.entries(from: matches, start: start, now: now)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].playerName, "Kees")
    }

    func testMatchWinnerOnlyForThePartijThatDecided() {
        // 3-1 with close wins: had any won partij been lost, 2-2 with fewer games, so every won partij decided
        let close: [(Int, Int)] = [(11, 5), (5, 11), (11, 6), (6, 11), (11, 7)]
        let threeOne = match(day: 1, [partij(1, "A", close), partij(2, "B", close), partij(3, "C", close), partij(4, "D", loss)])
        // 4-0: no single partij decided it
        let fourNil = match(day: 2, [partij(1, "A", win), partij(2, "B", win), partij(3, "C", win), partij(4, "D", win)])
        // Lost 1-3: nobody
        let lost = match(day: 3, [partij(1, "A", win), partij(2, "B", loss), partij(3, "C", loss), partij(4, "D", loss)])
        let awards = TeamBadges.awards(from: [threeOne, fourNil, lost], start: start, now: now)
        let winners = awards.filter { award in award.badge == BadgeKind.matchWinner }
        XCTAssertEqual(winners.map { award in award.playerName }.sorted(), ["A", "B", "C"])
        for award in winners { XCTAssertEqual(award.earnedAt, threeOne.date) }
        XCTAssertTrue(badges(awards, "D").filter { kind in kind == BadgeKind.matchWinner }.isEmpty)
    }

    func testMatchWinnerWhenTheTieBreakGoesToE1() {
        // 3-1 with 3-0 wins: losing E2 or E3 gives 2-2, equal games and points, and E1 decides: only A
        let threeOne = match(day: 1, [partij(1, "A", win), partij(2, "B", win), partij(3, "C", win), partij(4, "D", loss)])
        let winners = TeamBadges.awards(from: [threeOne], start: start, now: now).filter { award in award.badge == BadgeKind.matchWinner }
        XCTAssertEqual(winners.map { award in award.playerName }, ["A"])
    }

    func testMatchWinnerInATwoTwoWonOnGames() {
        // 2-2 in partijen, won on games (9-6): E1 lost 2-3, E2 won 3-0, E3 won 3-0, E4 lost 1-3.
        // Losing E2 or E3 makes it 1-3; both decided
        let e1 = partij(1, "A", [(11, 5), (11, 6), (5, 11), (6, 11), (9, 11)])
        let e4 = partij(4, "D", [(11, 5), (6, 11), (7, 11), (8, 11)])
        let twoTwo = match(day: 1, [e1, partij(2, "B", win), partij(3, "C", win), e4])
        XCTAssertEqual(twoTwo.score.ownWon, true)
        let winners = TeamBadges.awards(from: [twoTwo], start: start, now: now).filter { award in award.badge == BadgeKind.matchWinner }
        XCTAssertEqual(winners.map { award in award.playerName }.sorted(), ["B", "C"])
    }

    func testTwoCopiesOfTheSameFixtureCountOnce() {
        let older = match(day: 1, [partij(1, "Kees", win)], fixture: "sbn/1", updated: 0)
        let newer = match(day: 1, [partij(1, "Kees", win)], fixture: "sbn/1", updated: 60)
        let entries = TeamBadges.entries(from: [older, newer], start: start, now: now)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].matchId, TeamBadges.partijId(teamMatchId: newer.id, slot: 1))
    }

    func testPartijIdIsStablePerMatchAndSlot() {
        let id = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
        XCTAssertEqual(TeamBadges.partijId(teamMatchId: id, slot: 2), TeamBadges.partijId(teamMatchId: id, slot: 2))
        XCTAssertNotEqual(TeamBadges.partijId(teamMatchId: id, slot: 2), TeamBadges.partijId(teamMatchId: id, slot: 3))
    }

    func testBadgeKindsOfTheCompetition() {
        XCTAssertEqual(BadgeKind.teamPlayerGold.family, BadgeKind.teamPlayer)
        XCTAssertEqual(BadgeKind.teamPlayerSilver.threshold, 8)
        XCTAssertEqual(BadgeKind.teamPlayer.category, BadgeKind.Category.competition)
        XCTAssertEqual(BadgeKind.matchWinner.category, BadgeKind.Category.competition)
        XCTAssertTrue(BadgeKind.teamPlayer.isOnce)
        XCTAssertFalse(BadgeKind.matchWinner.isOnce)
        XCTAssertTrue(BadgeKind.matchWinner.isTeamBadge)
        XCTAssertFalse(BadgeKind.veteran.isTeamBadge)
        XCTAssertEqual(BadgeKind.teamPlayerSilver.imageName, "badge-team-player-silver")
        XCTAssertEqual(BadgeKind.matchWinner.imageName, "badge-match-winner")
        XCTAssertTrue(BadgeKind.collection.contains(BadgeKind.teamPlayer))
    }
}
