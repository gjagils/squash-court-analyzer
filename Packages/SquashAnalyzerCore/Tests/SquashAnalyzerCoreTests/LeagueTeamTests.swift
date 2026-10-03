import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// Pages are hand-written in the shape the parser expects from sbn.toernooi.nl
/// (the markers it looks for), so these run offline on Darwin and Android.
final class LeagueTeamTests: XCTestCase {
    private let league = "0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2"
    private var teamURL: String { "https://sbn.toernooi.nl/league/\(league)/team/113" }

    private var teamPage: String {
        """
        <div class="hgroup"><h2 class="hgroup__heading">SC Hugo 1</h2>
        <p class="hgroup__subheading">Competitie 2026-2027</p></div>
        <a class="nav" href="/league/\(league)/draw/7">3e divisie &amp; B</a>
        <div class="stats"><span class="stats__title">Stand</span> <span class="stats__value">2</span>
        <span class="stats__title">Gespeeld</span><span class="stats__value is-big">4</span>
        <span class="stats__title">Punten</span><span class="stats__value">15</span></div>
        <a class="team-match__wrapper" href="/league/\(league)/team-match/200"><time datetime="2026-10-12 20:00">12 okt</time>
          <div class="team-match__name is-home">SC Hugo 1</div><div class="team-match__name">Ja&#239;r &amp; Co</div>
          <div class="score is-not-played">-</div></a>
        <a class="team-match__wrapper" href="/league/\(league)/team-match/100"><time datetime="2026-09-20 19:30">20 sep</time>
          <div class="team-match__name">Rivalen 2</div><div class="team-match__name">SC Hugo 1</div>
          <div class="score">1 - 3</div></a>
        <ul><li class="list__item"><a href="/league/\(league)/player/5">Paul St&#233;enks</a><span class="pull-right">3-1</span></li>
        <li class="list__item"><a href="/league/\(league)/player/6">Hugo &#x1F3BE;</a><span class="pull-right">2-2</span></li>
        <li class="list__item"><a href="/league/\(league)/player/5">Paul St&#233;enks</a><span class="pull-right">3-1</span></li></ul>
        """
    }

