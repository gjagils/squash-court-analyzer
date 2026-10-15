import ActivityKit
import Foundation

// Live score op het vergrendelscherm: the Live Activity of a followed match
// (updated by the live server through APNs) or of the match this phone is
// scoring (updated locally). Compiled into both the app and the widget
// extension SquashLiveActivity, which does not link SquashAnalyzerCore: the
// content state mirrors Core's `LiveSnapshot` field by field.

struct LiveScoreAttributes: ActivityAttributes {
    /// Exactly the snapshot JSON of the live server (`aps.content-state` of a
    /// liveactivity push): {p1,p2,bestOf,games,score,gamesWon,server,side,status,lastPoint?,winner?}.
    /// Property names must stay identical; `status` is a String so an unknown
    /// value from a newer server does not break decoding.
    struct ContentState: Codable, Hashable {
        var p1: String
        var p2: String
        var bestOf: Int
        /// Finished games as [player 1, player 2]
        var games: [[Int]]
        /// The game under way (or just finished) as [player 1, player 2]
        var score: [Int]
        /// Games won, head start included, as [player 1, player 2]
        var gamesWon: [Int]
        /// 1 or 2
        var server: Int
        /// "L" or "R"
        var side: String
        /// "warmup", "playing", "between" or "finished"
        var status: String
        var lastPoint: String?
        var winner: Int?
    }

    /// The live session id (followed match) or the match UUID (own match)
    var matchId: String
    /// "https://live.squashanalyzer.com"; empty for an own match
    var server: String
    /// The match this phone is scoring (no pushes, updated locally)
    var isOwnMatch: Bool
    /// Start of the match timer in the header, when known
    var startedAt: Date?
}

/// The badge on the right of the header
enum LiveScoreBadge: Equatable {
    case gameBall
    case matchBall
    case pause
    case finished

    var title: String {
        switch self {
        case .gameBall: return "GAMEBAL"
        case .matchBall: return "MATCHBAL"
        case .pause: return "PAUZE"
        case .finished: return "AFGELOPEN"
        }
    }
}

/// Everything the lock screen and the Dynamic Island show, worked out from
/// the content state (unit tested in SquashAnalyzerTests/LiveScoreAttributesTests)
extension LiveScoreAttributes.ContentState {
    var isFinished: Bool { status == "finished" }
    var isBetween: Bool { status == "between" }
    var isWarmup: Bool { status == "warmup" }
    var isPlaying: Bool { !isFinished && !isBetween && !isWarmup }

    func value(_ list: [Int], _ player: Int) -> Int {
        let index = player - 1
        return index >= 0 && index < list.count ? list[index] : 0
    }

    func name(_ player: Int) -> String { player == 1 ? p1 : p2 }

    /// Games needed to win the match: 3 in a best of 5
    var gamesToWin: Int { max(1, bestOf / 2 + 1) }

    /// Games played so far, head start included
    var gamesPlayed: Int { value(gamesWon, 1) + value(gamesWon, 2) }

    /// The game the header names: the one under way, or the one just finished
    /// during the break and at the end
    var gameNumber: Int {
        if isBetween || isFinished { return max(1, gamesPlayed) }
        return gamesPlayed + 1
    }

    /// The last finished game, during the break
    var lastGame: [Int]? { games.last }

    /// The big number per player: the games won once the match is over, the
    /// result of the last game during the break, otherwise the rally score
    func shownScore(_ player: Int) -> Int {
        if isFinished { return value(gamesWon, player) }
        if isBetween, score == [0, 0], let last = lastGame { return value(last, player) }
        return value(score, player)
    }

    /// The player who wins the game with the next rally (PAR-11, win by 2)
    var gameBallPlayer: Int? {
        guard isPlaying else { return nil }
        for player in [1, 2] {
            let own = value(score, player)
            let other = value(score, 3 - player)
            if own + 1 >= 11 && own + 1 - other >= 2 { return player }
        }
        return nil
    }

    /// Game ball that would also win the match
    var isMatchBall: Bool {
        guard let player = gameBallPlayer else { return false }
        return value(gamesWon, player) + 1 == gamesToWin
    }

    var badge: LiveScoreBadge? {
        if isFinished { return .finished }
        if isBetween { return .pause }
        if gameBallPlayer != nil { return isMatchBall ? .matchBall : .gameBall }
        return nil
    }

    /// The server dot shows only while rallies are played
    func isServing(_ player: Int) -> Bool {
        (isPlaying || isWarmup) && server == player
    }

    /// "Live · Game 3", "Live · Warming-up", "Uitslag · Jan wint"
    var headerTitle: String {
        if isFinished {
            if let winner, winner == 1 || winner == 2 { return "Uitslag · \(name(winner)) wint" }
            return "Uitslag"
        }
        if isWarmup { return "Live · Warming-up" }
        return "Live · Game \(gameNumber)"
    }

    /// "11–8 · 6–11"
    static func gameList(_ games: [[Int]]) -> String {
        var parts: [String] = []
        for game in games where game.count == 2 {
            parts.append("\(game[0])–\(game[1])")
        }
        return parts.joined(separator: " · ")
    }

    /// Left in the footer
    var footerLeading: String {
        if isFinished { return LiveScoreAttributes.ContentState.gameList(games) }
        if isBetween { return "Game \(gamesPlayed + 1) begint zo" }
        if games.isEmpty { return lastPoint ?? "" }
        return "Games " + LiveScoreAttributes.ContentState.gameList(games)
    }

    /// Right in the footer: the box the server serves from
    var footerTrailing: String {
        guard isPlaying || isWarmup else { return "" }
        return serviceText
    }

    var serviceText: String { side == "L" ? "Opslag links" : "Opslag rechts" }

    /// The expanded Dynamic Island's bottom line: "Game 3 · 11–8 · 6–11"
    var islandLine: String {
        if isFinished { return LiveScoreAttributes.ContentState.gameList(games) }
        if isBetween { return "Pauze · game \(gamesPlayed + 1) begint zo" }
        let list = LiveScoreAttributes.ContentState.gameList(games)
        let head = isWarmup ? "Warming-up" : "Game \(gameNumber)"
        return list.isEmpty ? head : head + " · " + list
    }

    /// Minimal Dynamic Island: "9·7"
    var minimalText: String { "\(shownScore(1))·\(shownScore(2))" }

    /// Filled pips per player: the games won (head start included)
    func pips(_ player: Int) -> Int { min(value(gamesWon, player), gamesToWin) }
}
