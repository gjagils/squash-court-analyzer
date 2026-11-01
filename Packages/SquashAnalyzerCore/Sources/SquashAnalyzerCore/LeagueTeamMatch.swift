import Foundation

// The result of a team match as sbn.toernooi.nl shows it on its team-match
// page (/league/<uuid>/team-match/<n>, the link every fixture of Mijn team
// carries): per partij E1–E4 the two players, who won and every game with its
// points, home first. The back-up for a live page that is gone, and the way
// to bring a played match that was never logged into the app (Gerd-Jan,
// 1 November 2026).

/// One partij on the SBN team-match page
public struct LeaguePartijResult: Equatable, Sendable {
    public let slot: Int
    public let homePlayer: String
    public let awayPlayer: String
    /// [home, away] per game, in play order; empty before the result is in
    public let games: [[Int]]
    /// nil before the result is in
    public let homeWon: Bool?

    public init(slot: Int, homePlayer: String, awayPlayer: String, games: [[Int]], homeWon: Bool?) {
        self.slot = slot
        self.homePlayer = homePlayer
        self.awayPlayer = awayPlayer
        self.games = games
        self.homeWon = homeWon
    }

    public var hasResult: Bool { !games.isEmpty }
}

/// The SBN team-match page, read
public struct LeagueTeamMatchResult: Equatable, Sendable {
    public let home: String
    public let away: String
    public let partijen: [LeaguePartijResult]

    public init(home: String, away: String, partijen: [LeaguePartijResult]) {
        self.home = home
        self.away = away
        self.partijen = partijen
    }

    /// At least one partij with games; SBN shows the page before the captain enters the result
    public var hasResult: Bool { partijen.contains { partij in partij.hasResult } }

    public func partij(slot: Int) -> LeaguePartijResult? {
        for partij in partijen where partij.slot == slot { return partij }
        return nil
    }
}

enum LeagueTeamMatchParser {
    /// The partijen block: `<li class="match-group__item">` per partij with
    /// `E1` in a `nav-link__value`, two `match__row`s (the winner's has
    /// `has-won`) with the player in a `nav-link__value`, and per game a
    /// `<ul class="points">` with two `points__cell`s. A page without that
    /// block is not a team-match page (or SBN changed).
    static func parse(_ html: String) throws -> LeagueTeamMatchResult {
        let parts = html.components(separatedBy: "class=\"match-group__item\"")
        guard parts.count > 1 else { throw LeagueTeamError.changedPage }
        var partijen: [LeaguePartijResult] = []
        var home = ""
        var away = ""
        for index in 1..<parts.count {
            let part = parts[index]
            let values = LeagueRegex.matches("class=\"nav-link__value\">(.*?)</span>", part)
            // E1, the home player, the away player (then H2H, when the page has it)
            guard values.count >= 3, let slot = slotNumber(LeagueTeamParser.text(values[0][1])) else { continue }
            let homePlayer = LeagueTeamParser.text(values[1][1])
            let awayPlayer = LeagueTeamParser.text(values[2][1])
            let rows = LeagueRegex.matches("class=\"match__row( [^\"]*)?\"", part)
            guard rows.count >= 2 else { throw LeagueTeamError.changedPage }
            let headers = LeagueRegex.matches("class=\"match__row-title-header\">(.*?)</div>", part)
            if headers.count >= 2 && home.isEmpty {
                home = LeagueTeamParser.text(headers[0][1])
                away = LeagueTeamParser.text(headers[1][1])
            }
            var games: [[Int]] = []
            for list in LeagueRegex.matches("<ul class=\"points\">(.*?)</ul>", part) {
                let cells = LeagueRegex.matches("class=\"points__cell[^\"]*\">\\s*(\\d+)\\s*</li>", list[1])
                guard cells.count == 2, let homePoints = Int(cells[0][1]), let awayPoints = Int(cells[1][1]) else {
                    throw LeagueTeamError.changedPage
                }
                games.append([homePoints, awayPoints])
            }
            var homeWon: Bool? = nil
            if !games.isEmpty {
                let homeHasWon = rows[0][1].contains("has-won")
                let awayHasWon = rows[1][1].contains("has-won")
                if homeHasWon != awayHasWon {
                    homeWon = homeHasWon
                } else {
                    // No mark: count the games
                    var homeGames = 0
                    var awayGames = 0
                    for game in games { if game[0] > game[1] { homeGames += 1 } else { awayGames += 1 } }
                    homeWon = homeGames > awayGames
                }
            }
            partijen.append(LeaguePartijResult(slot: slot, homePlayer: homePlayer, awayPlayer: awayPlayer, games: games, homeWon: homeWon))
        }
        guard !partijen.isEmpty else { throw LeagueTeamError.changedPage }
        return LeagueTeamMatchResult(home: home, away: away, partijen: partijen)
    }