    private var drawPage: String {
        """
        <table><tr><th>#</th><th>Team</th></tr>
        <tr><td><span class="standing-status">1</span></td><td>4</td><td>3</td><td>0</td><td>1</td><td>12</td><td>4</td><td>8</td><td>16</td>
          <td><a href="/league/\(league)/team/99">Rivalen 2</a></td></tr>
        <tr><td><span class="standing-status">2</span></td><td>4</td><td>3</td><td>0</td><td>1</td><td>11</td><td>5</td><td>6</td><td>15</td>
          <td><a href="/league/\(league.lowercased())/team/113">SC Hugo 1</a></td></tr></table>
        """
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

    // MARK: Links

    func testAcceptsATeamLink() throws {
        let link = try LeagueTeamLink("  HTTPS://SBN.toernooi.nl/league/\(league.lowercased())/team/113/ \n")
        XCTAssertEqual(link.leagueID, league)
        XCTAssertEqual(link.teamID, "113")
        XCTAssertEqual(link.url.absoluteString, teamURL)
    }

    func testRejectsOtherLinks() {
        let bad = [
            "http://sbn.toernooi.nl/league/\(league)/team/113",
            "https://example.com/league/\(league)/team/113",
            "https://sbn.toernooi.nl:8443/league/\(league)/team/113",
            "https://user@sbn.toernooi.nl/league/\(league)/team/113",
            "https://sbn.toernooi.nl/league/\(league)/team/113?x=1",
            "https://sbn.toernooi.nl/league/\(league)/team/113#top",
            "https://sbn.toernooi.nl/league/not-a-uuid/team/113",
            "https://sbn.toernooi.nl/league/\(league)/team/abc",
            "https://sbn.toernooi.nl/league/\(league)/draw/113",
            "",
        ]
        for value in bad {
            let error = thrown { _ = try LeagueTeamLink(value) }
            XCTAssertEqual(error as? LeagueTeamError, LeagueTeamError.invalidLink, value)
        }
    }

    // MARK: Parsing

    func testReadsTheTeamPage() throws {
        let link = try LeagueTeamLink(teamURL)
        let parsed = try LeagueTeamParser.team(teamPage, link: link)
        let team = parsed.snapshot
        let draw = parsed.draw
        XCTAssertEqual(team.name, "SC Hugo 1")
        XCTAssertEqual(team.competition, "Competitie 2026-2027")
        XCTAssertEqual(team.division, "3e divisie & B")
        XCTAssertEqual(team.rank, 2)
        XCTAssertEqual(team.played, 4)
        XCTAssertEqual(team.points, 15)
        XCTAssertEqual(draw.absoluteString, "https://sbn.toernooi.nl/league/\(league)/draw/7")

        // Sorted by date; a match not played yet has no score
        XCTAssertEqual(team.fixtures.count, 2)
        XCTAssertEqual(team.fixtures[0].home, "Rivalen 2")
        XCTAssertEqual(team.fixtures[0].score, "1 - 3")
        XCTAssertEqual(team.fixtures[1].away, "Jaïr & Co")
        XCTAssertNil(team.fixtures[1].score)
        XCTAssertEqual(team.fixtures[1].url.absoluteString, "https://sbn.toernooi.nl/league/\(league)/team-match/200")
        // 2026-10-12 20:00 in Amsterdam (summer time) is 18:00 UTC
        XCTAssertEqual(team.fixtures[1].date.timeIntervalSince1970, 1_791_828_000)

        // Duplicates dropped, entities decoded, including one outside the BMP
        XCTAssertEqual(team.players.count, 2)
        XCTAssertEqual(team.players[0].name, "Paul Stéenks")
        XCTAssertEqual(team.players[0].record, "3-1")
        XCTAssertEqual(team.players[1].name, "Hugo 🎾")
    }

    func testReadsTheStandings() throws {
        let rows = try LeagueTeamParser.standings(drawPage)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1].rank, 2)
        XCTAssertEqual(rows[1].name, "SC Hugo 1")
        XCTAssertEqual(rows[1].played, 4)
        XCTAssertEqual(rows[1].won, 3)
        XCTAssertEqual(rows[1].lost, 1)
        XCTAssertEqual(rows[1].points, 15)
    }

    func testAChangedPageIsReportedNotGuessed() throws {
        let link = try LeagueTeamLink(teamURL)
        let teamError = thrown { _ = try LeagueTeamParser.team("<html>Onderhoud</html>", link: link) }
        XCTAssertEqual(teamError as? LeagueTeamError, LeagueTeamError.changedPage)
        let standingsError = thrown { _ = try LeagueTeamParser.standings("<table></table>") }
        XCTAssertEqual(standingsError as? LeagueTeamError, LeagueTeamError.changedPage)
    }

    func testNextFixtureIsTheFirstNotYetPlayed() throws {
        let team = try LeagueTeamParser.team(teamPage, link: try LeagueTeamLink(teamURL)).snapshot
        XCTAssertEqual(team.nextFixture(after: Date(timeIntervalSince1970: 1_790_000_000))?.home, "SC Hugo 1")
        XCTAssertNil(team.nextFixture(after: Date(timeIntervalSince1970: 1_800_000_000)))
    }

    func testSnapshotSurvivesTheCache() throws {
        var team = try LeagueTeamParser.team(teamPage, link: try LeagueTeamLink(teamURL)).snapshot
        team.standings = try LeagueTeamParser.standings(drawPage)
        let data = try JSONEncoder().encode(team)
        let decoded = try JSONDecoder().decode(LeagueTeamSnapshot.self, from: data)
        XCTAssertEqual(decoded.name, team.name)
        XCTAssertEqual(decoded.fixtures, team.fixtures)
        XCTAssertEqual(decoded.standings, team.standings)
        XCTAssertEqual(decoded.players, team.players)
    }

    func testCacheOnlyAnswersForTheSameTeam() throws {
        let defaults = UserDefaults(suiteName: "league-team-tests")!
        defaults.removeObject(forKey: "sbnTeamSnapshot")
        let link = try LeagueTeamLink(teamURL)
        let team = try LeagueTeamParser.team(teamPage, link: link).snapshot
        XCTAssertNil(LeagueTeamStorage.cachedSnapshot(for: link, in: defaults))
        LeagueTeamStorage.store(team, in: defaults)
        XCTAssertEqual(LeagueTeamStorage.cachedSnapshot(for: link, in: defaults)?.name, "SC Hugo 1")
        let other = try LeagueTeamLink("https://sbn.toernooi.nl/league/\(league)/team/114")
        XCTAssertNil(LeagueTeamStorage.cachedSnapshot(for: other, in: defaults))
    }

    // MARK: Fetching

    func testFetchAnswersTheCookieWallAndChecksTheTeamIsInTheStandings() async throws {
        let wall = URL(string: "https://sbn.toernooi.nl/cookiewall?ReturnUrl=%2Fleague")!
        let loader = FakeLoader(pages: [
            LeaguePage(finalURL: wall, status: 200, body: "<form action=\"/cookiewall/Save\">", byteCount: 40),
            LeaguePage(finalURL: URL(string: teamURL)!, status: 200, body: teamPage, byteCount: 3000),
            LeaguePage(finalURL: URL(string: "https://sbn.toernooi.nl/league/\(league)/draw/7")!, status: 200, body: drawPage, byteCount: 900),
        ])
        let team = try await LeagueTeamFetcher(loader: loader).fetch(try LeagueTeamLink(teamURL))
        XCTAssertEqual(team.name, "SC Hugo 1")
        XCTAssertEqual(team.standings.count, 2)
        XCTAssertEqual(loader.requests, [
            "GET \(teamURL)",
            "POST https://sbn.toernooi.nl/cookiewall/Save ReturnUrl=/league/\(league)/team/113&SettingsOpen=true&CookiePurposes=1",
            "GET https://sbn.toernooi.nl/league/\(league)/draw/7",
        ])
    }

    func testFailuresBecomeUnavailable() async throws {
        let link = try LeagueTeamLink(teamURL)
        let cases: [FakeLoader] = [
            // Server error
            FakeLoader(pages: [LeaguePage(finalURL: URL(string: teamURL)!, status: 500, body: "", byteCount: 0)]),
            // Still the cookie wall after consenting
            FakeLoader(pages: [
                LeaguePage(finalURL: URL(string: "https://sbn.toernooi.nl/cookiewall")!, status: 200, body: "/cookiewall/Save", byteCount: 20),
                LeaguePage(finalURL: URL(string: teamURL)!, status: 200, body: "<form action=\"/cookiewall/Save\">", byteCount: 40),
            ]),
            // Redirected to another host
            FakeLoader(pages: [LeaguePage(finalURL: URL(string: "https://example.com/")!, status: 200, body: teamPage, byteCount: 3000)]),
            // No connection
            FakeLoader(pages: []),
        ]
        for loader in cases {
            do {
                _ = try await LeagueTeamFetcher(loader: loader).fetch(link)
                XCTFail("expected an error")
            } catch {
                XCTAssertEqual(error as? LeagueTeamError, LeagueTeamError.unavailable)
            }
        }
    }

    func testTheTeamMustBeInItsOwnStandings() async throws {
        let otherDraw = drawPage.replacingOccurrences(of: "/team/113", with: "/team/114")
        let loader = FakeLoader(pages: [
            LeaguePage(finalURL: URL(string: teamURL)!, status: 200, body: teamPage, byteCount: 3000),
            LeaguePage(finalURL: URL(string: "https://sbn.toernooi.nl/league/\(league)/draw/7")!, status: 200, body: otherDraw, byteCount: 900),
        ])
        do {
            _ = try await LeagueTeamFetcher(loader: loader).fetch(try LeagueTeamLink(teamURL))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? LeagueTeamError, LeagueTeamError.changedPage)
        }
    }
}

/// Answers requests with the given pages in order and records them;
/// throws (like a lost connection) when it runs out.
final class FakeLoader: LeaguePageLoader, @unchecked Sendable {
    private var pages: [LeaguePage]
    var requests: [String] = []

    init(pages: [LeaguePage]) {
        self.pages = pages
    }

    func get(_ url: URL) async throws -> LeaguePage {
        requests.append("GET \(url.absoluteString)")
        return try next()
    }

    func postForm(_ url: URL, body: String) async throws -> LeaguePage {
        requests.append("POST \(url.absoluteString) \(body)")
        return try next()
    }

    private func next() throws -> LeaguePage {
        guard !pages.isEmpty else { throw URLError(.notConnectedToInternet) }
        return pages.removeFirst()
    }
}
