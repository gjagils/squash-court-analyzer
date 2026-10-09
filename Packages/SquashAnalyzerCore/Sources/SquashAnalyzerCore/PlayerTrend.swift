import Foundation

// Spelersprofiel: how a player does over their matches instead of one match
// (backlog "Spelersprofiel met trend over wedstrijden", docs/wijzigingen-builds.md).
// Pure and shared with Android: the stores hand over the matches, the screen
// (SquashAnalyzerUI, SharedPlayerTrendView) only shows what is computed here.

/// One finished match of a player, seen from that player. Coach matches have
/// the kind of every point; referee matches only the score.
public struct PlayerTrendMatch: Equatable, Sendable {
    public let id: String
    public let date: Date
    /// Coach mode: points with their kind, shot and zone
    public let isCoach: Bool
    /// Nil while the match was not decided (stopped early)
    public let won: Bool?
    public let ownGames: Int
    public let theirGames: Int
    public let opponentName: String
    /// The opponent's player id, or the name in lower case when typed in
    public let opponentKey: String
    /// Coach mode: games with at least one point
    public var trackedGames: Int = 0
    /// Coach mode: own winners, and own unforced errors (the points the opponent got from them)
    public var winners: Int = 0
    public var unforcedErrors: Int = 0
    /// Coach mode: points won per winning shot (winners and forced errors)
    public var shotsWon: [ShotType: Int] = [:]
    /// Coach mode: own unforced errors per kind (only those with a kind)
    public var errorKinds: [ErrorKind: Int] = [:]
    /// Coach mode: where the player won and lost points
    public var zones = ZoneProfile()
    /// Coach mode: timed rallies won and lost, in seconds
    public var rallySecondsWon = 0.0
    public var ralliesWon = 0
    public var rallySecondsLost = 0.0
    public var ralliesLost = 0

    public init(id: String, date: Date, isCoach: Bool, won: Bool?, ownGames: Int, theirGames: Int,
                opponentName: String, opponentKey: String) {
        self.id = id
        self.date = date
        self.isCoach = isCoach
        self.won = won
        self.ownGames = ownGames
        self.theirGames = theirGames
        self.opponentName = opponentName
        self.opponentKey = opponentKey
    }

    /// Which side `playerId` played in a match with these ids; nil when not in it
    static func side(of playerId: String, player1Id: UUID?, player2Id: UUID?) -> Player? {
        let wanted = playerId.lowercased()
        if let id = player1Id, id.uuidString.lowercased() == wanted { return Player.player1 }
        if let id = player2Id, id.uuidString.lowercased() == wanted { return Player.player2 }
        return nil
    }

    static func key(id: UUID?, name: String) -> String {
        if let id { return id.uuidString.lowercased() }
        return name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The coach match seen from `playerId`; nil when that player is not in it
    public static func of(coach match: Match, playerId: String, date: Date) -> PlayerTrendMatch? {
        guard let player = side(of: playerId, player1Id: match.player1Id, player2Id: match.player2Id) else { return nil }
        let opponent = player.opponent
        let winner = match.matchWinner
        var result = PlayerTrendMatch(id: match.id.uuidString, date: date, isCoach: true,
                                      won: winner.map { decided in decided == player },
                                      ownGames: player == Player.player1 ? match.player1GamesWon : match.player2GamesWon,
                                      theirGames: player == Player.player1 ? match.player2GamesWon : match.player1GamesWon,
                                      opponentName: match.name(for: opponent),
                                      opponentKey: key(id: opponent == Player.player1 ? match.player1Id : match.player2Id,
                                                       name: match.name(for: opponent)))
        for game in match.games where !game.points.isEmpty {
            result.trackedGames += 1
            result.winners += game.winners(by: player).count
            result.unforcedErrors += game.unforcedErrors(by: opponent).count
            for point in game.attackingPoints(by: player) {
                if let shot = point.shotType { result.shotsWon[shot] = (result.shotsWon[shot] ?? 0) + 1 }
            }
            for (kind, count) in game.errorKindCounts(madeBy: player) {
                result.errorKinds[kind] = (result.errorKinds[kind] ?? 0) + count
            }
            result.zones = result.zones.adding(ZoneProfile.of(game, for: player))
            for point in game.timedPoints {
                if point.scorer == player {
                    result.rallySecondsWon += point.duration
                    result.ralliesWon += 1
                } else {
                    result.rallySecondsLost += point.duration
                    result.ralliesLost += 1
                }
            }
        }
        return result
    }

    /// The referee match seen from `playerId`: only the score
    public static func of(referee match: RefereeMatch, playerId: String, date: Date) -> PlayerTrendMatch? {
        guard let player = side(of: playerId, player1Id: match.player1Id, player2Id: match.player2Id) else { return nil }
        let opponent = player.opponent
        let winner = match.matchWinner
        return PlayerTrendMatch(id: match.id.uuidString, date: date, isCoach: false,
                                won: winner.map { decided in decided == player },
                                ownGames: player == Player.player1 ? match.player1TotalGames : match.player2TotalGames,
                                theirGames: player == Player.player1 ? match.player2TotalGames : match.player1TotalGames,
                                opponentName: match.name(for: opponent),
                                opponentKey: key(id: opponent == Player.player1 ? match.player1Id : match.player2Id,
                                                 name: match.name(for: opponent)))
    }
}

extension AreaTally {
    /// Both tallies together
    public func adding(_ other: AreaTally) -> AreaTally {
        var result = self
        result.front += other.front
        result.middle += other.middle
        result.back += other.back
        result.left += other.left
        result.right += other.right
        return result
    }
}

extension ZoneProfile {
    public func adding(_ other: ZoneProfile) -> ZoneProfile {
        var result = self
        result.won = won.adding(other.won)
        result.lost = lost.adding(other.lost)
        result.errors = errors.adding(other.errors)
        return result
    }
}

/// How far back the profile looks
public enum PlayerTrendPeriod: Int, CaseIterable, Identifiable, Sendable {
    case last10 = 10
    case last25 = 25
    case all = 0

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .last10: return "Laatste 10"
        case .last25: return "Laatste 25"
        case .all: return "Alles"
        }
    }
}

