import Foundation

struct LeagueTeamLink: Equatable {
    let leagueID: String
    let teamID: String
    var url: URL { URL(string: "https://sbn.toernooi.nl/league/\(leagueID)/team/\(teamID)")! }
    init(_ value: String) throws {
        guard let parts = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https", parts.host?.lowercased() == "sbn.toernooi.nl",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil else { throw LeagueTeamError.invalidLink }
        let path = parts.path.split(separator: "/").map(String.init)
        guard path.count == 4, path[0].lowercased() == "league", UUID(uuidString: path[1]) != nil,
              path[2].lowercased() == "team", !path[3].isEmpty,
              path[3].allSatisfy({ $0.isASCII && $0.isNumber }) else { throw LeagueTeamError.invalidLink }
        leagueID = path[1].uppercased(); teamID = path[3]
    }
}

enum LeagueTeamError: LocalizedError {
    case invalidLink, changedPage, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidLink: return "Gebruik een HTTPS-teamlink van sbn.toernooi.nl, zoals /league/…/team/113."
        case .changedPage: return "De teamgegevens zijn niet herkenbaar. Mogelijk is de website gewijzigd."
        case .unavailable: return "SBN is nu niet bereikbaar. Probeer het later opnieuw."
        }
    }
}

struct LeagueFixture: Codable, Identifiable {
    let id: String
    let date: Date
    let home: String
    let away: String
    let score: String?
    let url: URL
}
struct LeagueStanding: Codable, Identifiable {
    let id: String
    let rank: Int
    let name: String
    let played: Int
    let won: Int
    let lost: Int
    let points: Int
}
struct LeaguePlayer: Codable, Identifiable {
    let id: String
    let name: String
    let record: String
}
struct LeagueTeamSnapshot: Codable {
    let source: URL
    let name: String
    let competition: String
    let division: String
    let rank: Int?
    let played: Int?
    let points: Int?
    let fixtures: [LeagueFixture]
    let players: [LeaguePlayer]
    var standings: [LeagueStanding] = []
    var updatedAt: Date = Date()
}
struct LeagueRubber: Identifiable {
    let id: Int
    let home: String
    let away: String
    let scores: [String]
}
struct LeagueMatchDetail {
    let competitionPoints: String
    let rubbers: [LeagueRubber]
}

