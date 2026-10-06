import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Competitie: a team match of four partijen with the SBN rules
final class TeamMatchTests: XCTestCase {
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

    func testAGameScoreMustBeASquashScore() {
        XCTAssertTrue(TeamGame.isValidScore(11, 8))
        XCTAssertTrue(TeamGame.isValidScore(8, 11))
        XCTAssertTrue(TeamGame.isValidScore(12, 10))
        XCTAssertTrue(TeamGame.isValidScore(15, 13))
        XCTAssertTrue(TeamGame.isValidScore(11, 0))
        XCTAssertFalse(TeamGame.isValidScore(11, 10))
        XCTAssertFalse(TeamGame.isValidScore(10, 8))
        XCTAssertFalse(TeamGame.isValidScore(13, 10))
        XCTAssertFalse(TeamGame.isValidScore(11, -1))
        XCTAssertEqual(TeamGame(own: 11, their: 8).text, "11-8")
        XCTAssertTrue(TeamGame(own: 11, their: 8).ownWon)
        XCTAssertFalse(TeamGame(own: 9, their: 11).ownWon)
        XCTAssertEqual(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: true).text, "–")
    }

    func testAPartijEndsAtThreeGamesAndTakesNoMore() {
        var first = partij(1, [(11, 8), (9, 11), (11, 6)])
        XCTAssertFalse(first.isOver)
        XCTAssertNil(first.ownWon)
        XCTAssertTrue(first.canAddGame)
        XCTAssertTrue(first.addGame(TeamGame(own: 11, their: 9)))
        XCTAssertTrue(first.isOver)
        XCTAssertEqual(first.ownWon, true)
        XCTAssertEqual(first.standText, "3-1")
        XCTAssertEqual(first.gamesText, "11-8, 9-11, 11-6, 11-9")
        XCTAssertFalse(first.canAddGame)
        XCTAssertFalse(first.addGame(TeamGame(own: 11, their: 3)), "a decided partij takes no fifth game")
        XCTAssertFalse(first.addGame(TeamGame(own: 11, their: 10)), "11-10 is no squash score")
        first.removeLastGame()
        XCTAssertFalse(first.isOver)
        XCTAssertEqual(first.games.count, 3)
    }

    func testTheTeamResultIsTheGamesWithThreeBonusPointsForTheWinner() {
        let team = match([
            partij(1, [(11, 5), (11, 7), (11, 9)]),            // 3-0
            partij(2, [(11, 9), (8, 11), (11, 13), (11, 4), (11, 8)]), // 3-2
            partij(3, [(11, 6), (5, 11), (7, 11), (9, 11)]),   // 1-3
            partij(4, [(11, 9), (11, 8), (6, 11), (9, 11), (8, 11)]), // 2-3
        ])
        let score = team.score
        XCTAssertTrue(score.isComplete)
        XCTAssertEqual(score.ownGames, 9)
        XCTAssertEqual(score.theirGames, 8)
        XCTAssertEqual(score.ownPartijen, 2)
        XCTAssertEqual(score.theirPartijen, 2)
        XCTAssertEqual(score.ownWon, true)
        XCTAssertEqual(score.ownCompetitionPoints, 12)
        XCTAssertEqual(score.theirCompetitionPoints, 8)
        XCTAssertEqual(team.winnerName, "All Inn Squash 8")
        XCTAssertEqual(team.gamesText, "9-8")
        XCTAssertEqual(team.statusText, "All Inn Squash 8 wint 9-8")
    }

    func testEqualGamesGoToTheTeamWithMorePartijen() {
        // 8-8 in games, 3-1 in partijen
        let team = match([
            partij(1, [(11, 5), (11, 7), (11, 9)]),            // 3-0
            partij(2, [(11, 9), (11, 8), (11, 4)]),            // 3-0
            partij(3, [(11, 6), (5, 11), (11, 7), (9, 11), (11, 9)]), // 3-2 (own 2 lost)
            partij(4, [(3, 11), (4, 11), (5, 11)]),            // 0-3
        ])
        // own games: 3+3+3+0 = 9, their: 0+0+2+3 = 5 → not equal yet; make E4 2-3 and E3 1-3
        let tied = match([
            partij(1, [(11, 5), (11, 7), (11, 9)]),            // 3-0
            partij(2, [(11, 9), (11, 8), (11, 4)]),            // 3-0
            partij(3, [(11, 6), (5, 11), (7, 11), (9, 11)]),   // 1-3
            partij(4, [(11, 9), (6, 11), (9, 11), (8, 11)]),   // 1-3
        ])
        XCTAssertEqual(team.score.ownWon, true)
        XCTAssertEqual(tied.score.ownGames, 8)
        XCTAssertEqual(tied.score.theirGames, 6)
        // Real tie on games: E1 3-1, E2 3-2, E3 1-3, E4 1-3 → 8-9? Build 8-8 explicitly
        let eight = match([
            partij(1, [(11, 5), (9, 11), (11, 7), (11, 9)]),           // 3-1
            partij(2, [(11, 9), (8, 11), (11, 8), (11, 4)]),           // 3-1
            partij(3, [(11, 6), (5, 11), (7, 11), (9, 11)]),           // 1-3
            partij(4, [(11, 9), (6, 11), (9, 11), (8, 11)]),           // 1-3
        ])
        XCTAssertEqual(eight.score.ownGames, 8)
        XCTAssertEqual(eight.score.theirGames, 8)
        XCTAssertEqual(eight.score.ownPartijen, 2)
        XCTAssertEqual(eight.score.theirPartijen, 2)
        // 2-2 in partijen as well: the rally points decide
        XCTAssertTrue(eight.score.pointsKnown)
        XCTAssertNotEqual(eight.score.ownPoints, eight.score.theirPoints)
        XCTAssertEqual(eight.score.ownWon, eight.score.ownPoints > eight.score.theirPoints)
        // 8-8 with 3-1 in partijen: the partijen decide
        let byPartijen = match([
            partij(1, [(11, 5), (9, 11), (11, 7), (11, 9)]),           // 3-1
            partij(2, [(11, 9), (8, 11), (11, 8), (11, 4)]),           // 3-1
            partij(3, [(11, 6), (5, 11), (11, 7), (9, 11), (11, 9)]),  // 3-2
            partij(4, [(3, 11), (4, 11), (5, 11)]),                    // 0-3
        ])
        XCTAssertEqual(byPartijen.score.ownGames, 9)
        XCTAssertEqual(byPartijen.score.theirGames, 7)
        XCTAssertEqual(byPartijen.score.ownWon, true)
    }

    func testAFullTieWithoutPointsIsADrawWithoutBonus() {
        // 8-8 in games and 2-2 in partijen, every game without a score
        func blind(_ slot: Int, _ wins: [Bool]) -> TeamPartij {
            var partij = TeamPartij(slot: slot)
            for won in wins { XCTAssertTrue(partij.addGame(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: won))) }
            return partij
        }
        let team = match([
            blind(1, [true, false, true, true]),
            blind(2, [true, false, true, true]),
            blind(3, [true, false, false, false]),
            blind(4, [true, false, false, false]),
        ])
        let score = team.score
        XCTAssertTrue(score.isComplete)
        XCTAssertFalse(score.pointsKnown)
        XCTAssertEqual(score.ownGames, 8)
        XCTAssertEqual(score.theirGames, 8)
        XCTAssertNil(score.ownWon)
        XCTAssertEqual(score.ownCompetitionPoints, 8)
        XCTAssertEqual(score.theirCompetitionPoints, 8)
        XCTAssertEqual(team.statusText, "Gelijkspel 8-8")
    }

    func testAnUnfinishedTeamMatchHasAStandButNoWinner() {
        let team = match([partij(1, [(11, 5), (11, 7), (11, 9)]), partij(2, [(11, 9), (8, 11)])])
        let score = team.score
        XCTAssertFalse(score.isComplete)
        XCTAssertEqual(score.partijenPlayed, 2)
        XCTAssertNil(score.ownWon)
        XCTAssertEqual(score.ownCompetitionPoints, 4, "no bonus before the end")
        XCTAssertEqual(team.statusText, "Stand 4-1 · 2 van 4 partijen")
        XCTAssertEqual(match([]).statusText, "Nog niet begonnen")
        XCTAssertEqual(match([]).partijen.count, 4, "always four slots")
        XCTAssertEqual(match([]).partij(3).label, "E3")
    }

    func testAwayTeamShowsHomeFirst() {
        let team = match([partij(1, [(11, 5), (11, 7), (11, 9)])], ownSide: .away)
        XCTAssertEqual(team.ownName, "Squash Delft 8")
        XCTAssertEqual(team.opponentName, "All Inn Squash 8")
        XCTAssertEqual(team.homeGames, 0)
        XCTAssertEqual(team.awayGames, 3)
        XCTAssertEqual(team.gamesText, "0-3")
    }

    func testAFixtureOfMijnTeamKnowsOurSide() {
        let fixture = LeagueFixture(id: "f1", date: Date(timeIntervalSince1970: 1_793_181_600.0), home: "All Inn Squash 8",
                                    away: "Squash Delft 8", score: nil, url: URL(string: "https://sbn.toernooi.nl/x")!)
        let home = TeamMatch.from(fixture: fixture, ownTeam: "All Inn Squash 8")
        XCTAssertEqual(home.ownSide, TeamSide.home)
        XCTAssertEqual(home.fixtureId, "f1")
        XCTAssertEqual(home.title, "All Inn Squash 8 – Squash Delft 8")
        let away = TeamMatch.from(fixture: fixture, ownTeam: " squash delft 8 ")
        XCTAssertEqual(away.ownSide, TeamSide.away)
    }

    func testLinkingATrackedMatchTakesItsGamesFromOurSide() {
        // Player 1 won 3-1: one game before scoring started, three tracked
        let summary = MatchHistorySummary(id: "m1", kind: "coach", player1Name: "Gerd-Jan", player2Name: "Piet",
                                          player1Games: 3, player2Games: 1, status: "completed",
                                          updatedAt: Date(timeIntervalSince1970: 1_793_181_600.0),
                                          games: [HistoryGameScore(player1Score: 11, player2Score: 8, winner: Player.player1.rawValue),
                                                  HistoryGameScore(player1Score: 9, player2Score: 11, winner: Player.player2.rawValue),
                                                  HistoryGameScore(player1Score: 11, player2Score: 6, winner: Player.player1.rawValue)],
                                          untrackedBefore: 1)
        var partij = TeamPartij(slot: 2)
        partij.link(summary, ownIsPlayer1: true)
        XCTAssertEqual(partij.ownPlayer, "Gerd-Jan")
        XCTAssertEqual(partij.opponentPlayer, "Piet")
        XCTAssertEqual(partij.games.count, 4)
        XCTAssertEqual(partij.ownGames, 3)
        XCTAssertEqual(partij.theirGames, 1)
        XCTAssertEqual(partij.gamesText, "11-8, 9-11, 11-6, –")
        XCTAssertFalse(partij.hasAllPoints)
        XCTAssertEqual(partij.linkedMatchId, "m1")
        XCTAssertEqual(partij.linkedKind, "coach")
        XCTAssertTrue(partij.isLinked)

        // Our player was player 2
        var theirs = TeamPartij(slot: 3)
        theirs.link(summary, ownIsPlayer1: false)
        XCTAssertEqual(theirs.ownPlayer, "Piet")
        XCTAssertEqual(theirs.ownGames, 1)
        XCTAssertEqual(theirs.theirGames, 3)
        XCTAssertEqual(theirs.games[0].text, "8-11")
        XCTAssertEqual(theirs.ownWon, false)

        theirs.unlink()
        XCTAssertFalse(theirs.isLinked)
        XCTAssertEqual(theirs.games.count, 4, "the games stay")

        var team = match([])
        team.update(partij)
        XCTAssertEqual(team.partijLinked(to: "m1")?.slot, 2)
        XCTAssertNil(team.partijLinked(to: "m2"))
        XCTAssertEqual(team.partij(2).ownPlayer, "Gerd-Jan")
    }

    func testRefreshingALinkKeepsOurSideAlsoWhenTheNameWasEdited() {
        let summary = MatchHistorySummary(id: "m1", kind: "coach", player1Name: "Jan de Vries", player2Name: "Piet",
                                          player1Games: 3, player2Games: 1, status: "completed",
                                          updatedAt: Date(timeIntervalSince1970: 1_793_181_600.0),
                                          games: [HistoryGameScore(player1Score: 11, player2Score: 8, winner: Player.player1.rawValue)],
                                          untrackedBefore: 0)
        var partij = TeamPartij(slot: 2)
        partij.link(summary, ownIsPlayer1: true)
        XCTAssertEqual(partij.linkedOwnIsPlayer1, true)
        // The coach corrects the name in the form; Vernieuwen must not turn the partij around
        partij.ownPlayer = "Jan"
        partij.refreshLink(from: summary)
        XCTAssertEqual(partij.ownPlayer, "Jan de Vries")
        XCTAssertEqual(partij.opponentPlayer, "Piet")
        XCTAssertEqual(partij.ownGames, 3)
        XCTAssertEqual(partij.theirGames, 1)

        // A link from before the side was stored: the name decides, ignoring case and spaces
        var old = TeamPartij(slot: 3, ownPlayer: "  piet ", opponentPlayer: "Jan de Vries", linkedMatchId: "m1", linkedKind: "coach")
        old.refreshLink(from: summary)
        XCTAssertEqual(old.ownPlayer, "Piet")
        XCTAssertEqual(old.ownGames, 1)

        old.unlink()
        XCTAssertNil(old.linkedOwnIsPlayer1)
    }

    func testAMatchInProgressIsRememberedForItsPartijUntilItIsLinked() throws {
        var team = match([])
        let id = UUID()
        team.startTracking(slot: 3, matchId: id.uuidString, ownIsPlayer1: false)
        XCTAssertEqual(team.partijTracking(matchId: id.uuidString)?.slot, 3)
        XCTAssertEqual(team.partijTracking(matchId: id.uuidString)?.trackingOwnIsPlayer1, false)
        XCTAssertNil(team.partijTracking(matchId: UUID().uuidString))

        // The names it was started with stay with the partij; the defaults stay empty
        var named = match([])
        named.startTracking(slot: 1, matchId: id.uuidString, ownIsPlayer1: true, ownPlayer: "Gerd-Jan", opponentPlayer: "Squash Delft 8 E1")
        XCTAssertEqual(named.partij(1).ownPlayer, "Gerd-Jan")
        XCTAssertEqual(named.partij(1).opponentPlayer, "")

        // Thrown away or saved as incomplete: the partij is free again
        var dropped = team
        dropped.stopTracking(matchId: id.uuidString)
        XCTAssertNil(dropped.partijTracking(matchId: id.uuidString))
        XCTAssertNil(dropped.partij(3).trackingOwnIsPlayer1)
        XCTAssertNotNil(team.partijTracking(matchId: id.uuidString), "the copy is untouched")

        // It survives the file: leaving and resuming later finds the coupling again
        let data = try JSONEncoder().encode(team)
        let back = try JSONDecoder().decode(TeamMatch.self, from: data)
        XCTAssertEqual(back.partijTracking(matchId: id.uuidString)?.slot, 3)

        // The finished match is linked and no longer "in progress"
        let coach = Match()
        coach.setupMatch(player1: "Gerd-Jan", player2: "Piet", startingServer: .player1,
                         player1CoachingFocus: [], player2CoachingFocus: [], player1GamesBefore: 0, player2GamesBefore: 0)
        var partij = team.partij(3)
        partij.link(coach: coach, ownIsPlayer1: true)
        team.update(partij)
        XCTAssertNil(team.partijTracking(matchId: id.uuidString))
        XCTAssertNil(team.partij(3).trackingOwnIsPlayer1)
    }

    func testLinkingALiveMatchTakesItsGames() {
        // Coach: one game head start for player 2, two tracked games, one filled in for player 1
        let coach = Match()
        coach.setupMatch(player1: "Gerd-Jan", player2: "Piet", startingServer: .player1,
                         player1CoachingFocus: [], player2CoachingFocus: [], player1GamesBefore: 0, player2GamesBefore: 1)
        for _ in 0..<11 { coach.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive) }
        coach.startNewGame()
        for _ in 0..<11 { coach.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive) }
        coach.startNewGame()
        XCTAssertTrue(coach.completeResult(with: [.player1]))
        var partij = TeamPartij(slot: 1)
        partij.link(coach: coach, ownIsPlayer1: true)
        XCTAssertEqual(partij.ownPlayer, "Gerd-Jan")
        XCTAssertEqual(partij.games.count, 4)
        XCTAssertEqual(partij.ownGames, 3)
        XCTAssertEqual(partij.theirGames, 1)
        XCTAssertEqual(partij.gamesText, "–, 11-0, 11-0, –")
        XCTAssertEqual(partij.linkedMatchId, coach.id.uuidString)
        XCTAssertEqual(partij.linkedKind, "coach")

        // Referee, seen from player 2
        let referee = RefereeMatch(player1Name: "Gerard", player2Name: "Thé", bestOf: 5, startingServer: .player1,
                                   player1GamesBefore: 0, player2GamesBefore: 0)
        for _ in 0..<11 { referee.awardPoint(to: Player.player2) }
        referee.confirmNextGame()
        for _ in 0..<11 { referee.awardPoint(to: Player.player1) }
        referee.confirmNextGame()
        // The third game stays on the board (no "Volgende game" after the last point)
        for _ in 0..<11 { referee.awardPoint(to: Player.player2) }
        XCTAssertTrue(referee.isGameOver)
        var theirs = TeamPartij(slot: 4)
        theirs.link(referee: referee, ownIsPlayer1: false)
        XCTAssertEqual(theirs.ownPlayer, "Thé")
        XCTAssertEqual(theirs.opponentPlayer, "Gerard")
        XCTAssertEqual(theirs.gamesText, "11-0, 0-11, 11-0")
        XCTAssertEqual(theirs.ownGames, 2)
        XCTAssertEqual(theirs.linkedKind, "referee")
    }

    private func decided() -> TeamMatch {
        match([
            partij(1, [(11, 5), (11, 7), (11, 9)]),
            partij(2, [(11, 9), (8, 11), (11, 13), (11, 4), (11, 8)]),
            partij(3, [(11, 6), (5, 11), (7, 11), (9, 11)]),
            partij(4, [(11, 9), (11, 8), (6, 11), (9, 11), (8, 11)]),
        ])
    }

    func testTheReportReadsLikeAWhatsAppMessage() {
        var team = decided()
        var text = TeamMatchReport.text(team)
        XCTAssertEqual(text, TeamMatchReport.text(team, style: MatchShareStyle.report))
        XCTAssertTrue(text.hasPrefix("🏆 *TEAMWEDSTRIJD*"), text)
        XCTAssertTrue(text.contains("👥 All Inn Squash 8 – Squash Delft 8"))
        XCTAssertTrue(text.contains("🏆 *All Inn Squash 8 wint met 9–8*"), text)
        XCTAssertTrue(text.contains("🎯 2-2 in partijen"))
        XCTAssertTrue(text.contains("Competitiepunten: All Inn Squash 8 12 · Squash Delft 8 8"))
        XCTAssertTrue(text.contains("*E1* Wij1 – Zij1 · 3-0 (11-5, 11-7, 11-9) ✅ Wij1"), text)
        XCTAssertTrue(text.contains("*E3* Wij3 – Zij3 · 1-3 (11-6, 5-11, 7-11, 9-11) ✅ Zij3"), text)
        XCTAssertTrue(text.hasSuffix("_Gescoord met Squash Analyzer_"))

        // Away: home names and scores first, so it reads like SBN
        team = match([partij(1, [(11, 5), (11, 7), (11, 9)])], ownSide: .away)
        text = TeamMatchReport.text(team)
        XCTAssertTrue(text.contains("Stand: Squash Delft 8 leidt met 3–0 · 1 van 4 partijen"), text)
        XCTAssertTrue(text.contains("*E1* Zij1 – Wij1 · 0-3 (5-11, 7-11, 9-11)"), text)
        XCTAssertTrue(text.contains("*E2* nog niet gespeeld"), text)
    }

    func testTheScorecardIsAMonospaceTable() {
        let text = TeamMatchReport.text(decided(), style: MatchShareStyle.scorecard)
        XCTAssertTrue(text.hasPrefix("🏆 *TEAM SCOREKAART*"), text)
        let blocks = text.components(separatedBy: "```")
        XCTAssertEqual(blocks.count, 3, "one code block")
        var rows: [String] = []
        for line in blocks[1].components(separatedBy: "\n") where !line.isEmpty { rows.append(line) }
        XCTAssertEqual(rows.count, 8, "two rows per partij")
        // The columns line up: every row is as long as the longest partij needs
        for row in rows { XCTAssertEqual(row.count, rows[0].count, row) }
        // E1: home player on top, games won in the last column, away player below
        XCTAssertTrue(rows[0].hasPrefix("E1 Wij1    "), rows[0])
        XCTAssertTrue(rows[0].contains("11  11  11"), rows[0])
        XCTAssertTrue(rows[0].hasSuffix("  3"), rows[0])
        XCTAssertTrue(rows[1].hasPrefix("   Zij1"), rows[1])
        XCTAssertTrue(rows[1].hasSuffix("  0"), rows[1])
        XCTAssertTrue(text.contains("🏆 *All Inn Squash 8 wint met 9–8*"))
        XCTAssertTrue(text.contains("Competitiepunten: All Inn Squash 8 12 · Squash Delft 8 8"))
        // A partij without a score still shows who won each game
        var blind = TeamPartij(slot: 1, ownPlayer: "Jan", opponentPlayer: "Piet")
        XCTAssertTrue(blind.addGame(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: true)))
        let open = TeamMatchReport.text(match([blind]), style: MatchShareStyle.scorecard)
        XCTAssertTrue(open.contains("E1 Jan "), open)
        XCTAssertTrue(open.contains("–  1"), open)
        XCTAssertTrue(open.contains("Stand: All Inn Squash 8 leidt met 1–0 · 1 van 4 partijen"), open)
    }

    func testTheShortLayoutIsThreeLines() {
        let text = TeamMatchReport.text(decided(), style: MatchShareStyle.compact)
        let lines = text.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3, text)
        XCTAssertTrue(lines[0].hasPrefix("🏆 *Teamwedstrijd · "))
        XCTAssertEqual(lines[1], "*All Inn Squash 8* 9 – 8 Squash Delft 8")
        XCTAssertEqual(lines[2], "2-2 in partijen · punten All Inn Squash 8 12 · Squash Delft 8 8")
    }

    func testThePictureShowsTheGamesAndAChipPerPartij() {
        let card = ResultCard.from(decided())
        XCTAssertEqual(card.title, "TEAMWEDSTRIJD KLAAR")
        XCTAssertEqual(card.player1Name, "All Inn Squash 8")
        XCTAssertEqual(card.player1Score, 9)
        XCTAssertEqual(card.player2Score, 8)
        XCTAssertEqual(card.winner, Player.player1)
        XCTAssertEqual(card.winnerText, "All Inn Squash 8 wint de teamwedstrijd")
        XCTAssertEqual(card.chips.count, 4)
        XCTAssertEqual(card.chips[0].label, "E1")
        XCTAssertEqual(card.chips[0].score, "3-0")
        XCTAssertEqual(card.chips[0].winner, Player.player1)
        XCTAssertEqual(card.chips[2].winner, Player.player2)

        // Away: the orange side is still home
        let away = ResultCard.from(match([partij(1, [(11, 5), (11, 7), (11, 9)])], ownSide: .away))
        XCTAssertEqual(away.title, "TUSSENSTAND")
        XCTAssertEqual(away.player1Score, 0)
        XCTAssertEqual(away.player2Score, 3)
        XCTAssertEqual(away.winner, Player.player2)
        XCTAssertEqual(away.chips[0].score, "0-3")
        XCTAssertEqual(away.chips[0].winner, Player.player2)
        XCTAssertEqual(ResultCard.from(match([])).title, "TEAMWEDSTRIJD")
    }

    func testTheTeamRosterIsAListOfIdsInTheSettings() {
        XCTAssertTrue(TeamRoster.parse("").isEmpty)
        XCTAssertEqual(TeamRoster.parse("a, b,,a"), ["a", "b"])
        var raw = ""
        raw = TeamRoster.setting("p1", inTeam: true, in: raw)
        raw = TeamRoster.setting("p2", inTeam: true, in: raw)
        raw = TeamRoster.setting("p1", inTeam: true, in: raw)
        XCTAssertEqual(raw, "p1,p2")
        XCTAssertTrue(TeamRoster.contains("p2", in: raw))
        raw = TeamRoster.setting("p1", inTeam: false, in: raw)
        XCTAssertEqual(TeamRoster.parse(raw), ["p2"])
        XCTAssertFalse(TeamRoster.contains("p1", in: raw))
    }

    @MainActor
    func testTeamMatchesAndTeamPlayersTravelInTheBackup() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("teambackup-\(UUID().uuidString)")
        let store = JSONFileTeamMatchStore(directory: folder)
        let team = decided()
        try await store.save(team)
        let defaults = UserDefaults.standard
        let before = defaults.string(forKey: TeamRoster.storageKey)
        TeamRoster.replace(["p1", "p2"])

        let plain = FullBackup(version: 2, backupDate: Date(timeIntervalSince1970: 1_793_181_600.0), players: [], matches: [], standaloneGames: [])
        XCTAssertEqual(BackupCodec.formatVersion(for: plain), 2, "without team data an older app can still read it")
        let attached = TeamBackup.attach(plain, directory: folder)
        XCTAssertEqual(attached.teamMatches?.count, 1)
        XCTAssertEqual(attached.teamPlayerIds, ["p1", "p2"])
        XCTAssertEqual(BackupCodec.formatVersion(for: attached), 4)

        // Through the file and back: the checksum holds and the match is intact
        let data = try BackupCodec.encode(attached, appVersion: "test")
        let decoded = try BackupCodec.decode(data)
        XCTAssertEqual(decoded.teamMatches, [team])
        XCTAssertEqual(decoded.teamPlayerIds, ["p1", "p2"])

        // Restore onto a clean phone
        let other = FileManager.default.temporaryDirectory.appendingPathComponent("teambackup-\(UUID().uuidString)")
        TeamRoster.replace(["x"])
        try TeamBackup.restore(decoded, directory: other, replacing: false)
        XCTAssertEqual(TeamMatchFile.read(in: other), [team])
        XCTAssertEqual(TeamRoster.ids(), ["x", "p1", "p2"], "merging keeps what was there")

        // Merging the same file again adds nothing; a newer edit on the phone wins
        var edited = team
        edited.updatedAt = Date(timeIntervalSince1970: 1_893_181_600.0)
        edited.home = "Bewerkt"
        try TeamMatchFile.write([edited], in: other)
        try TeamBackup.restore(decoded, directory: other, replacing: false)
        XCTAssertEqual(TeamMatchFile.read(in: other).count, 1)
        XCTAssertEqual(TeamMatchFile.read(in: other)[0].home, "Bewerkt")

        // Replacing swaps both for the file's; a file without team data wipes nothing
        try TeamBackup.restore(decoded, directory: other, replacing: true)
        XCTAssertEqual(TeamMatchFile.read(in: other), [team])
        XCTAssertEqual(TeamRoster.ids(), ["p1", "p2"])
        try TeamBackup.restore(plain, directory: other, replacing: true)
        XCTAssertEqual(TeamMatchFile.read(in: other).count, 1)
        XCTAssertEqual(TeamRoster.ids(), ["p1", "p2"])

        if let before { defaults.set(before, forKey: TeamRoster.storageKey) } else { defaults.removeObject(forKey: TeamRoster.storageKey) }
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.removeItem(at: other)
    }

    @MainActor
    func testATruncatedTeamFileIsSetAsideAndNeverOverwritten() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("teamfile-\(UUID().uuidString)")
        let store = JSONFileTeamMatchStore(directory: folder)
        try await store.save(decided())
        let url = folder.appendingPathComponent(TeamMatchFile.fileName)
        let whole = try Data(contentsOf: url)
        // A kill halfway: half a file
        try whole.subdata(in: 0..<(whole.count / 2)).write(to: url)

        do {
            _ = try await store.loadAll()
            XCTFail("an unreadable file must be reported, not read as empty")
        } catch let error as TeamMatchFileError {
            guard case .unreadable(let savedAs) = error else { return XCTFail("wrong error") }
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(savedAs).path),
                          "what was in the file is kept under another name")
        }
        // The next save starts a clean file and does not wipe the set-aside one
        try await store.save(match([]))
        let again = try await store.loadAll()
        XCTAssertEqual(again.count, 1)
        try? FileManager.default.removeItem(at: folder)
    }

    func testTheFileHoldsAVersionAndStillReadsTheFirstFormat() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("teamfile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let team = decided()
        try TeamMatchFile.write([team], in: folder)
        let text = String(data: try Data(contentsOf: folder.appendingPathComponent(TeamMatchFile.fileName)), encoding: String.Encoding.utf8) ?? ""
        XCTAssertTrue(text.contains("\"version\""), "an envelope with a version")
        XCTAssertEqual(try TeamMatchFile.load(in: folder), [team])

        // The first builds wrote a bare array: still read
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([team]).write(to: folder.appendingPathComponent(TeamMatchFile.fileName))
        XCTAssertEqual(try TeamMatchFile.load(in: folder), [team])
        try? FileManager.default.removeItem(at: folder)
    }

    func testAFileWithTooFewOrDoubledSlotsIsMadeFourAgain() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("teamfile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var odd = decided()
        odd.partijen = [odd.partijen[0], odd.partijen[0], odd.partijen[2]]
        try TeamMatchFile.write([odd], in: folder)
        let read = try TeamMatchFile.load(in: folder)
        XCTAssertEqual(read[0].partijen.map { partij in partij.slot }, [1, 2, 3, 4])
        var team = read[0]
        team.update(partij(4, [(11, 1), (11, 2), (11, 3)]))
        XCTAssertEqual(team.partijen.count, 4, "an update does not append a fifth slot")
        try? FileManager.default.removeItem(at: folder)
    }

    func testARestoreThatCannotWriteTheTeamFileFails() throws {
        // A "folder" that is a file: nothing can be written there
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("notafolder-\(UUID().uuidString)")
        try Data("x".utf8).write(to: file)
        var backup = FullBackup(version: 2, backupDate: Date(), players: [], matches: [], standaloneGames: [])
        backup.teamMatches = [decided()]
        do {
            try TeamBackup.restore(backup, directory: file, replacing: false)
            XCTFail("a team file that cannot be written must fail the restore")
        } catch {
            // expected
        }
        try? FileManager.default.removeItem(at: file)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("teamfile-\(UUID().uuidString)")
        XCTAssertEqual(try TeamBackup.restore(backup, directory: folder, replacing: false), 1, "the count of added team matches")
        XCTAssertEqual(try TeamBackup.restore(backup, directory: folder, replacing: false), 0, "the same file adds nothing")
        XCTAssertEqual(BackupCounts(players: 0, matches: 0, games: 0, badges: 0, teamMatches: 2).summary,
                       "0 spelers, 0 wedstrijden, 0 games, 0 badges, 2 teamwedstrijden")
        try? FileManager.default.removeItem(at: folder)
    }

    @MainActor
    func testTheFileStoreKeepsMatchesNewestFirst() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("teammatch-\(UUID().uuidString)")
        let store = JSONFileTeamMatchStore(directory: folder)
        let empty = try await store.loadAll()
        XCTAssertTrue(empty.isEmpty)

        let older = TeamMatch(date: Date(timeIntervalSince1970: 1_793_181_600.0), home: "A", away: "B", ownSide: .home)
        var newer = TeamMatch(date: Date(timeIntervalSince1970: 1_793_786_400.0), home: "C", away: "D", ownSide: .away)
        try await store.save(older)
        try await store.save(newer)
        var all = try await store.loadAll()
        XCTAssertEqual(all.map { match in match.home }, ["C", "A"])

        newer.update(partij(1, [(11, 3), (11, 4), (11, 5)]))
        try await store.save(newer)
        all = try await store.loadAll()
        XCTAssertEqual(all.count, 2, "saving again replaces")
        XCTAssertEqual(all[0].score.ownGames, 3)
        XCTAssertEqual(all[0].ownSide, TeamSide.away)
        XCTAssertEqual(all[0].partij(1).gamesText, "11-3, 11-4, 11-5")

        try await store.delete(id: older.id)
        all = try await store.loadAll()
        XCTAssertEqual(all.map { match in match.home }, ["C"])

        // A second store on the same folder reads the same file
        let again = try await JSONFileTeamMatchStore(directory: folder).loadAll()
        XCTAssertEqual(again, all)
        try? FileManager.default.removeItem(at: folder)
    }
}
