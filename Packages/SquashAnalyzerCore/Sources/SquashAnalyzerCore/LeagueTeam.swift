import Foundation

// "Mijn team": the public team page of sbn.toernooi.nl, shared by iOS and
// Android. The parsing and the cookie-wall handling live here; fetching a page
// is per platform (`LeaguePageLoader`), because Skip's URLSession keeps no
// cookies and the cookie wall needs them.

/// A validated team link: https://sbn.toernooi.nl/league/<uuid>/team/<number>
public struct LeagueTeamLink: Equatable, Sendable {
    public let leagueID: String
    public let teamID: String
    public var url: URL { URL(string: "https://sbn.toernooi.nl/league/\(leagueID)/team/\(teamID)")! }

    public init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Scheme and host are case-insensitive; no user, port, query or fragment
        let prefix = "https://sbn.toernooi.nl/"
        guard trimmed.lowercased().hasPrefix(prefix), !trimmed.contains("?"), !trimmed.contains("#") else {
            throw LeagueTeamError.invalidLink
        }
        let rest = String(trimmed.dropFirst(prefix.count))
        var path: [String] = []
        for part in rest.components(separatedBy: "/") where !part.isEmpty {
            path.append(part)
        }
        guard path.count == 4, path[0].lowercased() == "league", UUID(uuidString: path[1]) != nil,
              path[2].lowercased() == "team", LeagueTeamLink.isNumber(path[3]) else {
            throw LeagueTeamError.invalidLink
        }
        leagueID = path[1].uppercased()
        teamID = path[3]
    }

    static func isNumber(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        for character in value where !"0123456789".contains(character) {
            return false
        }
        return true
    }
}

public enum LeagueTeamError: Error, Equatable {
    case invalidLink, changedPage, unavailable

    public var message: String {
        switch self {
        case .invalidLink: return "Gebruik een HTTPS-teamlink van sbn.toernooi.nl, zoals /league/…/team/113."
        case .changedPage: return "De teamgegevens zijn niet herkenbaar. Mogelijk is de website gewijzigd."
        case .unavailable: return "SBN is nu niet bereikbaar. Probeer het later opnieuw."
        }
    }
}

public struct LeagueFixture: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let home: String
    public let away: String
    public let score: String?
    public let url: URL

    public init(id: String, date: Date, home: String, away: String, score: String?, url: URL) {
        self.id = id
        self.date = date
        self.home = home
        self.away = away
        self.score = score
        self.url = url
    }
}

public struct LeagueStanding: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let rank: Int
    public let name: String
    public let played: Int
    public let won: Int
    public let lost: Int
    public let points: Int

    public init(id: String, rank: Int, name: String, played: Int, won: Int, lost: Int, points: Int) {
        self.id = id
        self.rank = rank
        self.name = name
        self.played = played
        self.won = won
        self.lost = lost
        self.points = points
    }
}

public struct LeaguePlayer: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let record: String

    public init(id: String, name: String, record: String) {
        self.id = id
        self.name = name
        self.record = record
    }
}

public struct LeagueTeamSnapshot: Codable, Equatable, Sendable {
    public let source: URL
    public let name: String
    public let competition: String
    public let division: String
    public let rank: Int?
    public let played: Int?
    public let points: Int?
    public let fixtures: [LeagueFixture]
    public let players: [LeaguePlayer]
    public var standings: [LeagueStanding] = []
    public var updatedAt: Date = Date()

    public init(source: URL, name: String, competition: String, division: String, rank: Int?, played: Int?, points: Int?,
                fixtures: [LeagueFixture], players: [LeaguePlayer], standings: [LeagueStanding] = [], updatedAt: Date = Date()) {
        self.source = source
        self.name = name
        self.competition = competition
        self.division = division
        self.rank = rank
        self.played = played
        self.points = points
        self.fixtures = fixtures
        self.players = players
        self.standings = standings
        self.updatedAt = updatedAt
    }

    /// The first match that has not started yet
    public func nextFixture(after now: Date = Date()) -> LeagueFixture? {
        fixtures.first { fixture in fixture.date >= now }
    }
}

public struct LeagueRubber: Identifiable, Equatable, Sendable {
    public let id: Int
    public let home: String
    public let away: String
    public let scores: [String]
}

public struct LeagueMatchDetail: Equatable, Sendable {
    public let competitionPoints: String
    public let rubbers: [LeagueRubber]
}

