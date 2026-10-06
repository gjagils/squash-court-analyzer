import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Competitie: a player who gives up or does not show up, and the SBN
/// Algemeen competitiereglement art. 23 (partijen, full team, games, points, E1)
final class TeamPartijEndTests: XCTestCase {
    private func partij(_ slot: Int, _ scores: [(Int, Int)]) -> TeamPartij {
        var partij = TeamPartij(slot: slot, ownPlayer: "Wij\(slot)", opponentPlayer: "Zij\(slot)")
        for score in scores {
            XCTAssertTrue(partij.addGame(TeamGame(own: score.0, their: score.1)), "game \(score.0)-\(score.1) in E\(slot)")
        }
        return partij
    }

    private func match(_ partijen: [TeamPartij], ownSide: TeamSide = .home) -> TeamMatch {
        TeamMatch(date: Date(timeIntervalSince1970: 1_793_181_600.0), home: "All Inn Squash 8", away: "Squash Delft 8",
                  ownSide: ownSide, partijen: partijen, updatedAt: Date(timeIntervalSince1970: 1_793_181_600.0))
    }

    private func walkover(_ slot: Int, ownWins: Bool) -> TeamPartij {
        var partij = TeamPartij(slot: slot, ownPlayer: "Wij\(slot)", opponentPlayer: "Zij\(slot)")
        XCTAssertTrue(partij.walkover(ownWins: ownWins))
        return partij
    }

    // MARK: Opgave

    func testGivingUpFinishesTheGameInProgressAndTheMissingGamesForTheOpponent() {
        var game = partij(1, [(11, 8), (9, 11)])
        // Their player gives up at 7-9, leading: our player gets every remaining point (11-9)
        XCTAssertTrue(game.giveUp(ownGivesUp: false, currentOwn: 7, currentTheir: 9))
        XCTAssertEqual(game.gamesText, "11-8, 9-11, 11-9, 11-0")
        XCTAssertEqual(game.ownGames, 3)
        XCTAssertEqual(game.theirGames, 1)
        XCTAssertEqual(game.ownWon, true)
        XCTAssertEqual(game.endedBy, TeamPartijEnd.retired)
        XCTAssertEqual(game.endedAfter, 2)
        XCTAssertEqual(game.endText, "opgave")
        XCTAssertFalse(game.ownMissing)
        XCTAssertFalse(game.theirMissing, "giving up is not staying away")
    }

    func testTheOpponentGetsTwoClearWhenTheyGaveUpAtTenAll() {
        var game = partij(2, [])
        XCTAssertTrue(game.giveUp(ownGivesUp: true, currentOwn: 10, currentTheir: 10))
        XCTAssertEqual(game.gamesText, "10-12, 0-11, 0-11")
        XCTAssertEqual(game.ownWon, false)
        XCTAssertEqual(game.theirGames, 3)
    }

    func testGivingUpBetweenGamesAddsOnlyShutouts() {
        var game = partij(3, [(11, 8)])
        XCTAssertTrue(game.giveUp(ownGivesUp: true))
        XCTAssertEqual(game.gamesText, "11-8, 0-11, 0-11, 0-11")
        XCTAssertEqual(game.ownGames, 1)
        XCTAssertEqual(game.theirGames, 3)
        XCTAssertEqual(game.ownPoints, 11)
        XCTAssertEqual(game.theirPoints, 41)
    }

    func testGivingUpIsRefusedWhenItDoesNotApply() {
        var over = partij(1, [(11, 5), (11, 7), (11, 9)])
        XCTAssertFalse(over.giveUp(ownGivesUp: true))
        var open = partij(1, [(11, 5)])
        XCTAssertFalse(open.giveUp(ownGivesUp: true, currentOwn: 5, currentTheir: nil), "half a score")
        XCTAssertFalse(open.giveUp(ownGivesUp: true, currentOwn: -1, currentTheir: 3))
        XCTAssertEqual(open.games.count, 1)
        XCTAssertTrue(open.giveUp(ownGivesUp: false))
        XCTAssertFalse(open.giveUp(ownGivesUp: false), "only once")
    }

    // MARK: Niet verschenen

