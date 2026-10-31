import XCTest
import Foundation
@testable import SquashAnalyzerCore

#if !SKIP
/// Against the real sbn.toernooi.nl, for Gerd-Jan's own team: skipped unless
/// `SBN_LIVE_TEAM` is set (to a team link, or to 1 for the link below), so CI
/// and offline runs never touch the site. One team page and its poule, nothing more:
///
///     SBN_LIVE_TEAM=1 swift test --filter TeamLinkLiveTests
///
/// Checks the whole path of "Mijn team": cookie wall, parser, and the players
/// landing in Spelers with the mark "In mijn team".
final class TeamLinkLiveTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }
    static let defaultLink = "https://sbn.toernooi.nl/league/E035D752-EA4C-446D-82CF-0016EFF20E6C/team/94"

    private struct Loader: LeaguePageLoader {
        let session: URLSession

        init() {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 20
            config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 SquashAnalyzer/3.0 (test)", "Accept-Language": "nl-NL,nl;q=0.9"]
            session = URLSession(configuration: config)
        }

        func get(_ url: URL) async throws -> LeaguePage { page(try await session.data(from: url)) }

        func postForm(_ url: URL, body: String) async throws -> LeaguePage {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = body.data(using: .utf8)
            return page(try await session.data(for: request))
        }

        func getFragment(_ url: URL) async throws -> LeaguePage {
            var request = URLRequest(url: url)
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            return page(try await session.data(for: request))
        }

        private func page(_ result: (Data, URLResponse)) -> LeaguePage {
            let (data, response) = result
            return LeaguePage(finalURL: response.url, status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                              body: String(data: data, encoding: .utf8), byteCount: data.count)
        }
    }

    private final class MemoryStore: PlayerProfileStore, @unchecked Sendable {
        var players: [PlayerProfile] = []
        func loadPlayers() async throws -> [PlayerProfile] { players }
        func savePlayer(_ player: PlayerProfile) async throws { players.append(player) }
        func deletePlayer(_ id: String) async throws { players = players.filter { other in other.id != id } }
    }

    @MainActor
    func testTheTeamIsFetchedAndItsPlayersBecomeTeamMembers() async throws {
        guard let setting = ProcessInfo.processInfo.environment["SBN_LIVE_TEAM"], !setting.isEmpty else {
            throw XCTSkip("Set SBN_LIVE_TEAM=1 to run against sbn.toernooi.nl")
        }
        let link = try LeagueTeamLink(setting == "1" ? TeamLinkLiveTests.defaultLink : setting)
        let snapshot = try await LeagueTeamFetcher(loader: Loader()).fetch(link)
        XCTAssertFalse(snapshot.name.isEmpty)
        XCTAssertFalse(snapshot.players.isEmpty, "the team page lists players")
        XCTAssertFalse(snapshot.fixtures.isEmpty, "and a programme")

        let defaults = UserDefaults(suiteName: "teamlinklive-\(UUID().uuidString)")!
        let store = MemoryStore()
        let added = await TeamRosterSync.run(snapshot, store: store, in: defaults)
        XCTAssertEqual(added, snapshot.players.count)
        XCTAssertEqual(TeamRoster.ids(in: defaults).count, store.players.count, "everyone is marked In mijn team")
        let again = await TeamRosterSync.run(snapshot, store: store, in: defaults)
        XCTAssertEqual(again, 0, "once per team link")
    }

    /// Club, its teams and an opponent's players: the search in the settings
    /// and the names in a team match. A few pages of the season, nothing more.
    func testAClubItsTeamsAndAnOpponentAreFound() async throws {
        guard let setting = ProcessInfo.processInfo.environment["SBN_LIVE_TEAM"], !setting.isEmpty else {
            throw XCTSkip("Set SBN_LIVE_TEAM=1 to run against sbn.toernooi.nl")
        }
        let fetcher = LeagueTeamFetcher(loader: Loader())
        let clubs = try await fetcher.searchClubs("All Inn")
        let club = try XCTUnwrap(clubs.first(where: { club in club.name == "All Inn Squash" }), "\(clubs)")
        XCTAssertEqual(club.place, "Utrecht")
        let teams = try await fetcher.teams(of: club)
        let own = try XCTUnwrap(teams.first(where: { team in team.link.url.absoluteString == TeamLinkLiveTests.defaultLink }), "\(teams)")
        XCTAssertEqual(own.name, "All Inn Squash 7")
        XCTAssertFalse(own.division.isEmpty)

        let snapshot = try await fetcher.fetch(own.link)
        let fixture = try XCTUnwrap(snapshot.fixtures.first)
        let opponent = try XCTUnwrap(LeagueOpponent.link(for: fixture, in: snapshot), "the opponent is in the poule")
        XCTAssertNotEqual(opponent, own.link)
        let players = try await fetcher.players(of: opponent)
        XCTAssertFalse(players.isEmpty, "the opponent's page lists players")
    }
}
#endif
