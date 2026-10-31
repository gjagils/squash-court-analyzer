import Foundation

// Finding teams on sbn.toernooi.nl (Gerd-Jan, 31 October 2026, agreed with SBN):
// a club and its teams for the team link in the settings, and the players of
// the opponent in a team match. The pages are public; nothing is sent back.

/// The competition the club search looks in. One season at a time: before the
/// new competition starts (September 2027) the ID of "SBN Competitie 2027-2028"
/// goes here (https://sbn.toernooi.nl/find/league lists them).
public enum LeagueSeason {
    public static let leagueID = "E035D752-EA4C-446D-82CF-0016EFF20E6C"
    public static let name = "SBN Competitie 2026-2027"

    static var path: String { "/league/\(leagueID)" }
    static var url: URL { URL(string: "https://sbn.toernooi.nl\(path)")! }
}

/// A club in the competition: "All Inn Squash", "Utrecht"
public struct LeagueClub: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let place: String

    public init(id: String, name: String, place: String) {
        self.id = id
        self.name = name
        self.place = place
    }
}

/// One team of a club: "All Inn Squash 8", "Gemengd – Derde Divisie – Afdeling 4"
public struct LeagueClubTeam: Identifiable, Equatable, Sendable {
    public var id: String { link.url.absoluteString }
    public let name: String
    public let division: String
    public let link: LeagueTeamLink

    public init(name: String, division: String, link: LeagueTeamLink) {
        self.name = name
        self.division = division
        self.link = link
    }
}

extension LeagueTeamParser {
    /// The clubs in the answer of the club search (`LeagueHome/DoSearch`)
    public static func clubs(_ html: String) -> [LeagueClub] {
        var result: [LeagueClub] = []
        for block in html.components(separatedBy: "js-asg-result-item").dropFirst() {
            guard let href = LeagueRegex.matches("data-asg-href=\"[^\"]*/club/([0-9]+)\"", block).first else { continue }
            let id = href[1]
            guard !result.contains(where: { club in club.id == id }) else { continue }
            let title = LeagueRegex.matches("data-asg-title=\"([^\"]*)\"", block).first.map { match in text(match[1]) } ?? ""
            let name = title.isEmpty ? value("nav-link__value", in: block) : title
            guard !name.isEmpty else { continue }
            // "Utrecht | NED": the place only
            let place = value("media__subheading", in: block).components(separatedBy: "|")[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(LeagueClub(id: id, name: name, place: place))
        }
        return result
    }

    /// The teams of a club (its "Teams" tab), only those of `leagueID`
    public static func clubTeams(_ html: String, leagueID: String = LeagueSeason.leagueID) -> [LeagueClubTeam] {
        var result: [LeagueClubTeam] = []
        for block in html.components(separatedBy: "<li class=\"list__item").dropFirst() {
            guard let team = links(block, containing: "/team/").first, !team.name.isEmpty,
                  let link = try? LeagueTeamLink("https://sbn.toernooi.nl" + team.path),
                  link.leagueID == leagueID.uppercased(),
                  !result.contains(where: { known in known.link == link }) else { continue }
            // The item reads "Dames – Tweede Divisie – Afdeling 1 All Inn Squash Dames 1"
            // (the block starts inside the <li> tag: skip its rest)
            var division = text(block.components(separatedBy: ">").dropFirst().joined(separator: ">"))
            if division.hasSuffix(team.name) { division = String(division.dropLast(team.name.count)) }
            division = division.trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(LeagueClubTeam(name: team.name, division: division, link: link))
        }
        return result
    }
}

extension LeagueTeamFetcher {
    /// The shortest search SBN answers
    public static let minimumSearch = 3

    /// The search text as a form value: letters, digits and a few signs; a
    /// space becomes "+" (clubs have plain names, accents are left out)
    static func searchBody(_ query: String) -> String {
        var value = ""
        for character in query.trimmingCharacters(in: .whitespacesAndNewlines) {
            if character == " " {
                value += "+"
            } else if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._".contains(character) {
                value += String(character)
            }
        }
        return "Query=" + value
    }

    /// Clubs whose name matches `query` (at least three characters)
    public func searchClubs(_ query: String) async throws -> [LeagueClub] {
        let body = LeagueTeamFetcher.searchBody(query)
        guard body.count - 6 >= LeagueTeamFetcher.minimumSearch else { return [] }
        let url = URL(string: "https://sbn.toernooi.nl\(LeagueSeason.path)/LeagueHome/DoSearch")!
        return LeagueTeamParser.clubs(try await page(url, form: body, fragment: false))
    }