    func testAWalkoverIsThreeTimesElevenNil() {
        var won = TeamPartij(slot: 2)
        XCTAssertTrue(won.walkover(ownWins: true))
        XCTAssertEqual(won.gamesText, "11-0, 11-0, 11-0")
        XCTAssertEqual(won.ownWon, true)
        XCTAssertEqual(won.endText, "niet verschenen")
        XCTAssertTrue(won.theirMissing)
        XCTAssertFalse(won.ownMissing)
        XCTAssertEqual(won.ownPoints, 33)
        var lost = TeamPartij(slot: 2, bestOf: 3)
        XCTAssertTrue(lost.walkover(ownWins: false))
        XCTAssertEqual(lost.gamesText, "0-11, 0-11")
        XCTAssertTrue(lost.ownMissing)
        // Not on a partij that has games
        var played = partij(1, [(11, 5)])
        XCTAssertFalse(played.walkover(ownWins: true))
    }

    func testAnEndingCanBeTakenBack() {
        var game = partij(1, [(11, 8), (9, 11)])
        XCTAssertTrue(game.giveUp(ownGivesUp: false, currentOwn: 3, currentTheir: 2))
        game.clearEnd()
        XCTAssertEqual(game.gamesText, "11-8, 9-11")
        XCTAssertNil(game.endedBy)
        var empty = TeamPartij(slot: 1)
        XCTAssertTrue(empty.walkover(ownWins: true))
        empty.clearEnd()
        XCTAssertTrue(empty.games.isEmpty)
        // Taking a game away also drops the mark: it no longer says what happened
        var other = TeamPartij(slot: 1)
        XCTAssertTrue(other.walkover(ownWins: false))
        other.removeLastGame()
        XCTAssertNil(other.endedBy)
        XCTAssertNil(other.endText)
    }

    func testLinkingAMatchReplacesAnEnding() {
        var game = TeamPartij(slot: 1)
        XCTAssertTrue(game.walkover(ownWins: true))
        let summary = MatchHistorySummary(id: "m", kind: "coach", player1Name: "Wij", player2Name: "Zij",
                                          player1Games: 3, player2Games: 1, status: "completed", updatedAt: Date(),
                                          games: [HistoryGameScore(player1Score: 11, player2Score: 5, winner: Player.player1.rawValue),
                                                  HistoryGameScore(player1Score: 7, player2Score: 11, winner: Player.player2.rawValue),
                                                  HistoryGameScore(player1Score: 11, player2Score: 9, winner: Player.player1.rawValue),
                                                  HistoryGameScore(player1Score: 11, player2Score: 6, winner: Player.player1.rawValue)])
        game.link(summary, ownIsPlayer1: true)
        XCTAssertNil(game.endedBy)
        XCTAssertEqual(game.ownGames, 3)
    }

    // MARK: Artikel 23

    func testTheTeamThatIsFullWinsWhenThePartijenAreEqual() {
        // 2-2 in partijen; theirs did not show up in E1, so they are not full
        let team = match([
            walkover(1, ownWins: true),
            partij(2, [(9, 11), (9, 11), (9, 11)]),
            partij(3, [(9, 11), (9, 11), (9, 11)]),
            partij(4, [(11, 5), (11, 7), (11, 9)]),
        ])
        let score = team.score
        XCTAssertEqual(score.ownPartijen, 2)
        XCTAssertEqual(score.theirPartijen, 2)
        XCTAssertTrue(score.ownTeamFull)
        XCTAssertFalse(score.theirTeamFull)
        XCTAssertEqual(score.ownGames, 6)
        XCTAssertEqual(score.theirGames, 6)
        XCTAssertEqual(score.ownWon, true)
        XCTAssertFalse(score.winnerNotFull)
        XCTAssertEqual(score.ownCompetitionPoints, 9, "6 games and the 3 bonus points")
        XCTAssertEqual(score.theirCompetitionPoints, 6)
    }

    func testAWinByATeamThatIsNotFullGetsNoBonusPoints() {
        // We win E1-E3, but our E4 did not show up: 3-1 in partijen
        let team = match([
            partij(1, [(11, 5), (11, 7), (11, 9)]),
            partij(2, [(11, 5), (11, 7), (11, 9)]),
            partij(3, [(11, 5), (11, 7), (11, 9)]),
            walkover(4, ownWins: false),
        ])
        let score = team.score
        XCTAssertEqual(score.ownWon, true)
        XCTAssertFalse(score.ownTeamFull)
        XCTAssertTrue(score.winnerNotFull)
        XCTAssertEqual(score.ownCompetitionPoints, 9, "only the games won")
        XCTAssertEqual(score.theirCompetitionPoints, 3)
        XCTAssertTrue(TeamMatchReport.text(team).contains("(geen bonuspunten: onvolledig team)"))
    }