/// Deliberately scoped HTML extraction for SBN's public server-rendered pages.
/// Required markers are validated so a cookie/error page never replaces a good cache.
enum LeagueTeamParser {
    static func matches(_ pattern: String, _ html: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : ns.substring(with: match.range(at: $0)) }
        }
    }
    static func text(_ html: String) -> String {
        var value = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for match in matches("&#(x[0-9a-f]+|[0-9]+);", value) {
            let code = match[1].lowercased()
            let number = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
            if let number, let scalar = UnicodeScalar(number) { value = value.replacingOccurrences(of: match[0], with: String(scalar)) }
        }
        for (entity, replacement) in [("&nbsp;", " "), ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        return value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func value(_ className: String, tag: String = "span", in html: String) -> String {
        matches("<\(tag)\\b[^>]*class=\"[^\"]*\\b\(className)\\b[^\"]*\"[^>]*>(.*?)</\(tag)>", html).first.map { text($0[1]) } ?? ""
    }
    static func links(_ html: String, containing component: String) -> [(path: String, name: String)] {
        matches("<a\\b[^>]*href=\"([^\"]*\(component)[^\"]*)\"[^>]*>(.*?)</a>", html).map { ($0[1], text($0[2])) }
    }
    static func team(_ html: String, link: LeagueTeamLink) throws -> (LeagueTeamSnapshot, URL) {
        let name = value("hgroup__heading", tag: "h2", in: html)
        let division = links(html, containing: "/draw/").first
        guard !name.isEmpty, let division,
              let draw = URL(string: division.path, relativeTo: link.url)?.absoluteURL,
              draw.host == link.url.host, draw.path.lowercased().hasPrefix("/league/\(link.leagueID.lowercased())/draw/") else { throw LeagueTeamError.changedPage }
        let stats = matches("<span[^>]*class=\"stats__title\"[^>]*>(.*?)</span>\\s*<span[^>]*class=\"stats__value[^\"]*\"[^>]*>(.*?)</span>", html)
        func stat(_ name: String) -> Int? { stats.first(where: { text($0[1]) == name }).flatMap { Int(text($0[2])) } }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam"); formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let blocks = matches("<a[^>]*class=\"team-match__wrapper\"[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>", html)
        let fixtures = try blocks.map { block -> LeagueFixture in
            let body = block[2]
            guard let dateText = matches("<time[^>]*datetime=\"([^\"]+)\"", body).first?[1], let date = formatter.date(from: dateText),
                  let url = URL(string: block[1], relativeTo: link.url)?.absoluteURL, url.host == link.url.host else { throw LeagueTeamError.changedPage }
            let names = matches("<div[^>]*class=\"team-match__name[^\"]*\"[^>]*>(.*?)</div>", body).map { text($0[1]) }
            guard names.count == 2 else { throw LeagueTeamError.changedPage }
            let score = matches("<div[^>]*class=\"score[^\"]*\"[^>]*>(.*?)</div>", body).first
            let isPending = score?.first?.contains("is-not-played") == true
            return LeagueFixture(id: block[1], date: date, home: names[0], away: names[1], score: isPending ? nil : score.map { text($0[1]) }, url: url)
        }
        var players: [LeaguePlayer] = []
        for block in html.components(separatedBy: "<li class=\"list__item\">") {
            guard let player = links(block, containing: "/player/").first, !players.contains(where: { $0.id == player.path }) else { continue }
            players.append(LeaguePlayer(id: player.path, name: player.name, record: value("pull-right", in: block)))
        }
        return (LeagueTeamSnapshot(source: link.url, name: name, competition: value("hgroup__subheading", tag: "p", in: html), division: division.name, rank: stat("Stand"), played: stat("Gespeeld"), points: stat("Punten"), fixtures: fixtures.sorted { $0.date < $1.date }, players: players), draw)
    }
    static func standings(_ html: String) throws -> [LeagueStanding] {
        let rows = matches("<tr\\b[^>]*>(.*?)</tr>", html)
        let result: [LeagueStanding] = try rows.compactMap { row in
            guard let team = links(row[1], containing: "/team/").first else { return nil }
            let cells = matches("<td\\b[^>]*>(.*?)</td>", row[1]).map { text($0[1]) }
            guard cells.count >= 9, let rank = Int(value("standing-status", in: row[1])), let played = Int(cells[1]), let won = Int(cells[2]), let lost = Int(cells[4]), let points = Int(cells[8]) else { throw LeagueTeamError.changedPage }
            return LeagueStanding(id: team.path, rank: rank, name: team.name, played: played, won: won, lost: lost, points: points)
        }
        guard !result.isEmpty else { throw LeagueTeamError.changedPage }
        return result
    }
    static func detail(_ html: String) throws -> LeagueMatchDetail {
        var rubbers: [LeagueRubber] = []
        for block in html.components(separatedBy: "<div class=\"match\">").dropFirst() {
            let players = links(block, containing: "/player/")
            guard players.count >= 2 else { continue }
            let scores = matches("<ul[^>]*class=\"points\"[^>]*>(.*?)</ul>", block).map { row in
                matches("<li\\b[^>]*>(.*?)</li>", row[1]).map { text($0[1]) }.joined(separator: "–")
            }
            rubbers.append(LeagueRubber(id: rubbers.count, home: players[0].name, away: players[1].name, scores: scores))
        }
        guard html.contains("team-match__name") else { throw LeagueTeamError.changedPage }
        return LeagueMatchDetail(competitionPoints: value("module__footer-item-value", in: html), rubbers: rubbers)
    }
}

actor LeagueTeamService {
    static let shared = LeagueTeamService()
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 SquashAnalyzer/2.2", "Accept-Language": "nl-NL,nl;q=0.9"]
        session = URLSession(configuration: config)
    }
    private func page(_ url: URL) async throws -> String {
        guard url.scheme == "https", url.host == "sbn.toernooi.nl" else { throw LeagueTeamError.invalidLink }
        var (data, response) = try await session.data(from: url)
        if response.url?.path.lowercased().contains("cookiewall") == true {
            let consentHTML = String(decoding: data, as: UTF8.self)
            guard consentHTML.contains("/cookiewall/Save") else { throw LeagueTeamError.unavailable }
            var request = URLRequest(url: URL(string: "https://sbn.toernooi.nl/cookiewall/Save")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var body = URLComponents()
            body.queryItems = [URLQueryItem(name: "ReturnUrl", value: url.path), URLQueryItem(name: "SettingsOpen", value: "true"), URLQueryItem(name: "CookiePurposes", value: "1")]
            request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
            (data, response) = try await session.data(for: request)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, response.url?.host == url.host,
              data.count < 5_000_000, let html = String(data: data, encoding: .utf8), !html.contains("<form action=\"/cookiewall/Save\"") else { throw LeagueTeamError.unavailable }
        return html
    }
    func fetch(_ link: LeagueTeamLink) async throws -> LeagueTeamSnapshot {
        let (snapshot, draw) = try LeagueTeamParser.team(try await page(link.url), link: link)
        var result = snapshot
        result.standings = try LeagueTeamParser.standings(try await page(draw))
        guard result.standings.contains(where: { $0.id.lowercased() == link.url.path.lowercased() }) else { throw LeagueTeamError.changedPage }
        return result
    }
    func detail(_ url: URL) async throws -> LeagueMatchDetail { try LeagueTeamParser.detail(try await page(url)) }
}
