import Foundation

// 4.0: the compact match that goes to a player's account
// (docs/voorstel-spelersaccount-4.0.md, "Welke data, en hoeveel"). Only what
// badges, card, form and trend need: exactly what `BadgeMatchInput` holds, plus
// the names and which side the receiving player was on. Notes, advice, the AI
// Coach and photos stay on the phone that entered the match. About 2–3 KB for
// four games. The server keeps `summary` and `rallies` as opaque JSON.

/// The result and the frame of the match, shown in the inbox without the rallies
public struct AccountMatchSummary: Codable, Equatable, Sendable {
    /// Format version of summary and rallies
    public var v: Int
    /// "coach" or "referee"
    public var kind: String
    /// The side of the player this copy is for: 1 or 2
    public var me: Int
    public var p1: String
    public var p2: String
    public var gamesToWin: Int
    /// Games won before tracking started ("later instappen"), [player 1, player 2]
    public var gamesBefore: [Int]
    /// Games won in the end, filled-in games included, [player 1, player 2]
    public var gamesWon: [Int]
    /// 1 or 2; 0 while the match is not decided
    public var winner: Int
    /// The tracked games as [player 1, player 2]
    public var scores: [[Int]]
    /// Whole match in seconds
    public var duration: Double
    /// Coach mode in full: every point says how it was won
    public var recordsPointTypes: Bool
    /// The first rally, in milliseconds since 1970
    public var startedAt: Int64?

    public static let formatVersion = 1

    public init(kind: String, me: Int, p1: String, p2: String, gamesToWin: Int, gamesBefore: [Int], gamesWon: [Int],
                winner: Int, scores: [[Int]], duration: Double, recordsPointTypes: Bool, startedAt: Int64?) {
        self.v = AccountMatchSummary.formatVersion
        self.kind = kind
        self.me = me
        self.p1 = p1
        self.p2 = p2
        self.gamesToWin = gamesToWin
        self.gamesBefore = gamesBefore
        self.gamesWon = gamesWon
        self.winner = winner
        self.scores = scores
        self.duration = duration
        self.recordsPointTypes = recordsPointTypes
        self.startedAt = startedAt
    }

    /// The receiving player's side
    public var mySide: Player { me == 2 ? Player.player2 : Player.player1 }

    public var opponentName: String { me == 2 ? p1 : p2 }

    /// From the receiving player's side: "3-1"
    public var result: String {
        let mine = me == 2 ? 1 : 0
        let theirs = me == 2 ? 0 : 1
        guard gamesWon.count == 2 else { return "" }
        return "\(gamesWon[mine])-\(gamesWon[theirs])"
    }

    /// "3-1 tegen Mark"
    public var resultLine: String {
        L10n.text("%@ tegen %@", result, opponentName)
    }
}

/// One tracked game: who won it, its playing time and the rallies in play order.
/// A rally is one short text, `winner|pointType|zone|shot|tenths|volley|server`
/// (`AccountRally`), so 95 rallies stay around 2 KB.
public struct AccountGame: Codable, Equatable, Sendable {
    /// 1 or 2; 0 while unfinished
    public var winner: Int
    /// Seconds from the first serve to the last rally; nil when not timed
    public var duration: Double?
    public var rallies: [String]

    public init(winner: Int, duration: Double?, rallies: [String]) {
        self.winner = winner
        self.duration = duration
        self.rallies = rallies
    }
}

/// A rally as text and back. Raw values, never translated (docs/i18n.md);
/// empty fields for what was not recorded.
public enum AccountRally {
    public static func text(_ rally: BadgeRally) -> String {
        var duration = ""
        if let seconds = rally.duration { duration = "\(Int((seconds * 10.0).rounded()))" }
        var server = ""
        if let player = rally.server { server = "\(AccountMatch.number(player))" }
        let fields: [String] = [
            "\(AccountMatch.number(rally.winner))",
            rally.pointType?.rawValue ?? "",
            rally.zone?.rawValue ?? "",
            rally.shot?.rawValue ?? "",
            duration,
            rally.isVolley ? "1" : "",
            server,
        ]
        return fields.joined(separator: "|")
    }

    /// Nil for a text that is not a rally (unknown values are left out, not refused)
    public static func rally(_ text: String) -> BadgeRally? {
        let fields = split(text)
        guard fields.count >= 7, let winner = AccountMatch.player(fields[0]) else { return nil }
        var duration: TimeInterval? = nil
        if let tenths = Int(fields[4]) { duration = Double(tenths) / 10.0 }
        return BadgeRally(winner: winner, shot: ShotType(rawValue: fields[3]), pointType: PointType(rawValue: fields[1]),
                          zone: CourtZone(rawValue: fields[2]), duration: duration, isVolley: fields[5] == "1",
                          server: AccountMatch.player(fields[6]))
    }

    /// Split on "|" with a loop (no CharacterSet splitting in Skip)
    static func split(_ text: String) -> [String] {
        var fields: [String] = []
        var current = ""
        for character in text {
            if character == "|" {
                fields.append(current)
                current = ""
            } else {
                current += String(character)
            }
        }
        fields.append(current)
        return fields
    }
}

