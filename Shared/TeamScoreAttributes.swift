import ActivityKit
import Foundation

// Live score op het vergrendelscherm for a team match (Competitie, /t/<id>):
// the four partijen of one evening on one Live Activity, updated by the live
// server through APNs. Compiled into the app and the widget extension, which
// does not link SquashAnalyzerCore: the content state mirrors Core's
// `TeamFollowStand` field by field (the server's teamContentState in push.js).

struct TeamScoreAttributes: ActivityAttributes {
    /// Exactly the team push of the live server (`aps.content-state`):
    /// {home, away, partijen:[{slot,p1,p2,bestOf,gamesWon,score,status,winner?,end?}]}.
    /// Only the slots that have a partij, by slot. Property names must stay identical.
    struct ContentState: Codable, Hashable {
        var home: String
        var away: String
        var partijen: [TeamScorePartij]
    }

    /// The live team match id (/t/<id>)
    var teamId: String
    /// "https://live.squashanalyzer.com"
    var server: String
}

/// One partij, home player first (`p1`); names may be empty
struct TeamScorePartij: Codable, Hashable {
    var slot: Int
    var p1: String
    var p2: String
    var bestOf: Int
    /// Games won, [home, away]
    var gamesWon: [Int]
    /// The game under way, [home, away]
    var score: [Int]
    /// "warmup", "playing", "between" or "finished"
    var status: String
    var winner: Int?
    /// "retired" or "walkover"
    var end: String?

    func value(_ list: [Int], _ side: Int) -> Int {
        let index = side - 1
        return index >= 0 && index < list.count ? list[index] : 0
    }

    func games(_ side: Int) -> Int { value(gamesWon, side) }
    func points(_ side: Int) -> Int { value(score, side) }

    /// Decided as the server and the team page count it
    var isDecided: Bool {
        winner == 1 || winner == 2 || status == "finished" || end == "retired" || end == "walkover"
    }

    /// Being played now (the red current points)
    var isLive: Bool { !isDecided && (status == "playing" || status == "between") }

    /// 1 home, 2 away, 0 not known: the winner, else whoever has more games
    var winnerSide: Int {
        if let winner, winner == 1 || winner == 2 { return winner }
        guard isDecided else { return 0 }
        if games(1) > games(2) { return 1 }
        if games(2) > games(1) { return 2 }
        return 0
    }
}

/// What the middle of a partij row shows
enum TeamScoreRowMiddle: Equatable {
    /// "● 7–5": the points of the game under way
    case live(String)
    /// "klaar"
    case decided
    /// "–": not started, or no partij yet
    case none
}

/// Everything the lock screen and the Dynamic Island show, worked out from
/// the content state (unit tested in SquashAnalyzerTests/TeamScoreAttributesTests)
extension TeamScoreAttributes.ContentState {
    static let slots = [1, 2, 3, 4]

    func partij(_ slot: Int) -> TeamScorePartij? {
        for partij in partijen where partij.slot == slot { return partij }
        return nil
    }

    /// Games won by home (1) or away (2) over all partijen, as the team page counts them
    func games(_ side: Int) -> Int {
        var total = 0
        for partij in partijen { total += partij.games(side) }
        return total
    }

    /// Partijen won by home (1) or away (2)
    func partijenWon(_ side: Int) -> Int {
        var count = 0
        for partij in partijen where partij.winnerSide == side { count += 1 }
        return count
    }

    var decidedCount: Int {
        var count = 0
        for partij in partijen where partij.isDecided { count += 1 }
        return count
    }

    /// All four partijen decided
    var isFinished: Bool {
        for slot in Self.slots {
            guard let partij = partij(slot), partij.isDecided else { return false }
        }
        return true
    }

    /// A partij is being played
    var hasLive: Bool { partijen.contains { partij in partij.isLive } }

    /// "2 van 4 klaar"
    var progressText: String { "\(decidedCount) van 4 klaar" }

    func teamName(_ side: Int) -> String { side == 1 ? home : away }

    /// The player's name in a row: the first name, or "Delft 8 E2" without one
    func name(slot: Int, side: Int) -> String {
        if let partij = partij(slot) {
            let given = (side == 1 ? partij.p1 : partij.p2).trimmingCharacters(in: .whitespaces)
            if !given.isEmpty { return given }
        }
        return teamName(side) + " E\(slot)"
    }

    /// Whether the row has a real name (else it is greyed)
    func hasName(slot: Int, side: Int) -> Bool {
        guard let partij = partij(slot) else { return false }
        return !(side == 1 ? partij.p1 : partij.p2).trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The first letter of the name, in the circle when there is no photo
    func initial(slot: Int, side: Int) -> String {
        guard hasName(slot: slot, side: side), let first = name(slot: slot, side: side).first else { return "" }
        return String(first).uppercased()
    }

    func middle(_ slot: Int) -> TeamScoreRowMiddle {
        guard let partij = partij(slot) else { return .none }
        if partij.isDecided { return .decided }
        if partij.isLive { return .live("\(partij.points(1))–\(partij.points(2))") }
        return .none
    }

    /// The winner of the evening by the SBN rule as far as the lock screen
    /// knows it (no rally points in the push): most partijen; equal → a full
    /// line-up (a lost walkover is not); → most games; → whoever won E1.
    /// 1 home, 2 away, 0 a draw. The server's alert text is authoritative.
    var teamWinner: Int {
        let home = partijenWon(1)
        let away = partijenWon(2)
        if home != away { return home > away ? 1 : 2 }
        var full = [true, true]
        for partij in partijen where partij.end == "walkover" {
            let winner = partij.winnerSide
            if winner == 1 || winner == 2 { full[2 - winner] = false }
        }
        if full[0] != full[1] { return full[0] ? 1 : 2 }
        if games(1) != games(2) { return games(1) > games(2) ? 1 : 2 }
        return partij(1)?.winnerSide ?? 0
    }

    /// "Uitslag: All Inn 8 wint 9–4" (the winner's games first) or "Uitslag: gelijkspel 6–6"
    var resultTitle: String {
        let winner = teamWinner
        if winner == 0 { return "Uitslag: gelijkspel \(games(1))–\(games(2))" }
        return "Uitslag: \(teamName(winner)) wint \(games(winner))–\(games(3 - winner))"
    }

    /// Compact Dynamic Island and minimal: the games per team
    var minimalText: String { "\(games(1))·\(games(2))" }
}

/// The partij photos of a team match for the Live Activity, in the same App
/// Group folder as a single match (LiveScorePhotoStore), under the key
/// "<teamId>-<slot>" with player 1 = home, 2 = away
enum TeamScorePhotoStore {
    static func key(teamId: String, slot: Int) -> String { "\(teamId)-\(slot)" }

    /// The keys of all four slots, to keep them when unused photos are removed
    static func keys(teamId: String) -> [String] {
        TeamScoreAttributes.ContentState.slots.map { slot in key(teamId: teamId, slot: slot) }
    }

    static func remove(teamId: String) {
        for key in keys(teamId: teamId) { LiveScorePhotoStore.remove(matchId: key) }
    }
}