    func testEqualEverythingIsDecidedByTheWinnerOfE1() {
        func shape(e1Won: Bool) -> TeamMatch {
            let win = [(11, 9), (11, 9), (11, 9)]
            let loss = [(9, 11), (9, 11), (9, 11)]
            return match([partij(1, e1Won ? win : loss), partij(2, e1Won ? loss : win), partij(3, win), partij(4, loss)])
        }
        let yes = shape(e1Won: true).score
        XCTAssertEqual(yes.ownGames, 6)
        XCTAssertEqual(yes.theirGames, 6)
        XCTAssertEqual(yes.ownPoints, yes.theirPoints)
        XCTAssertEqual(yes.ownWon, true)
        XCTAssertEqual(shape(e1Won: false).score.ownWon, false)
        XCTAssertEqual(shape(e1Won: true).statusText, "All Inn Squash 8 wint 6-6")
    }

    func testTwoTeamsThatAreNotFullHaveNoWinnerToTheReglement() {
        let team = match([
            walkover(1, ownWins: true),
            walkover(2, ownWins: false),
            partij(3, [(11, 5), (11, 7), (11, 9)]),
            partij(4, [(5, 11), (7, 11), (9, 11)]),
        ])
        let score = team.score
        XCTAssertTrue(score.isComplete)
        XCTAssertFalse(score.ownTeamFull)
        XCTAssertFalse(score.theirTeamFull)
        XCTAssertNil(score.ownWon)
        XCTAssertEqual(score.ownCompetitionPoints, 6)
        XCTAssertEqual(score.theirCompetitionPoints, 6)
    }

    // MARK: Verslag, live, bestand

    func testTheReportAndThePictureSayHowAPartijEnded() {
        var retired = partij(1, [(11, 8), (9, 11)])
        XCTAssertTrue(retired.giveUp(ownGivesUp: false, currentOwn: 4, currentTheir: 6))
        let team = match([retired, walkover(2, ownWins: false)])
        let text = TeamMatchReport.text(team)
        XCTAssertTrue(text.contains("(11-8, 9-11, 11-6, 11-0 (opgave))"), text)
        XCTAssertTrue(text.contains("(0-11, 0-11, 0-11 (niet verschenen))"), text)
        let rows = ResultCard.from(team).rows
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows[1].games.hasSuffix("(niet verschenen)"), rows[1].games)
    }

    func testAnEndingTravelsOverTheLivePage() {
        let team = match([walkover(3, ownWins: false)])
        let payload = team.partij(3).livePayload(in: team)!
        XCTAssertEqual(payload.end, "walkover")
        XCTAssertEqual(payload.endAfter, 0)
        XCTAssertEqual(payload.gamesWon, [0, 3])
        let back = TeamPartij.fromLive(payload, slot: 3, ownIsHome: true)!
        XCTAssertEqual(back.endedBy, TeamPartijEnd.walkover)
        XCTAssertTrue(back.ownMissing)
        // An ending the app does not know is left out, and a count is kept within the games
        var odd = payload
        odd.end = "banana"
        XCTAssertNil(TeamPartij.fromLive(odd, slot: 3, ownIsHome: true)!.endedBy)
        var far = payload
        far.endAfter = 6
        XCTAssertEqual(TeamPartij.fromLive(far, slot: 3, ownIsHome: true)!.endedAfter, 3)
    }

    func testFilesWithoutAnEndingStayTheSameAndOldFilesStillRead() throws {
        let plain = partij(1, [(11, 5)])
        let json = String(data: try JSONEncoder().encode(plain), encoding: String.Encoding.utf8) ?? ""
        XCTAssertFalse(json.contains("endedBy"), json)
        XCTAssertFalse(json.contains("endedAfter"), json)
        let decoded = try JSONDecoder().decode(TeamPartij.self, from: JSONEncoder().encode(plain))
        XCTAssertEqual(decoded, plain)
        let ended = walkover(2, ownWins: true)
        let again = try JSONDecoder().decode(TeamPartij.self, from: JSONEncoder().encode(ended))
        XCTAssertEqual(again.endedBy, TeamPartijEnd.walkover)
        XCTAssertEqual(again, ended)
    }
}
