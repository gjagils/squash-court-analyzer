import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The SBN team-match page (the back-up for a live page that is gone), in
/// the shape sbn.toernooi.nl had on 1 November 2026, with made-up names
final class LeagueTeamMatchTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    private func partij(_ slot: Int, _ home: String, _ away: String, games: [[Int]], homeWon: Bool?) -> String {
        var rows = ""
        for (index, name) in [home, away].enumerated() {
            let won = homeWon == nil ? "" : ((index == 0) == homeWon! ? " has-won" : "")
            rows += """
            <div class="match__row\(won)"> <div class="match__row-title"> <div class="match__row-title-header">\(index == 0 ? "SC Hugo 1" : "Rivalen 2")</div>
            <div class="match__row-title-value"> <span class="match__row-title-value-content">
            <a href="/league/x/player/\(index)" class="nav-link"><span class="nav-link__value">\(name)</span></a> </span> </div> </div>
            \(index == 0 && homeWon == true ? "<span class=\"tag match__status\">W</span>" : "")</div>
            """
        }
        var points = ""
        for game in games {
            points += "<ul class=\"points\"> <li class=\"points__cell points__cell--won\"> \(game[0]) </li> <li class=\"points__cell \"> \(game[1]) </li> </ul>"
        }
        return """
        <li class="match-group__item"> <div class="match"> <div class="match__header"> <ul class="match__header-title">
        <li class="match__header-title-item"> <span title="E\(slot)" class="nav-link"><span class="nav-link__value">E\(slot)</span></span> </li> </ul> </div>
        <div class="match__body"> <div class="match__row-wrapper"> \(rows) </div>
        <div class="match__result"> \(points) </div>
        <div class="match__btn"> <a class="btn nav-link match__btn-h2h" href="/head-2-head?x=1"> <span class="nav-link__value">H2H</span></a></div>
        </div> </div> </li>
        """
    }

    private var playedPage: String {
        "<h4 class=\"module__title\">Partijen</h4><ul class=\"match-group\">"
            + partij(1, "Niels de G", "Andr&#233; S", games: [[11, 8], [11, 7], [11, 9]], homeWon: true)
            + partij(2, "Gerd-Jan", "Olegs", games: [[11, 5], [11, 3], [11, 3]], homeWon: true)
            + partij(3, "Niels van S", "Jo&#227;o", games: [[12, 10], [11, 5], [11, 9]], homeWon: true)
            + partij(4, "Paul", "Alexander", games: [[9, 11], [11, 2], [11, 8], [10, 12], [11, 3]], homeWon: true)
            + "</ul>"
    }

    func testReadsEveryPartijWithPlayersWinnerAndGames() throws {
        let result = try LeagueTeamMatchParser.parse(playedPage)
        XCTAssertEqual(result.home, "SC Hugo 1")
        XCTAssertEqual(result.away, "Rivalen 2")
        XCTAssertEqual(result.partijen.count, 4)
        XCTAssertTrue(result.hasResult)
        let third = try XCTUnwrap(result.partij(slot: 3))
        XCTAssertEqual(third.homePlayer, "Niels van S")
        XCTAssertEqual(third.awayPlayer, "João")
        XCTAssertEqual(third.games, [[12, 10], [11, 5], [11, 9]])
        XCTAssertEqual(third.homeWon, true)
        XCTAssertEqual(result.partij(slot: 4)?.games.count, 5)
    }

    func testAPageWithoutAResultYetIsPending() throws {
        let page = "<ul class=\"match-group\">" + partij(1, "Niels de G", "Andr&#233; S", games: [], homeWon: nil) + "</ul>"
        let result = try LeagueTeamMatchParser.parse(page)
        XCTAssertFalse(result.hasResult)
        XCTAssertNil(result.partij(slot: 1)?.homeWon)
    }

    /// The error `body` throws, or nil (SkipTest has no XCTAssertThrowsError)
    private func thrown(_ body: () throws -> Void) -> Error? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// "11-8", "11-7", … of a partij's games
    private func texts(_ games: [TeamGame]) -> [String] {
        var result: [String] = []
        for game in games { result.append(game.text) }
        return result
    }

    func testAnotherPageIsReportedNotGuessed() {
        XCTAssertNotNil(thrown { _ = try LeagueTeamMatchParser.parse("<html><body><h1>Cookies</h1></body></html>") })
    }

    func testFillsEmptyPartijenAndTheUnknownPointsOfOwnOnes() throws {
        let result = try LeagueTeamMatchParser.parse(playedPage)
        var match = TeamMatch(date: Date(), home: "SC Hugo 1", away: "Rivalen 2", ownSide: .home)
        // E2 tracked after joining late: two games without points, the last with
        var own = TeamPartij(slot: 2, ownPlayer: "Gerd-Jan", opponentPlayer: "Olegs",
                             games: [TeamGame(ownPoints: nil, theirPoints: nil, ownWon: true),
                                     TeamGame(ownPoints: nil, theirPoints: nil, ownWon: true),
                                     TeamGame(own: 11, their: 3)])
        own.fromLive = true
        match.update(own)
        // E4 says something else than SBN: reported, not changed
        match.update(TeamPartij(slot: 4, ownPlayer: "Paul", opponentPlayer: "Alexander",
                                games: [TeamGame(own: 11, their: 9), TeamGame(own: 11, their: 2), TeamGame(own: 11, their: 8)]))
        let outcome = match.fill(fromSBN: result)
        XCTAssertEqual(outcome.filled, [1, 3])
        XCTAssertEqual(outcome.completed, [2])
        XCTAssertEqual(outcome.differences.count, 1)
        XCTAssertTrue(outcome.differences[0].hasPrefix("E4: SBN 3-2"))
        XCTAssertEqual(match.partij(1).ownPlayer, "Niels de G")
        XCTAssertEqual(match.partij(1).opponentPlayer, "André S")
        XCTAssertEqual(texts(match.partij(1).games), ["11-8", "11-7", "11-9"])
        XCTAssertEqual(match.partij(1).fromSBN, true)
        XCTAssertEqual(texts(match.partij(2).games), ["11-5", "11-3", "11-3"])
        XCTAssertEqual(match.partij(4).games.count, 3, "the phone's own result stays")
        XCTAssertTrue(match.isComplete)
        XCTAssertFalse(match.hasUnknownPoints)
    }

    func testAnAwayMatchIsSeenFromOurSide() throws {
        let result = try LeagueTeamMatchParser.parse(playedPage)
        let fixture = LeagueFixture(id: "1074", date: Date(), home: "SC Hugo 1", away: "Rivalen 2", score: "12 - 2",
                                    url: URL(string: "https://sbn.toernooi.nl/league/x/team-match/1074")!)
        let match = TeamMatch.from(fixture: fixture, ownTeam: "Rivalen 2", sbn: result)
        XCTAssertEqual(match.ownSide, TeamSide.away)
        XCTAssertEqual(match.partij(1).ownPlayer, "André S")
        XCTAssertEqual(match.partij(1).games[0].text, "8-11")
        XCTAssertFalse(match.partij(1).games[0].ownWon)
        XCTAssertEqual(match.score.ownPartijen, 0)
    }

    func testAutoLinksAFinishedMatchOfTheSameEveningToAnEmptyPartij() {
        let evening = Date(timeIntervalSince1970: 1_793_181_600.0)
        var match = TeamMatch(date: evening, home: "SC Hugo 1", away: "Rivalen 2", ownSide: .home)
        match.update(TeamPartij(slot: 3, ownPlayer: "Niels van Sevenhoven", opponentPlayer: "joao"))
        match.update(TeamPartij(slot: 1, ownPlayer: "Niels de Groot", opponentPlayer: ""))
        let shared = MatchHistorySummary(id: "m3", kind: "referee", player1Name: "Niels van Sevenhoven", player2Name: "João",
                                         player1Games: 3, player2Games: 0, status: "completed",
                                         updatedAt: evening.addingTimeInterval(2 * 3600.0), games: [HistoryGameScore(player1Score: 11, player2Score: 5, winner: Player.player1.rawValue),
                                                 HistoryGameScore(player1Score: 11, player2Score: 9, winner: Player.player1.rawValue)],
                                         untrackedBefore: 1, untrackedAfter: 0, bestOf: 5)
        let other = MatchHistorySummary(id: "old", kind: "coach", player1Name: "Niels de Groot", player2Name: "Someone",
                                        player1Games: 3, player2Games: 1, status: "completed",
                                        updatedAt: evening.addingTimeInterval(-5 * 24 * 3600.0), games: [], untrackedBefore: 0, untrackedAfter: 0, bestOf: 5)
        let linked = TeamMatchSupport.autoLink(&match, history: [other, shared], now: evening)
        XCTAssertEqual(linked, [3])
        XCTAssertEqual(match.partij(3).linkedMatchId, "m3")
        XCTAssertEqual(match.partij(3).ownGames, 3)
        XCTAssertFalse(match.partij(1).hasEntry, "a match of another evening is not taken")
        // Again: nothing more to link
        XCTAssertTrue(TeamMatchSupport.autoLink(&match, history: [other, shared], now: evening).isEmpty)
    }
}
