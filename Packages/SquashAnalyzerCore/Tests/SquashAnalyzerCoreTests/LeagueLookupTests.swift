import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// Club search, a club's teams and the opponent's players, on pages written
/// in the shape sbn.toernooi.nl answers (checked on 31 October 2026).
final class LeagueLookupTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    private let league = LeagueSeason.leagueID
    private var base: String { "https://sbn.toernooi.nl/league/\(league)" }

    private var searchPage: String {
        """
        <div class="search__dropdown-results js-asg-results"><ul class="list list--bordered">
        <li class="list__item list__item--selectable js-asg-result-item" data-asg-title="All Inn Squash" data-asg-value="2" data-asg-href="/league/\(league)/club/2" data-asg-type="Player">
          <h4 class="media__title"><span class="media__link"><span class="nav-link__value">All Inn Squash</span></span></h4>
          <span class="media__subheading">Utrecht | NED</span></li>
        <li class="list__item list__item--selectable js-asg-result-item" data-asg-title="Squash &amp; Co" data-asg-value="7" data-asg-href="/league/\(league)/club/7" data-asg-type="Player">
          <span class="media__subheading">Delft | NED</span></li>
        <li class="list__item list__item--selectable js-asg-result-item" data-asg-title="Iemand" data-asg-href="/player/12"></li>
        </ul></div>
        """
    }

    private var teamsPage: String {
        """
        <h4 class="module-divider">Dames</h4><ul class="list">
        <li class="list__item"><div class="flex-container"><span class="tag">Dames – Tweede Divisie – Afdeling 1</span>
          <div class="media no-padding"><div class="media__wrapper"><div class="media__content"><h5 class="media__title">
          <a class="media__link nav-link" href="/league/\(league)/team/184"><span class="nav-link__value">All Inn Squash Dames 1</span></a></h5></div></div></div></div></li>
        </ul><h4 class="module-divider">Gemengd</h4><ul class="list">
        <li class="list__item"><span class="tag">Gemengd – Derde Divisie – Afdeling 4</span>
          <h5 class="media__title"><a class="media__link nav-link" href="/league/\(league)/team/113"><span class="nav-link__value">All Inn Squash 8</span></a></h5></li>
        <li class="list__item"><a class="media__link nav-link" href="/league/0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2/team/5"><span class="nav-link__value">Vorig seizoen</span></a></li>
        </ul>
        """
    }

    func testClubsComeFromTheSearch() {
        let clubs = LeagueTeamParser.clubs(searchPage)
        XCTAssertEqual(clubs, [LeagueClub(id: "2", name: "All Inn Squash", place: "Utrecht"),
                               LeagueClub(id: "7", name: "Squash & Co", place: "Delft")])
    }

    func testTeamsOfThisSeasonOnly() {
        let teams = LeagueTeamParser.clubTeams(teamsPage)
        XCTAssertEqual(teams.map { team in team.name }, ["All Inn Squash Dames 1", "All Inn Squash 8"])
        XCTAssertEqual(teams[1].division, "Gemengd – Derde Divisie – Afdeling 4")
        XCTAssertEqual(teams[1].link.url.absoluteString, "\(base)/team/113")
    }

    func testTheSearchIsAPlainFormValue() {
        XCTAssertEqual(LeagueTeamFetcher.searchBody("  All Inn é?&=x "), "Query=All+Inn+x")
    }

    func testSearchAndTeamsGoThroughTheCookieWall() async throws {
        let wall = URL(string: "https://sbn.toernooi.nl/cookiewall")!
        let loader = FakeLoader(pages: [
            LeaguePage(finalURL: wall, status: 200, body: "<form action=\"/cookiewall/Save\">", byteCount: 40),
            LeaguePage(finalURL: URL(string: base)!, status: 200, body: "<h2>Competitie</h2>", byteCount: 20),
            LeaguePage(finalURL: URL(string: "\(base)/LeagueHome/DoSearch")!, status: 200, body: searchPage, byteCount: 900),
            LeaguePage(finalURL: URL(string: "\(base)/club/2/GetTabContent/teams")!, status: 200, body: teamsPage, byteCount: 900),
        ])
        let fetcher = LeagueTeamFetcher(loader: loader)
        let clubs = try await fetcher.searchClubs("All Inn")
        XCTAssertEqual(clubs.count, 2)
        let teams = try await fetcher.teams(of: clubs[0])
        XCTAssertEqual(teams.count, 2)
        XCTAssertEqual(loader.requests, [
            "POST \(base)/LeagueHome/DoSearch Query=All+Inn",
            "POST https://sbn.toernooi.nl/cookiewall/Save ReturnUrl=/league/\(league)/LeagueHome/DoSearch&SettingsOpen=true&CookiePurposes=1",
            "POST \(base)/LeagueHome/DoSearch Query=All+Inn",
            "PART \(base)/club/2/GetTabContent/teams",
        ])
    }

    func testAShortSearchAsksNothing() async throws {
        let loader = FakeLoader(pages: [])
        let clubs = try await LeagueTeamFetcher(loader: loader).searchClubs(" a? ")
        XCTAssertTrue(clubs.isEmpty)
        XCTAssertTrue(loader.requests.isEmpty)
    }

    // MARK: The opponent

    private func snapshot() -> LeagueTeamSnapshot {
        let fixture = LeagueFixture(id: "/league/\(league)/team-match/200", date: Date(), home: "Squash Delft 8",
                                    away: "All Inn Squash 8", score: nil, url: URL(string: "\(base)/team-match/200")!)
        let cup = LeagueFixture(id: "/league/\(league)/team-match/300", date: Date(), home: "All Inn Squash 8",
                                away: "Bekerteam", score: nil, url: URL(string: "\(base)/team-match/300")!)
        return LeagueTeamSnapshot(source: URL(string: "\(base)/team/113")!, name: "All Inn Squash 8", competition: "", division: "",
                                  rank: nil, played: nil, points: nil, fixtures: [fixture, cup], players: [],
                                  standings: [LeagueStanding(id: "/league/\(league)/team/113", rank: 1, name: "All Inn Squash 8", played: 1, won: 1, lost: 0, points: 8),
                                              LeagueStanding(id: "/league/\(league)/team/120", rank: 2, name: "squash delft 8 ", played: 1, won: 0, lost: 1, points: 2)])
    }

    func testTheOpponentIsFoundInThePoule() {
        let team = snapshot()
        XCTAssertEqual(LeagueOpponent.link(for: team.fixtures[0], in: team)?.url.absoluteString, "\(base)/team/120")
        XCTAssertNil(LeagueOpponent.link(for: team.fixtures[1], in: team), "not in the poule")
        let match = TeamMatch.from(fixture: team.fixtures[0], ownTeam: team.name)
        XCTAssertEqual(LeagueOpponent.link(for: match, in: team)?.url.absoluteString, "\(base)/team/120")
        XCTAssertNil(LeagueOpponent.link(for: match, in: nil))
    }

    func testOpponentNamesAreKeptForADay() async throws {
        let defaults = UserDefaults(suiteName: "opponents-\(UUID().uuidString)")!
        let link = try LeagueTeamLink("\(base)/team/120")
        let page = """
        <h2 class="hgroup__heading">Squash Delft 8</h2>
        <a href="/league/\(league)/draw/7">Derde divisie</a>
        <ul><li class="list__item"><a href="/league/\(league)/player/5">Bas de Wit</a><span class="pull-right">1-0</span></li>
        <li class="list__item"><a href="/league/\(league)/player/6">Kees Vos</a><span class="pull-right">0-1</span></li></ul>
        """
        let loader = FakeLoader(pages: [LeaguePage(finalURL: link.url, status: 200, body: page, byteCount: 600)])
        let fetcher = LeagueTeamFetcher(loader: loader)
        let now = Date()
        let names = await LeagueOpponentStorage.names(for: link, fetcher: fetcher, in: defaults, now: now)
        XCTAssertEqual(names, ["Bas de Wit", "Kees Vos"])
        // Within a day: from the phone, no request (the loader has no pages left)
        let again = await LeagueOpponentStorage.names(for: link, fetcher: fetcher, in: defaults, now: now.addingTimeInterval(3600.0))
        XCTAssertEqual(again, names)
        XCTAssertEqual(loader.requests.count, 1)
        // Later and offline: still the saved names
        let offline = await LeagueOpponentStorage.names(for: link, fetcher: fetcher, in: defaults, now: now.addingTimeInterval(3.0 * 24.0 * 3600.0))
        XCTAssertEqual(offline, names)
        XCTAssertEqual(loader.requests.count, 2)
    }
}