/// One winning shot's share of all points won with a shot
public struct PlayerTrendShot: Equatable, Sendable {
    public let shot: ShotType
    public let count: Int
    /// 0...100
    public let percentage: Int
}

/// Matches against one opponent
public struct PlayerTrendOpponent: Equatable, Sendable {
    public let name: String
    public let won: Int
    public let lost: Int

    public var played: Int { won + lost }
}

/// Everything the profile shows, for one period
public struct PlayerTrendSummary: Equatable, Sendable {
    /// The matches in the period, oldest first
    public let matches: [PlayerTrendMatch]
    public let won: Int
    public let lost: Int
    /// The last 10 decided matches, oldest first
    public let form: [PlayerTrendMatch]
    /// Coach matches with tracked games, oldest first: the lines
    public let coachMatches: [PlayerTrendMatch]
    public let topShots: [PlayerTrendShot]
    public let commonError: ErrorKind?
    public let commonErrorCount: Int
    public let zones: ZoneProfile
    public let averageRallyWon: Double?
    public let averageRallyLost: Double?
    public let opponents: [PlayerTrendOpponent]

    public static let formLength = 10
    /// The halves need at least this many coach matches to say "van … naar …"
    public static let minimumForChange = 4

    public init(from all: [PlayerTrendMatch], period: PlayerTrendPeriod) {
        var ordered = all.sorted { a, b in a.date < b.date }
        if period != PlayerTrendPeriod.all && ordered.count > period.rawValue {
            ordered = Array(ordered.suffix(period.rawValue))
        }
        matches = ordered
        var wins = 0
        var losses = 0
        var decided: [PlayerTrendMatch] = []
        var coach: [PlayerTrendMatch] = []
        var shots: [ShotType: Int] = [:]
        var errors: [ErrorKind: Int] = [:]
        var zoneTotal = ZoneProfile()
        var secondsWon = 0.0
        var countWon = 0
        var secondsLost = 0.0
        var countLost = 0
        for match in ordered {
            if let result = match.won {
                if result { wins += 1 } else { losses += 1 }
                decided.append(match)
            }
            if match.isCoach && match.trackedGames > 0 {
                coach.append(match)
                for (shot, count) in match.shotsWon { shots[shot] = (shots[shot] ?? 0) + count }
                for (kind, count) in match.errorKinds { errors[kind] = (errors[kind] ?? 0) + count }
                zoneTotal = zoneTotal.adding(match.zones)
                secondsWon += match.rallySecondsWon
                countWon += match.ralliesWon
                secondsLost += match.rallySecondsLost
                countLost += match.ralliesLost
            }
        }
        won = wins
        lost = losses
        form = Array(decided.suffix(PlayerTrendSummary.formLength))
        coachMatches = coach
        zones = zoneTotal
        averageRallyWon = countWon > 0 ? secondsWon / Double(countWon) : nil
        averageRallyLost = countLost > 0 ? secondsLost / Double(countLost) : nil

        var shotTotal = 0
        for (_, count) in shots { shotTotal += count }
        var shotList: [PlayerTrendShot] = []
        for shot in ShotType.allCases {
            let count = shots[shot] ?? 0
            if count > 0 {
                shotList.append(PlayerTrendShot(shot: shot, count: count, percentage: Int((Double(count) * 100.0 / Double(shotTotal)).rounded())))
            }
        }
        // Most first; equal counts keep the order of the shot buttons
        shotList.sort { a, b in a.count > b.count }
        topShots = Array(shotList.prefix(3))

        var bestError: ErrorKind? = nil
        var bestErrorCount = 0
        for kind in ErrorKind.allCases {
            let count = errors[kind] ?? 0
            if count > bestErrorCount {
                bestError = kind
                bestErrorCount = count
            }
        }
        commonError = bestError
        commonErrorCount = bestErrorCount

        // Opponents: most matches first, then most recent
        var keys: [String] = []
        var names: [String: String] = [:]
        var wonAgainst: [String: Int] = [:]
        var lostAgainst: [String: Int] = [:]
        for match in decided.reversed() where !match.opponentKey.isEmpty {
            if names[match.opponentKey] == nil {
                keys.append(match.opponentKey)
                names[match.opponentKey] = match.opponentName
            }
            if match.won == true {
                wonAgainst[match.opponentKey] = (wonAgainst[match.opponentKey] ?? 0) + 1
            } else {
                lostAgainst[match.opponentKey] = (lostAgainst[match.opponentKey] ?? 0) + 1
            }
        }
        var records: [PlayerTrendOpponent] = []
        for key in keys {
            records.append(PlayerTrendOpponent(name: names[key] ?? "", won: wonAgainst[key] ?? 0, lost: lostAgainst[key] ?? 0))
        }
        records.sort { a, b in a.played > b.played }
        opponents = Array(records.prefix(3))
    }

