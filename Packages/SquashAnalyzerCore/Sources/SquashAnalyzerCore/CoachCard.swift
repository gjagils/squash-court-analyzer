import Foundation

// De coachkaart (backlog C1, uitgewerkt met Gerd-Jan op 12 oktober 2026): one
// screen to show the player between games. The three most important points of
// the game from the local advice, and from game 2 on how they relate to the
// game before: still there, improved, or something that worked earlier and is
// gone now. Shared by iOS and Android; the screen is SharedCoachCardView.

/// How a point on the card relates to the games before
public enum CoachCardMark: Equatable, Sendable {
    /// First time in this match
    case new
    /// A work point that was also there in the game before ("Nog steeds")
    case stillThere
    /// A work point of the game before that is gone or smaller now ("Verbeterd!")
    case improved
    /// Something that went well in an earlier game and not in this one
    /// ("Pak dit op zoals je in game N deed")
    case pickUpAgain(game: Int)

    /// The label above the point; nil for a new point
    public var label: String? {
        switch self {
        case .new: return nil
        case .stillThere: return L10n.text("Nog steeds")
        case .improved: return L10n.text("Verbeterd!")
        case .pickUpAgain(let game): return L10n.text("Pak dit op zoals je in game %@ deed", "\(game)")
        }
    }
}

public struct CoachCardPoint: Equatable, Sendable {
    public let item: AdviceItem
    public let mark: CoachCardMark

    public init(item: AdviceItem, mark: CoachCardMark) {
        self.item = item
        self.mark = mark
    }
}

/// The card for one player after one game
public struct CoachCard: Equatable, Sendable {
    public let gameNumber: Int
    /// The match number of the game the points are compared with; nil in the first tracked game
    public let previousGameNumber: Int?
    /// The three most important points of this game, marked against the game before
    public let points: [CoachCardPoint]
    /// Since the game before: work points that went away and good things that went missing
    public let changes: [CoachCardPoint]

    public static let pointCount = 3
    /// At most this many lines under "Sinds game N"
    public static let changeCount = 2

    /// The card for `player` after the game at `gameIndex` (an index in `match.games`)
    public static func make(match: Match, gameIndex: Int, player: Player) -> CoachCard {
        let games = match.games
        let index = max(0, min(gameIndex, games.count - 1))
        let current = ranked(AdviceRules.candidates(in: games[index], for: player))
        let top = Array(current.prefix(pointCount))

        guard index > 0 else {
            var points: [CoachCardPoint] = []
            for candidate in top { points.append(CoachCardPoint(item: candidate.item, mark: CoachCardMark.new)) }
            return CoachCard(gameNumber: match.gameNumber(at: index), previousGameNumber: nil, points: points, changes: [])
        }

        // What the coach told the player after the game before
        let previous = ranked(AdviceRules.candidates(in: games[index - 1], for: player))
        let previousTop = Array(previous.prefix(pointCount))

        var points: [CoachCardPoint] = []
        for candidate in top {
            var mark = CoachCardMark.new
            if candidate.item.tone == AdviceTone.warning && previous.contains(where: { earlier in earlier.key == candidate.key }) {
                mark = CoachCardMark.stillThere
            }
            points.append(CoachCardPoint(item: candidate.item, mark: mark))
        }

        var changes: [CoachCardPoint] = []
        // A work point from the last card that is gone, or at most half as big
        for earlier in previousTop where earlier.item.tone == AdviceTone.warning {
            let now = current.first { candidate in candidate.key == earlier.key }
            if now == nil || now!.potential <= earlier.potential / 2.0 {
                changes.append(CoachCardPoint(item: earlier.item, mark: CoachCardMark.improved))
            }
        }
        // Something that went well in an earlier game (the most recent one first) and not now
        // (a plain while loop: the stride with a filtered inner loop behaved differently in Kotlin)
        var seenKeys: [String] = []
        var back = index - 1
        while back >= 0 {
            let earlierTop = Array(ranked(AdviceRules.candidates(in: games[back], for: player)).prefix(pointCount))
            for earlier in earlierTop {
                if earlier.item.tone != AdviceTone.success || seenKeys.contains(earlier.key) { continue }
                seenKeys.append(earlier.key)
                var stillThere = false
                for candidate in current where candidate.key == earlier.key { stillThere = true }
                if !stillThere {
                    changes.append(CoachCardPoint(item: earlier.item, mark: CoachCardMark.pickUpAgain(game: match.gameNumber(at: back))))
                }
            }
            back -= 1
        }
        return CoachCard(gameNumber: match.gameNumber(at: index), previousGameNumber: match.gameNumber(at: index - 1),
                         points: points, changes: Array(changes.prefix(changeCount)))
    }

    /// Whose card opens first: the player from Mijn team (`TeamRoster` ids);
    /// with both or neither in the team, player 1 (decision Gerd-Jan, 12 October 2026)
    public static func focus(player1Id: UUID?, player2Id: UUID?, team: [String]) -> Player {
        var inTeam: [String] = []
        for id in team { inTeam.append(id.lowercased()) }
        let first = player1Id.map { id in inTeam.contains(id.uuidString.lowercased()) } ?? false
        let second = player2Id.map { id in inTeam.contains(id.uuidString.lowercased()) } ?? false
        return second && !first ? Player.player2 : Player.player1
    }

    /// The dashboard's order: the most to gain first, a warning before a success at equal weight
    static func ranked(_ candidates: [AdviceCandidate]) -> [AdviceCandidate] {
        var sorted = candidates
        sorted.sort { first, second in
            if first.potential != second.potential { return first.potential > second.potential }
            let firstWarns = first.item.tone == AdviceTone.warning
            let secondWarns = second.item.tone == AdviceTone.warning
            if firstWarns != secondWarns { return firstWarns }
            return first.order < second.order
        }
        return sorted
    }
}