/// A link on a page: its href and its text
struct LeagueLink {
    let path: String
    let name: String
}

/// Regular expressions on both platforms: NSRegularExpression on Apple,
/// kotlin.text.Regex on Android (Skip has no NSRegularExpression). Always
/// case-insensitive with `.` matching newlines; a group that did not take
/// part in a match is "".
enum LeagueRegex {
    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        var result: [[String]] = []
        #if SKIP
        // Flags inline: Skip's own setOf() makes Kotlin pick an internal Regex constructor
        let regex = kotlin.text.Regex("(?siu)" + pattern)
        for match in regex.findAll(text) {
            var groups: [String] = []
            for group in match.groupValues {
                groups.append(group)
            }
            result.append(groups)
        }
        #else
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            var groups: [String] = []
            for index in 0..<match.numberOfRanges {
                let range = match.range(at: index)
                groups.append(range.location == NSNotFound ? "" : ns.substring(with: range))
            }
            result.append(groups)
        }
        #endif
        return result
    }

    /// Replaces every match (case-sensitive, like `.regularExpression`)
    static func replace(_ pattern: String, in text: String, with replacement: String) -> String {
        #if SKIP
        return kotlin.text.Regex(pattern).replace(text, replacement)
        #else
        return text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        #endif
    }

    static func hexadecimal(_ text: String) -> Int? {
        #if SKIP
        return text.toIntOrNull(16)
        #else
        return Int(text, radix: 16)
        #endif
    }

    /// The character for a Unicode code point, or nil for an invalid one
    static func character(_ codePoint: Int) -> String? {
        guard codePoint > 0, codePoint <= 0x10FFFF, !(codePoint >= 0xD800 && codePoint <= 0xDFFF) else { return nil }
        #if SKIP
        return java.lang.StringBuilder().appendCodePoint(codePoint).toString()
        #else
        return UnicodeScalar(UInt32(codePoint)).map { scalar in String(Character(scalar)) }
        #endif
    }
}