    /// The teams of a club in this season's competition
    public func teams(of club: LeagueClub) async throws -> [LeagueClubTeam] {
        guard LeagueTeamLink.isNumber(club.id) else { throw LeagueTeamError.invalidLink }
        let url = URL(string: "https://sbn.toernooi.nl\(LeagueSeason.path)/club/\(club.id)/GetTabContent/teams")!
        return LeagueTeamParser.clubTeams(try await page(url, form: nil, fragment: true))
    }

    /// The players on a team's page (the opponent's in a team match)
    public func players(of link: LeagueTeamLink) async throws -> [LeaguePlayer] {
        try LeagueTeamParser.team(try await page(link.url), link: link).snapshot.players
    }
}

// MARK: - The opponent of a match of Mijn team

public enum LeagueOpponent {
    /// The opponent's team page for a match of Mijn team, found by its name
    /// in the standings of the poule; nil when it is not there (a cup match)
    public static func link(for fixture: LeagueFixture, in team: LeagueTeamSnapshot) -> LeagueTeamLink? {
        let opponent = TeamMatch.sameTeam(fixture.home, team.name) ? fixture.away : fixture.home
        guard let row = team.standings.first(where: { row in TeamMatch.sameTeam(row.name, opponent) }) else { return nil }
        return try? LeagueTeamLink("https://sbn.toernooi.nl" + row.id)
    }

    /// The opponent's team page for a team match made from the programme
    public static func link(for match: TeamMatch, in team: LeagueTeamSnapshot?) -> LeagueTeamLink? {
        guard let team, let id = match.fixtureId,
              let fixture = team.fixtures.first(where: { fixture in fixture.id == id }) else { return nil }
        return link(for: fixture, in: team)
    }
}

/// An opponent's players as last fetched
public struct LeagueOpponentRoster: Codable, Equatable, Sendable {
    public let source: URL
    public let names: [String]
    public let fetchedAt: Date

    public init(source: URL, names: [String], fetchedAt: Date = Date()) {
        self.source = source
        self.names = names
        self.fetchedAt = fetchedAt
    }
}

/// The opponents' players on this phone, so the partij editor has them
/// without a connection; a team is fetched again after a day.
public enum LeagueOpponentStorage {
    static let key = "sbnOpponentRosters"
    static let keep = 12
    public static let maxAge: TimeInterval = 24.0 * 3600.0

    static func all(in defaults: UserDefaults) -> [LeagueOpponentRoster] {
        guard let data = defaults.data(forKey: key),
              let rosters = try? JSONDecoder().decode([LeagueOpponentRoster].self, from: data) else { return [] }
        return rosters
    }

    public static func roster(for link: LeagueTeamLink, in defaults: UserDefaults = UserDefaults.standard) -> LeagueOpponentRoster? {
        all(in: defaults).first(where: { roster in roster.source == link.url })
    }

    public static func store(_ roster: LeagueOpponentRoster, in defaults: UserDefaults = UserDefaults.standard) {
        var rosters = all(in: defaults).filter { known in known.source != roster.source }
        rosters.insert(roster, at: 0)
        if rosters.count > keep { rosters = Array(rosters.prefix(keep)) }
        if let data = try? JSONEncoder().encode(rosters) {
            defaults.set(data, forKey: key)
        }
    }

    /// The saved names, fetching them first when they are missing or older
    /// than a day; the saved ones (or none) when SBN cannot be reached
    public static func names(for link: LeagueTeamLink, fetcher: LeagueTeamFetcher,
                             in defaults: UserDefaults = UserDefaults.standard, now: Date = Date()) async -> [String] {
        let saved = roster(for: link, in: defaults)
        if let saved, now.timeIntervalSince(saved.fetchedAt) < maxAge { return saved.names }
        do {
            let players = try await fetcher.players(of: link)
            var names: [String] = []
            for player in players where !names.contains(player.name) { names.append(player.name) }
            store(LeagueOpponentRoster(source: link.url, names: names, fetchedAt: now), in: defaults)
            return names
        } catch {
            return saved?.names ?? []
        }
    }
}