/// A match as the app sends it to the account Worker (POST /api/v1/me/matches,
/// and inside a submission). `matchId` is the match's own id, so sending it again
/// never makes a second one.
public struct AccountMatchUpload: Codable, Equatable, Sendable {
    public var matchId: String
    /// Milliseconds since 1970
    public var playedAt: Int64
    public var opponent: String
    /// Team match: "<team match id>:E1"; nil otherwise
    public var teamKey: String?
    public var summary: AccountMatchSummary
    public var rallies: [AccountGame]

    public init(matchId: String, playedAt: Int64, opponent: String, teamKey: String?, summary: AccountMatchSummary, rallies: [AccountGame]) {
        self.matchId = matchId
        self.playedAt = playedAt
        self.opponent = opponent
        self.teamKey = teamKey
        self.summary = summary
        self.rallies = rallies
    }

    /// For BadgeEngine, oriented as the match was entered (`summary.mySide` is the player)
    public var badgeInput: BadgeMatchInput {
        AccountMatch.badgeInput(summary: summary, rallies: rallies)
    }

    /// The same match for the player on the other side
    public func forSide(_ side: Player) -> AccountMatchUpload {
        var copy = self
        copy.summary.me = AccountMatch.number(side)
        copy.opponent = copy.summary.opponentName
        return copy
    }
}

public enum AccountMatch {
    public static func number(_ player: Player) -> Int { player == Player.player2 ? 2 : 1 }

    static func player(_ text: String) -> Player? {
        if text == "1" { return Player.player1 }
        if text == "2" { return Player.player2 }
        return nil
    }

    /// 0 for nobody (a game or match not decided); one name for both would clash on the JVM
    static func numberOrZero(_ player: Player?) -> Int {
        guard let player else { return 0 }
        return number(player)
    }

    /// The compact form of a match. `me` is the side of the player it goes to.
    public static func upload(id: UUID, kind: String, input: BadgeMatchInput, player1Name: String, player2Name: String,
                              me: Player, teamKey: String? = nil, now: Date = Date()) -> AccountMatchUpload {
        var scores: [[Int]] = []
        var games: [AccountGame] = []
        for game in input.games {
            var p1 = 0
            var p2 = 0
            var rallies: [String] = []
            for rally in game.rallies {
                if rally.winner == Player.player1 { p1 += 1 } else { p2 += 1 }
                rallies.append(AccountRally.text(rally))
            }
            scores.append([p1, p2])
            games.append(AccountGame(winner: numberOrZero(game.winner), duration: game.duration, rallies: rallies))
        }
        var startedAt: Int64? = nil
        if let started = input.startedAt { startedAt = AuthSession.millis(started) }
        let summary = AccountMatchSummary(kind: kind, me: number(me), p1: player1Name, p2: player2Name,
                                          gamesToWin: input.gamesToWin,
                                          gamesBefore: [input.player1GamesBefore, input.player2GamesBefore],
                                          gamesWon: [input.player1GamesWon, input.player2GamesWon],
                                          winner: numberOrZero(input.matchWinner), scores: scores,
                                          duration: input.duration,
                                          recordsPointTypes: input.recordsPointTypes, startedAt: startedAt)
        return AccountMatchUpload(matchId: id.uuidString.uppercased(), playedAt: startedAt ?? AuthSession.millis(now),
                                  opponent: summary.opponentName, teamKey: teamKey, summary: summary, rallies: games)
    }

    public static func badgeInput(summary: AccountMatchSummary, rallies: [AccountGame]) -> BadgeMatchInput {
        var games: [BadgeGame] = []
        for game in rallies {
            var list: [BadgeRally] = []
            for text in game.rallies {
                if let rally = AccountRally.rally(text) { list.append(rally) }
            }
            games.append(BadgeGame(rallies: list, winner: player("\(game.winner)"), duration: game.duration))
        }
        var startedAt: Date? = nil
        if let millis = summary.startedAt { startedAt = Date(timeIntervalSince1970: Double(millis) / 1000.0) }
        let before = summary.gamesBefore.count == 2 ? summary.gamesBefore : [0, 0]
        let won = summary.gamesWon.count == 2 ? summary.gamesWon : [0, 0]
        return BadgeMatchInput(games: games, player1GamesBefore: before[0], player2GamesBefore: before[1],
                               player1GamesWon: won[0], player2GamesWon: won[1], matchWinner: player("\(summary.winner)"),
                               gamesToWin: summary.gamesToWin, recordsPointTypes: summary.recordsPointTypes,
                               duration: summary.duration, startedAt: startedAt, isPractice: false)
    }
}

public extension Match {
    /// The compact form for the player on `side`. Nil for an oefenpartij: those never leave the phone.
    func accountUpload(for side: Player, teamKey: String? = nil) -> AccountMatchUpload? {
        if PracticeMatches.shared.contains(id) { return nil }
        return AccountMatch.upload(id: id, kind: "coach", input: badgeInput, player1Name: player1Name,
                                   player2Name: player2Name, me: side, teamKey: teamKey)
    }
}

public extension RefereeMatch {
    /// The compact form for the player on `side`. Nil for an oefenpartij: those never leave the phone.
    func accountUpload(for side: Player, teamKey: String? = nil) -> AccountMatchUpload? {
        if PracticeMatches.shared.contains(id) { return nil }
        return AccountMatch.upload(id: id, kind: "referee", input: badgeInput, player1Name: player1Name,
                                   player2Name: player2Name, me: side, teamKey: teamKey)
    }
}