/// Deliberately scoped HTML extraction for SBN's public server-rendered pages.
/// Required markers are validated so a cookie/error page never replaces a good cache.
public enum LeagueTeamParser {
    static func text(_ html: String) -> String {
        var value = LeagueRegex.replace("<[^>]+>", in: html, with: " ")
        for match in LeagueRegex.matches("&#(x[0-9a-f]+|[0-9]+);", value) {
            let code = match[1].lowercased()
            let number = code.hasPrefix("x") ? LeagueRegex.hexadecimal(String(code.dropFirst())) : Int(code)
            if let number, let character = LeagueRegex.character(number) {
                value = value.replacingOccurrences(of: match[0], with: character)
            }
        }
        value = value.replacingOccurrences(of: "&nbsp;", with: " ")
        value = value.replacingOccurrences(of: "&quot;", with: "\"")
        value = value.replacingOccurrences(of: "&apos;", with: "'")
        value = value.replacingOccurrences(of: "&lt;", with: "<")
        value = value.replacingOccurrences(of: "&gt;", with: ">")
        value = value.replacingOccurrences(of: "&amp;", with: "&")
        return LeagueRegex.replace("\\s+", in: value, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func value(_ className: String, tag: String = "span", in html: String) -> String {
        guard let first = LeagueRegex.matches("<\(tag)\\b[^>]*class=\"[^\"]*\\b\(className)\\b[^\"]*\"[^>]*>(.*?)</\(tag)>", html).first else { return "" }
        return text(first[1])
    }

    static func links(_ html: String, containing component: String) -> [LeagueLink] {
        var result: [LeagueLink] = []
        for match in LeagueRegex.matches("<a\\b[^>]*href=\"([^\"]*\(component)[^\"]*)\"[^>]*>(.*?)</a>", html) {
            result.append(LeagueLink(path: match[1], name: text(match[2])))
        }
        return result
    }

    /// The team page, plus the URL of its division's standings page
    public static func team(_ html: String, link: LeagueTeamLink) throws -> (LeagueTeamSnapshot, URL) {
        let name = value("hgroup__heading", tag: "h2", in: html)
        guard !name.isEmpty, let division = links(html, containing: "/draw/").first,
              let draw = resolve(division.path, against: link.url),
              draw.host == link.url.host,
              draw.path.lowercased().hasPrefix("/league/\(link.leagueID.lowercased())/draw/") else {
            throw LeagueTeamError.changedPage
        }
        let stats = LeagueRegex.matches("<span[^>]*class=\"stats__title\"[^>]*>(.*?)</span>\\s*<span[^>]*class=\"stats__value[^\"]*\"[^>]*>(.*?)</span>", html)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var fixtures: [LeagueFixture] = []
        for block in LeagueRegex.matches("<a[^>]*class=\"team-match__wrapper\"[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>", html) {
            let body = block[2]
            guard let dateText = LeagueRegex.matches("<time[^>]*datetime=\"([^\"]+)\"", body).first?[1],
                  let date = formatter.date(from: dateText),
                  let url = resolve(block[1], against: link.url),
                  url.host == link.url.host else { throw LeagueTeamError.changedPage }
            var names: [String] = []
            for match in LeagueRegex.matches("<div[^>]*class=\"team-match__name[^\"]*\"[^>]*>(.*?)</div>", body) {
                names.append(text(match[1]))
            }
            guard names.count == 2 else { throw LeagueTeamError.changedPage }
            let score = LeagueRegex.matches("<div[^>]*class=\"score[^\"]*\"[^>]*>(.*?)</div>", body).first
            var scoreText: String? = nil
            if let score, !score[0].contains("is-not-played") {
                scoreText = text(score[1])
            }
            fixtures.append(LeagueFixture(id: block[1], date: date, home: names[0], away: names[1], score: scoreText, url: url))
        }
        fixtures.sort { first, second in first.date < second.date }

        var players: [LeaguePlayer] = []
        for block in html.components(separatedBy: "<li class=\"list__item\">") {
            guard let player = links(block, containing: "/player/").first else { continue }
            guard !players.contains(where: { existing in existing.id == player.path }) else { continue }
            players.append(LeaguePlayer(id: player.path, name: player.name, record: value("pull-right", in: block)))
        }
        let snapshot = LeagueTeamSnapshot(source: link.url, name: name, competition: value("hgroup__subheading", tag: "p", in: html),
                                          division: division.name, rank: stat("Stand", in: stats), played: stat("Gespeeld", in: stats),
                                          points: stat("Punten", in: stats),
                                          fixtures: fixtures, players: players)
        return (snapshot, draw)
    }

    /// A link on the page as a standalone absolute URL (no base URL kept, so it
    /// compares equal after a round trip through the cache on both platforms)
    static func resolve(_ path: String, against base: URL) -> URL? {
        guard let absolute = URL(string: path, relativeTo: base)?.absoluteString else { return nil }
        return URL(string: absolute)
    }

    static func stat(_ title: String, in stats: [[String]]) -> Int? {
        for row in stats where text(row[1]) == title {
            return Int(text(row[2]))
        }
        return nil
    }

    public static func standings(_ html: String) throws -> [LeagueStanding] {
        var result: [LeagueStanding] = []
        for row in LeagueRegex.matches("<tr\\b[^>]*>(.*?)</tr>", html) {
            guard let team = links(row[1], containing: "/team/").first else { continue }
            var cells: [String] = []
            for cell in LeagueRegex.matches("<td\\b[^>]*>(.*?)</td>", row[1]) {
                cells.append(text(cell[1]))
            }
            guard cells.count >= 9, let rank = Int(value("standing-status", in: row[1])), let played = Int(cells[1]),
                  let won = Int(cells[2]), let lost = Int(cells[4]), let points = Int(cells[8]) else {
                throw LeagueTeamError.changedPage
            }
            result.append(LeagueStanding(id: team.path, rank: rank, name: team.name, played: played, won: won, lost: lost, points: points))
        }
        guard !result.isEmpty else { throw LeagueTeamError.changedPage }
        return result
    }

    public static func detail(_ html: String) throws -> LeagueMatchDetail {
        var rubbers: [LeagueRubber] = []
        for block in html.components(separatedBy: "<div class=\"match\">").dropFirst() {
            let players = links(block, containing: "/player/")
            guard players.count >= 2 else { continue }
            var scores: [String] = []
            for row in LeagueRegex.matches("<ul[^>]*class=\"points\"[^>]*>(.*?)</ul>", block) {
                var points: [String] = []
                for item in LeagueRegex.matches("<li\\b[^>]*>(.*?)</li>", row[1]) {
                    points.append(text(item[1]))
                }
                scores.append(points.joined(separator: "–"))
            }
            rubbers.append(LeagueRubber(id: rubbers.count, home: players[0].name, away: players[1].name, scores: scores))
        }
        guard html.contains("team-match__name") else { throw LeagueTeamError.changedPage }
        return LeagueMatchDetail(competitionPoints: value("module__footer-item-value", in: html), rubbers: rubbers)
    }
}

// MARK: - Fetching

/// One HTTP response as a platform loader returns it
public struct LeaguePage: Sendable {
    /// The URL after redirects
    public let finalURL: URL?
    public let status: Int
    /// The body as UTF-8, or nil when it is not valid UTF-8
    public let body: String?
    public let byteCount: Int

    public init(finalURL: URL?, status: Int, body: String?, byteCount: Int) {
        self.finalURL = finalURL
        self.status = status
        self.body = body
        self.byteCount = byteCount
    }
}

/// Fetches pages, following redirects and keeping cookies for the session:
/// URLSession on iOS, HttpURLConnection with a CookieManager on Android.
public protocol LeaguePageLoader: Sendable {
    func get(_ url: URL) async throws -> LeaguePage
    /// POSTs an application/x-www-form-urlencoded body (already encoded)
    func postForm(_ url: URL, body: String) async throws -> LeaguePage
}

/// Fetches and parses a team, answering SBN's cookie wall with the
/// functional-cookies-only choice when it shows up.
public struct LeagueTeamFetcher: Sendable {
    let loader: any LeaguePageLoader

    public init(loader: any LeaguePageLoader) {
        self.loader = loader
    }

    public func fetch(_ link: LeagueTeamLink) async throws -> LeagueTeamSnapshot {
        let (snapshot, draw) = try LeagueTeamParser.team(try await page(link.url), link: link)
        var result = snapshot
        result.standings = try LeagueTeamParser.standings(try await page(draw))
        let ownPath = link.url.path.lowercased()
        guard result.standings.contains(where: { row in row.id.lowercased() == ownPath }) else { throw LeagueTeamError.changedPage }
        return result
    }

    public func detail(_ url: URL) async throws -> LeagueMatchDetail {
        try LeagueTeamParser.detail(try await page(url))
    }

    /// The cookie-wall consent form: functional cookies only, then back to
    /// `returnPath`. The paths are SBN league paths (letters, digits, `-`, `/`),
    /// which need no escaping in a form body.
    static func consentBody(returnPath: String) -> String {
        "ReturnUrl=\(returnPath)&SettingsOpen=true&CookiePurposes=1"
    }

    func page(_ url: URL) async throws -> String {
        guard url.scheme == "https", url.host == "sbn.toernooi.nl" else { throw LeagueTeamError.invalidLink }
        do {
            var response = try await loader.get(url)
            if response.finalURL?.path.lowercased().contains("cookiewall") == true {
                guard response.body?.contains("/cookiewall/Save") == true else { throw LeagueTeamError.unavailable }
                response = try await loader.postForm(URL(string: "https://sbn.toernooi.nl/cookiewall/Save")!,
                                                     body: LeagueTeamFetcher.consentBody(returnPath: url.path))
            }
            guard response.status == 200, response.finalURL?.host == url.host, response.byteCount < 5_000_000,
                  let html = response.body, !html.contains("<form action=\"/cookiewall/Save\"") else {
                throw LeagueTeamError.unavailable
            }
            return html
        } catch {
            // No connection, a timeout, …: one message for the coach
            if let known = error as? LeagueTeamError { throw known }
            throw LeagueTeamError.unavailable
        }
    }
}

// MARK: - Storage

/// Where the team link and the last fetched team are kept, with the same keys
/// as the iOS app (`CoachInputSettings.teamURLKey`, `LeagueTeamCard`).
public enum LeagueTeamStorage {
    public static let linkKey = "sbnTeamURL"
    static let snapshotKey = "sbnTeamSnapshot"

    /// The last fetched team, only when it belongs to `link`
    public static func cachedSnapshot(for link: LeagueTeamLink, in defaults: UserDefaults = UserDefaults.standard) -> LeagueTeamSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(LeagueTeamSnapshot.self, from: data),
              snapshot.source == link.url else { return nil }
        return snapshot
    }

    public static func store(_ snapshot: LeagueTeamSnapshot, in defaults: UserDefaults = UserDefaults.standard) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }
}