    /// "E1" → 1
    private static func slotNumber(_ label: String) -> Int? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.hasPrefix("E"), let number = Int(String(trimmed.dropFirst())), number >= 1, number <= 4 else { return nil }
        return number
    }
}

public extension LeagueTeamFetcher {
    /// The result of one team match from its SBN page (a fixture's `url`)
    func fetchTeamMatch(_ url: URL) async throws -> LeagueTeamMatchResult {
        try LeagueTeamMatchParser.parse(try await page(url))
    }
}

/// What filling a team match from SBN did
public struct LeagueFillOutcome: Equatable, Sendable {
    /// Slots that were empty and now hold the SBN result
    public var filled: [Int] = []
    /// Slots whose games had no points and got them
    public var completed: [Int] = []
    /// Slots where SBN says something else than the phone: "E3: SBN 3-1 (11-5, …), app 3-0"
    public var differences: [String] = []
    /// Slots SBN has no result for yet
    public var pending: [Int] = []

    public init() {}

    public var changedAnything: Bool { !filled.isEmpty || !completed.isEmpty }

    /// "E1, E3"
    public static func labels(_ slots: [Int]) -> String {
        var parts: [String] = []
        for slot in slots { parts.append("E\(slot)") }
        return parts.joined(separator: ", ")
    }
}

public extension TeamMatch {
    /// Any partij with a game whose points are unknown ("–")
    var hasUnknownPoints: Bool {
        for partij in partijen {
            for game in partij.games where !game.hasPoints { return true }
        }
        return false
    }

    /// Takes what SBN knows into this team match: an empty partij gets the
    /// players and the games; a partij whose games have no points (later
    /// instappen, filled in from memory) gets the points when the winners per
    /// game agree; a partij that says something else is reported, not changed
    /// (what was tracked on a phone counts as the truth until someone decides).
    /// Partijen linked to a tracked match keep their games (Vernieuwen reads
    /// the tracked match again), differences are reported.
    mutating func fill(fromSBN result: LeagueTeamMatchResult) -> LeagueFillOutcome {
        var outcome = LeagueFillOutcome()
        let ownIsHome = ownSide == TeamSide.home
        for index in 0..<partijen.count {
            let current = partijen[index]
            guard let sbn = result.partij(slot: current.slot) else { continue }
            guard sbn.hasResult else {
                if !current.hasEntry { outcome.pending.append(current.slot) }
                continue
            }
            var sbnGames: [TeamGame] = []
            for game in sbn.games where game.count >= 2 {
                sbnGames.append(TeamGame(own: ownIsHome ? game[0] : game[1], their: ownIsHome ? game[1] : game[0]))
            }
            if !current.hasEntry {
                var partij = TeamPartij(slot: current.slot, ownPlayer: ownIsHome ? sbn.homePlayer : sbn.awayPlayer,
                                        opponentPlayer: ownIsHome ? sbn.awayPlayer : sbn.homePlayer,
                                        games: sbnGames, playOrder: current.playOrder, bestOf: current.bestOf)
                partij.fromSBN = true
                partijen[index] = partij
                outcome.filled.append(current.slot)
                continue
            }
            // Same games (count and winners): points for the unknown ones
            var sameCourse = current.games.count == sbnGames.count
            if sameCourse {
                for gameIndex in 0..<current.games.count where current.games[gameIndex].ownWon != sbnGames[gameIndex].ownWon {
                    sameCourse = false
                }
            }
            if sameCourse {
                var changed = false
                var games = current.games
                if current.linkedMatchId == nil {
                    for gameIndex in 0..<games.count where !games[gameIndex].hasPoints {
                        games[gameIndex] = sbnGames[gameIndex]
                        changed = true
                    }
                }
                if changed {
                    partijen[index].games = games
                    outcome.completed.append(current.slot)
                }
            } else {
                outcome.differences.append("E\(current.slot): SBN \(TeamMatch.summary(sbnGames)), " + L10n.text("app") + " \(TeamMatch.summary(current.games))")
            }
        }
        if outcome.changedAnything { updatedAt = Date() }
        return outcome
    }

    /// "3-1 (11-5, 9-11, 11-3, 11-8)"
    private static func summary(_ games: [TeamGame]) -> String {
        var won = 0
        var lost = 0
        var texts: [String] = []
        for game in games {
            if game.ownWon { won += 1 } else { lost += 1 }
            texts.append(game.text)
        }
        return "\(won)-\(lost) (" + texts.joined(separator: ", ") + ")"
    }

    /// A team match from the programme with the SBN result already in it
    static func from(fixture: LeagueFixture, ownTeam: String, sbn result: LeagueTeamMatchResult) -> TeamMatch {
        var match = TeamMatch.from(fixture: fixture, ownTeam: ownTeam)
        _ = match.fill(fromSBN: result)
        return match
    }
}
