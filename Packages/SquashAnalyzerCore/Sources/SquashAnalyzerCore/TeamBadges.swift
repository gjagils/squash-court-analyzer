import Foundation

// MARK: - Competitiebadges (4.0, T7)

/// The competition badges, earned from the team matches on this device rather
/// than from one coach or referee match (decision Gerd-Jan, 10 November 2026):
///
/// - **Teamspeler** (bronze 3, silver 8, gold 15): partijen played for your
///   team. A partij counts once it is decided; a walkover was not played and
///   counts for nobody. Each tier once per card, awarded at the partij that
///   reached it.
/// - **Matchwinnaar**: you won the partij that decided the team match. Your
///   team won, and had you lost this partij (the same games the other way
///   round) it would not have won. A 4-0 has no Matchwinnaar, a 3-1 has three
///   when the team would also lose a 2-2. Can be earned again in every team match.
///
/// Only the own team's partijen (`TeamMatch.ownSide`), only from the badge
/// start (`BadgeSeason`). A partij belongs to the player in Spelers with the
/// same name (`key`); the apps award to that player's card and keep the awards
/// in line with the team matches (`BadgeAwarder.syncTeamAwards` on iOS,
/// `BadgeAwardStore.syncTeamAwards` on Android).
public enum TeamBadges {
    /// One award for the player named `playerName`
    public struct Award: Equatable, Sendable {
        public let playerName: String
        public let badge: BadgeKind
        /// The partij it was earned in (`partijId`), so every device makes the same award id
        public let matchId: UUID
        public let earnedAt: Date
        public let opponentName: String

        public init(playerName: String, badge: BadgeKind, matchId: UUID, earnedAt: Date, opponentName: String) {
            self.playerName = playerName
            self.badge = badge
            self.matchId = matchId
            self.earnedAt = earnedAt
            self.opponentName = opponentName
        }
    }

    /// One decided partij of the own team, as the badge rules see it
    public struct Entry: Equatable, Sendable {
        public let playerName: String
        public let opponentName: String
        public let matchId: UUID
        public let date: Date
        public let slot: Int
        public let won: Bool
        public let decisive: Bool
    }

    /// The stable id of partij `slot` of a team match, the same on every device
    /// (the same hash as an award id, see `AwardValue.awardId`)
    public static func partijId(teamMatchId: UUID, slot: Int) -> UUID {
        AwardValue.awardId(cardId: teamMatchId, badge: BadgeKind.matchWinner,
                           matchId: UUID(uuidString: "5A1E0000-0000-4000-8000-00000000040\(min(max(slot, 1), 9))")!)
    }

    /// The name as matched against Spelers: lowercased, spaces trimmed and collapsed
    public static func key(_ name: String) -> String {
        var kept = ""
        var lastWasSpace = true
        for character in name.lowercased() {
            if character == " " || character == "\t" || character == "\n" {
                if !lastWasSpace { kept += " " }
                lastWasSpace = true
            } else {
                kept += String(character)
                lastWasSpace = false
            }
        }
        if kept.hasSuffix(" ") { kept = String(kept.dropLast()) }
        return kept
    }

    /// The decided partijen of the own team in `matches`, oldest first
    public static func entries(from matches: [TeamMatch], start: Date? = BadgeSeason.start, now: Date = Date()) -> [Entry] {
        var result: [Entry] = []
        for match in distinct(matches) where BadgeSeason.counts(match.date, start: start, now: now) {
            let teamWon = match.score.ownWon == true
            for partij in match.partijen {
                guard let won = partij.ownWon, partij.endedBy != TeamPartijEnd.walkover else { continue }
                let name = partij.ownPlayer.trimmingCharacters(in: .whitespaces)
                guard !key(name).isEmpty, key(name) != key(match.defaultOwnName(partij.slot)) else { continue }
                let decisive = teamWon && won && !wins(match, flipping: partij.slot)
                result.append(Entry(playerName: name, opponentName: match.opponentDisplayName(partij),
                                    matchId: partijId(teamMatchId: match.id, slot: partij.slot),
                                    date: match.date, slot: partij.slot, won: won, decisive: decisive))
            }
        }
        result.sort { a, b in a.date == b.date ? a.slot < b.slot : a.date < b.date }
        return result
    }

    /// One team match per SBN match: two copies of the same fixture on one
    /// phone (made before 4.0 could find the other) count once, the newest
    static func distinct(_ matches: [TeamMatch]) -> [TeamMatch] {
        var newest: [String: TeamMatch] = [:]
        var result: [TeamMatch] = []
        for match in matches {
            guard let fixture = match.fixtureId, !fixture.isEmpty else {
                result.append(match)
                continue
            }
            if let other = newest[fixture], other.updatedAt >= match.updatedAt { continue }
            newest[fixture] = match
        }
        for (_, match) in newest { result.append(match) }
        return result
    }

    /// Whether the own team still wins with partij `slot` lost (its games the other way round)
    static func wins(_ match: TeamMatch, flipping slot: Int) -> Bool {
        var flipped = match
        for index in 0..<flipped.partijen.count where flipped.partijen[index].slot == slot {
            var partij = flipped.partijen[index]
            var games: [TeamGame] = []
            for game in partij.games {
                games.append(TeamGame(ownPoints: game.theirPoints, theirPoints: game.ownPoints, ownWon: !game.ownWon))
            }
            partij.games = games
            flipped.partijen[index] = partij
        }
        return flipped.score.ownWon == true
    }

    /// Every competition award the team matches give, per player name
    public static func awards(from matches: [TeamMatch], start: Date? = BadgeSeason.start, now: Date = Date()) -> [Award] {
        var result: [Award] = []
        var played: [String: Int] = [:]
        for entry in entries(from: matches, start: start, now: now) {
            let player = key(entry.playerName)
            let count = (played[player] ?? 0) + 1
            played[player] = count
            for kind in BadgeKind.series(of: BadgeKind.teamPlayer) where kind.threshold == count {
                result.append(Award(playerName: entry.playerName, badge: kind, matchId: entry.matchId,
                                    earnedAt: entry.date, opponentName: entry.opponentName))
            }
            if entry.decisive {
                result.append(Award(playerName: entry.playerName, badge: BadgeKind.matchWinner, matchId: entry.matchId,
                                    earnedAt: entry.date, opponentName: entry.opponentName))
            }
        }
        return result
    }

    /// The awards for the player named `name`
    public static func awards(for name: String, in awards: [Award]) -> [Award] {
        let wanted = key(name)
        return awards.filter { award in key(award.playerName) == wanted }
    }
}