    public var played: Int { matches.count }

    /// Won of the decided matches, 0...100; nil without any
    public var winPercentage: Int? {
        let decided = won + lost
        guard decided > 0 else { return nil }
        return Int((Double(won) * 100.0 / Double(decided)).rounded())
    }

    /// Per coach match, oldest first
    public var winnersPerGame: [Double] { PlayerTrendSummary.perGame(coachMatches) { match in match.winners } }
    public var errorsPerGame: [Double] { PlayerTrendSummary.perGame(coachMatches) { match in match.unforcedErrors } }

    static func perGame(_ matches: [PlayerTrendMatch], _ value: (PlayerTrendMatch) -> Int) -> [Double] {
        var result: [Double] = []
        for match in matches { result.append(Double(value(match)) / Double(max(1, match.trackedGames))) }
        return result
    }

    /// The average per game of the first and of the last half of the coach
    /// matches ("van 3,1 naar 2,4"); nil with too few matches
    public static func change(_ values: [Double]) -> PlayerTrendChange? {
        guard values.count >= minimumForChange else { return nil }
        let half = values.count / 2
        var first = 0.0
        for value in values.prefix(half) { first += value }
        var last = 0.0
        for value in values.suffix(half) { last += value }
        return PlayerTrendChange(from: first / Double(half), to: last / Double(half))
    }

    /// The row or side where the player wins most, and where they lose most:
    /// one sentence for the court card; nil without enough points
    public var strongestArea: String? { PlayerTrendSummary.area(zones.won) }
    public var weakestArea: String? { PlayerTrendSummary.area(zones.lost) }

    static func area(_ tally: AreaTally) -> String? {
        if let row = tally.dominantRow { return row.inWords }
        if let side = tally.dominantSide { return side.inWords }
        return nil
    }
}

/// An average that went from one value to another
public struct PlayerTrendChange: Equatable, Sendable {
    public let from: Double
    public let to: Double

    /// "3,1" with a decimal comma
    public static func text(_ value: Double) -> String {
        let tenths = Int((value * 10.0).rounded())
        return "\(tenths / 10),\(tenths % 10)"
    }

    public var text: String { "van \(PlayerTrendChange.text(from)) naar \(PlayerTrendChange.text(to))" }
}

extension MatchHistoryStore {
    /// Every finished match of the player on this device, from the history
    /// (only players picked with "Kies speler" are linked to a match)
    public func trendMatches(forPlayer playerId: String) async throws -> [PlayerTrendMatch] {
        var result: [PlayerTrendMatch] = []
        for entry in try await loadHistory() {
            if entry.kind == "coach" {
                if let match = try await coachMatch(id: entry.id),
                   let seen = PlayerTrendMatch.of(coach: match, playerId: playerId, date: entry.updatedAt) {
                    result.append(seen)
                }
            } else if let match = try await refereeMatch(id: entry.id),
                      let seen = PlayerTrendMatch.of(referee: match, playerId: playerId, date: entry.updatedAt) {
                result.append(seen)
            }
        }
        return result
    }
}
