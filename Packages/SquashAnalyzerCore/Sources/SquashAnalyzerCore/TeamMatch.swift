import Foundation

// MARK: - Competitie: een SBN-teamwedstrijd van vier partijen
//
// An SBN team match is four singles (E1–E4, best of five to 11). The result
// is the games won over the four partijen; competition points are those
// games plus 3 bonus points for the winner. Winner: most games; tie → most
// partijen won; still tied → most rally points (rules confirmed by Gerd-Jan,
// October 2026). Everything here is pure and shared with Android; the
// screens live in SquashAnalyzerUI, the file store (TeamMatchStore.swift) is used by both
// platforms.

/// Home or away: which side of a team match
public enum TeamSide: String, Codable, CaseIterable, Sendable {
    case home, away

    public var other: TeamSide { self == .home ? .away : .home }
}

/// One game of a partij, seen from our player. The points may be unknown
/// (a partij filled in from memory, or a game before "Later instappen");
/// who won is always known.
public struct TeamGame: Codable, Equatable, Sendable {
    public var ownPoints: Int?
    public var theirPoints: Int?
    public var ownWon: Bool

    public init(ownPoints: Int?, theirPoints: Int?, ownWon: Bool) {
        self.ownPoints = ownPoints
        self.theirPoints = theirPoints
        self.ownWon = ownWon
    }

    /// A game with its score; the winner follows from the points
    public init(own: Int, their: Int) {
        self.ownPoints = own
        self.theirPoints = their
        self.ownWon = own > their
    }

    public var hasPoints: Bool { ownPoints != nil && theirPoints != nil }

    /// "11-8", or "–" when only the winner is known
    public var text: String {
        guard let own = ownPoints, let their = theirPoints else { return "–" }
        return "\(own)-\(their)"
    }

    /// A squash game: to 11, two clear, so 11-9, 12-10, 15-13 but not 11-10
    public static func isValidScore(_ a: Int, _ b: Int) -> Bool {
        let high = max(a, b)
        let low = min(a, b)
        if high < 11 || low < 0 { return false }
        if high == 11 { return low <= 9 }
        return high - low == 2
    }
}

/// One of the four partijen (E1–E4) of a team match
public struct TeamPartij: Codable, Equatable, Sendable {
    /// 1...4: E1 is the strongest player of each team
    public var slot: Int
    public var ownPlayer: String
    public var opponentPlayer: String
    public var games: [TeamGame]
    /// The order played on the evening (1...4), when known
    public var playOrder: Int?
    /// A coach or referee match on this phone the games came from
    /// (`MatchHistorySummary.id` and `.kind`)
    public var linkedMatchId: String?
    public var linkedKind: String?
    public var bestOf: Int
    /// Taken over from the live page (another phone's partij); a local edit makes it ours
    public var fromLive: Bool?
    /// A coach or referee match started for this partij that is not finished
    /// yet (its id), and whether our player is its Speler 1: resuming that
    /// match picks the coupling up again. Cleared when the result is linked.
    public var trackingMatchId: String?
    public var trackingOwnIsPlayer1: Bool?
    /// Whether our player was Speler 1 of the linked match, as chosen when it
    /// was linked: "Vernieuwen" must not guess it again from a name that can
    /// be edited in the meantime
    public var linkedOwnIsPlayer1: Bool?

    public init(slot: Int, ownPlayer: String = "", opponentPlayer: String = "", games: [TeamGame] = [],
                playOrder: Int? = nil, linkedMatchId: String? = nil, linkedKind: String? = nil, bestOf: Int = 5) {
        self.slot = slot
        self.ownPlayer = ownPlayer
        self.opponentPlayer = opponentPlayer
        self.games = games
        self.playOrder = playOrder
        self.linkedMatchId = linkedMatchId
        self.linkedKind = linkedKind
        self.bestOf = bestOf
    }

    public var label: String { "E\(slot)" }
    public var gamesToWin: Int { MatchStand.gamesToWin(bestOf: bestOf) }

    public var ownGames: Int {
        var count = 0
        for game in games where game.ownWon { count += 1 }
        return count
    }

    public var theirGames: Int { games.count - ownGames }

    /// Rally points of the games whose score is known
    public var ownPoints: Int {
        var total = 0
        for game in games { total += game.ownPoints ?? 0 }
        return total
    }

    public var theirPoints: Int {
        var total = 0
        for game in games { total += game.theirPoints ?? 0 }
        return total
    }

    /// Every game has its score, so the rally points can break a tie
    public var hasAllPoints: Bool {
        for game in games where !game.hasPoints { return false }
        return true
    }

    public var hasEntry: Bool { !games.isEmpty }
    public var isLinked: Bool { linkedMatchId != nil }
    public var isOver: Bool { ownGames >= gamesToWin || theirGames >= gamesToWin }

    /// Decided: did our player win? Nil while the partij is not over
    public var ownWon: Bool? {
        guard isOver else { return nil }
        return ownGames > theirGames
    }

    /// A decided partij takes no more games; neither does a full one
    public var canAddGame: Bool { !isOver && games.count < bestOf }

    /// "3-1" in games
    public var standText: String { "\(ownGames)-\(theirGames)" }

    /// "11-8, 9-11, 11-6, 11-9"
    public var gamesText: String {
        var parts: [String] = []
        for game in games { parts.append(game.text) }
        return parts.joined(separator: ", ")
    }

    /// A game is only accepted while the partij is open; a scored game must
    /// be a real squash score
    public mutating func addGame(_ game: TeamGame) -> Bool {
        guard canAddGame else { return false }
        if let own = game.ownPoints, let their = game.theirPoints, !TeamGame.isValidScore(own, their) { return false }
        games.append(game)
        return true
    }

    public mutating func removeLastGame() {
        if !games.isEmpty { games.removeLast() }
    }

    /// The games of a tracked coach or referee match, seen from our player.
    /// Games played before scoring started or filled in afterwards have no
    /// score; only who won them is known (from the stand).
    public static func linkedGames(from summary: MatchHistorySummary, ownIsPlayer1: Bool) -> [TeamGame] {
        var result: [TeamGame] = []
        var trackedPlayer1 = 0
        var trackedPlayer2 = 0
        for game in summary.games {
            let player1Won = game.winner == Player.player1.rawValue
            if player1Won { trackedPlayer1 += 1 } else { trackedPlayer2 += 1 }
            let own = ownIsPlayer1 ? game.player1Score : game.player2Score
            let their = ownIsPlayer1 ? game.player2Score : game.player1Score
            result.append(TeamGame(ownPoints: own, theirPoints: their, ownWon: player1Won == ownIsPlayer1))
        }
        let untrackedPlayer1 = max(0, summary.player1Games - trackedPlayer1)
        let untrackedPlayer2 = max(0, summary.player2Games - trackedPlayer2)
        for _ in 0..<untrackedPlayer1 { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: ownIsPlayer1)) }
        for _ in 0..<untrackedPlayer2 { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: !ownIsPlayer1)) }
        return result
    }

    /// Takes the names and games of a tracked match; "Vernieuwen" does the same again
    public mutating func link(_ summary: MatchHistorySummary, ownIsPlayer1: Bool) {
        ownPlayer = ownIsPlayer1 ? summary.player1Name : summary.player2Name
        opponentPlayer = ownIsPlayer1 ? summary.player2Name : summary.player1Name
        games = TeamPartij.linkedGames(from: summary, ownIsPlayer1: ownIsPlayer1)
        linkedMatchId = summary.id
        linkedKind = summary.kind
        linkedOwnIsPlayer1 = ownIsPlayer1
        trackingMatchId = nil
        trackingOwnIsPlayer1 = nil
        bestOf = summary.bestOf
    }

    /// Reads the linked match again (e.g. after its result was completed),
    /// from the same player's side as when it was linked. Without a stored
    /// side (a link from before) the name is compared, ignoring case and spaces.
    public mutating func refreshLink(from summary: MatchHistorySummary) {
        var ownFirst = linkedOwnIsPlayer1
        if ownFirst == nil {
            let own = ownPlayer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ownFirst = summary.player1Name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == own
        }
        link(summary, ownIsPlayer1: ownFirst == true)
    }

    /// The games of a coach match just played, seen from our player: the
    /// head start ("Later instappen") and the filled-in result have no score
    public mutating func link(coach match: Match, ownIsPlayer1: Bool) {
        var result: [TeamGame] = []
        for _ in 0..<match.player1GamesBefore { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: ownIsPlayer1)) }
        for _ in 0..<match.player2GamesBefore { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: !ownIsPlayer1)) }
        for game in match.completedGames {
            let own = ownIsPlayer1 ? game.player1Score : game.player2Score
            let their = ownIsPlayer1 ? game.player2Score : game.player1Score
            result.append(TeamGame(ownPoints: own, theirPoints: their, ownWon: own > their))
        }
        for _ in 0..<match.player1GamesAfter { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: ownIsPlayer1)) }
        for _ in 0..<match.player2GamesAfter { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: !ownIsPlayer1)) }
        ownPlayer = ownIsPlayer1 ? match.player1Name : match.player2Name
        opponentPlayer = ownIsPlayer1 ? match.player2Name : match.player1Name
        games = result
        linkedMatchId = match.id.uuidString
        linkedKind = "coach"
        linkedOwnIsPlayer1 = ownIsPlayer1
        trackingMatchId = nil
        trackingOwnIsPlayer1 = nil
        bestOf = match.bestOf
    }

    /// The games of a referee match just played, seen from our player (the
    /// last game is still on the board when the match ends: `allGameResults`)
    public mutating func link(referee match: RefereeMatch, ownIsPlayer1: Bool) {
        var result: [TeamGame] = []
        for _ in 0..<match.player1GamesBefore { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: ownIsPlayer1)) }
        for _ in 0..<match.player2GamesBefore { result.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: !ownIsPlayer1)) }
        for game in match.allGameResults {
            let own = ownIsPlayer1 ? game.player1Score : game.player2Score
            let their = ownIsPlayer1 ? game.player2Score : game.player1Score
            result.append(TeamGame(ownPoints: own, theirPoints: their, ownWon: (game.winner == Player.player1) == ownIsPlayer1))
        }
        ownPlayer = ownIsPlayer1 ? match.player1Name : match.player2Name
        opponentPlayer = ownIsPlayer1 ? match.player2Name : match.player1Name
        games = result
        linkedMatchId = match.id.uuidString
        linkedKind = "referee"
        linkedOwnIsPlayer1 = ownIsPlayer1
        trackingMatchId = nil
        trackingOwnIsPlayer1 = nil
        bestOf = match.bestOf
    }

    /// Keeps the games as they are, but as a partij filled in by hand
    public mutating func unlink() {
        linkedMatchId = nil
        linkedKind = nil
        linkedOwnIsPlayer1 = nil
        trackingMatchId = nil
        trackingOwnIsPlayer1 = nil
    }
}

/// The stand of a team match, seen from our team
public struct TeamMatchScore: Equatable, Sendable {
    public static let bonus = 3

    public let ownGames: Int
    public let theirGames: Int
    public let ownPartijen: Int
    public let theirPartijen: Int
    public let ownPoints: Int
    public let theirPoints: Int
    /// Partijen with at least one game
    public let partijenPlayed: Int
    /// All four partijen decided
    public let isComplete: Bool
    /// Every played game has its score, so rally points can break a tie
    public let pointsKnown: Bool
    /// Only when complete: true = we won, false = they did, nil = not decided (or a full tie)
    public let ownWon: Bool?
    public let ownCompetitionPoints: Int
    public let theirCompetitionPoints: Int

    init(partijen: [TeamPartij]) {
        var ownGames = 0
        var theirGames = 0
        var ownPartijen = 0
        var theirPartijen = 0
        var ownPoints = 0
        var theirPoints = 0
        var played = 0
        var decided = 0
        var pointsKnown = true
        for partij in partijen {
            ownGames += partij.ownGames
            theirGames += partij.theirGames
            ownPoints += partij.ownPoints
            theirPoints += partij.theirPoints
            if partij.hasEntry { played += 1 }
            if !partij.hasAllPoints { pointsKnown = false }
            if let won = partij.ownWon {
                decided += 1
                if won { ownPartijen += 1 } else { theirPartijen += 1 }
            }
        }
        let complete = partijen.count == 4 && decided == 4
        var ownWon: Bool? = nil
        if complete {
            if ownGames != theirGames {
                ownWon = ownGames > theirGames
            } else if ownPartijen != theirPartijen {
                ownWon = ownPartijen > theirPartijen
            } else if pointsKnown && ownPoints != theirPoints {
                ownWon = ownPoints > theirPoints
            }
        }
        self.ownGames = ownGames
        self.theirGames = theirGames
        self.ownPartijen = ownPartijen
        self.theirPartijen = theirPartijen
        self.ownPoints = ownPoints
        self.theirPoints = theirPoints
        self.partijenPlayed = played
        self.isComplete = complete
        self.pointsKnown = pointsKnown
        self.ownWon = ownWon
        self.ownCompetitionPoints = ownGames + (ownWon == true ? TeamMatchScore.bonus : 0)
        self.theirCompetitionPoints = theirGames + (ownWon == false ? TeamMatchScore.bonus : 0)
    }
}

/// A team match: the SBN fixture (or one typed in) with its four partijen
public struct TeamMatch: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var date: Date
    public var home: String
    public var away: String
    /// Which of the two is our team
    public var ownSide: TeamSide
    /// `LeagueFixture.id` when the match came from Mijn team
    public var fixtureId: String?
    public var partijen: [TeamPartij]
    public var updatedAt: Date
    /// The live team match on the server (Live delen, or joined with a code)
    public var liveId: String?
    /// The key in the invitation: writes a partij, nothing more
    public var liveKey: String?
    /// Only on the phone that started the live page: ends it, changes its team names
    public var liveOwnerKey: String?

    public init(id: UUID = UUID(), date: Date, home: String, away: String, ownSide: TeamSide,
                fixtureId: String? = nil, partijen: [TeamPartij] = [], updatedAt: Date = Date(),
                liveId: String? = nil, liveKey: String? = nil, liveOwnerKey: String? = nil) {
        self.liveId = liveId
        self.liveKey = liveKey
        self.liveOwnerKey = liveOwnerKey
        self.id = id
        self.date = date
        self.home = home
        self.away = away
        self.ownSide = ownSide
        self.fixtureId = fixtureId
        // Always the four slots E1–E4, in order; missing ones start empty
        var slots: [TeamPartij] = []
        for slot in 1...4 {
            var found: TeamPartij? = nil
            for partij in partijen where partij.slot == slot { found = partij }
            slots.append(found ?? TeamPartij(slot: slot))
        }
        self.partijen = slots
        self.updatedAt = updatedAt
    }

    /// The same match with exactly the four slots E1–E4 in order, also when a
    /// file has too few, too many or doubled ones (decoding does not go
    /// through `init`)
    public func normalized() -> TeamMatch {
        TeamMatch(id: id, date: date, home: home, away: away, ownSide: ownSide, fixtureId: fixtureId,
                  partijen: partijen, updatedAt: updatedAt, liveId: liveId, liveKey: liveKey,
                  liveOwnerKey: liveOwnerKey)
    }

    /// A match of Mijn team: our side follows from the team's name
    public static func from(fixture: LeagueFixture, ownTeam: String) -> TeamMatch {
        let side: TeamSide = TeamMatch.sameTeam(fixture.home, ownTeam) ? .home : .away
        return TeamMatch(date: fixture.date, home: fixture.home, away: fixture.away, ownSide: side, fixtureId: fixture.id)
    }

    public static func sameTeam(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == b.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var ownName: String { ownSide == .home ? home : away }
    public var opponentName: String { ownSide == .home ? away : home }
    /// "All Inn Squash 8 – Squash Delft 8"
    public var title: String { "\(home) – \(away)" }

    public var score: TeamMatchScore { TeamMatchScore(partijen: partijen) }
    public var isComplete: Bool { score.isComplete }

    public func partij(_ slot: Int) -> TeamPartij {
        for partij in partijen where partij.slot == slot { return partij }
        return TeamPartij(slot: slot)
    }

    /// Replaces the partij with the same slot
    public mutating func update(_ partij: TeamPartij) {
        var ours = cleaned(partij)
        ours.fromLive = nil
        var replaced = false
        for index in 0..<partijen.count where partijen[index].slot == ours.slot {
            partijen[index] = ours
            replaced = true
        }
        if !replaced { partijen.append(ours) }
        updatedAt = Date()
    }

    // Default names: nothing filled in = "Squash Delft 8 E1"

    /// The name of our player in this slot when none is filled in
    public func defaultOwnName(_ slot: Int) -> String { "\(ownName) E\(slot)" }
    public func defaultOpponentName(_ slot: Int) -> String { "\(opponentName) E\(slot)" }
    /// The name to show: the real one, or the default ("Squash Delft 8 E1")
    public func ownDisplayName(_ partij: TeamPartij) -> String {
        partij.ownPlayer.isEmpty ? defaultOwnName(partij.slot) : partij.ownPlayer
    }
    public func opponentDisplayName(_ partij: TeamPartij) -> String {
        partij.opponentPlayer.isEmpty ? defaultOpponentName(partij.slot) : partij.opponentPlayer
    }

    /// A partij whose "names" are just the defaults gets empty names again, so
    /// filling them in later works and the defaults follow a renamed team
    public func cleaned(_ partij: TeamPartij) -> TeamPartij {
        var result = partij
        if TeamMatch.sameTeam(result.ownPlayer, defaultOwnName(partij.slot)) { result.ownPlayer = "" }
        if TeamMatch.sameTeam(result.opponentPlayer, defaultOpponentName(partij.slot)) { result.opponentPlayer = "" }
        return result
    }

    public var isLive: Bool { liveId != nil && liveKey != nil }
    /// This phone started the live page (and may end it)
    public var isLiveOwner: Bool { isLive && liveOwnerKey != nil }

    /// The partij a coach or referee match in progress was started for, if any
    public func partijTracking(matchId: String) -> TeamPartij? {
        for partij in partijen where partij.trackingMatchId == matchId { return partij }
        return nil
    }

    /// Remembers that the tracked match `matchId` was started for this partij;
    /// a partij has one tracked match at a time
    /// The names the match was started with go into the partij too (the
    /// defaults stay empty), so a resumed match keeps them
    public mutating func startTracking(slot: Int, matchId: String, ownIsPlayer1: Bool,
                                       ownPlayer: String? = nil, opponentPlayer: String? = nil) {
        var partij = partij(slot)
        partij.trackingMatchId = matchId
        partij.trackingOwnIsPlayer1 = ownIsPlayer1
        if let ownPlayer, !partij.hasEntry { partij.ownPlayer = ownPlayer }
        if let opponentPlayer, !partij.hasEntry { partij.opponentPlayer = opponentPlayer }
        update(partij)
    }

    /// The tracked match was thrown away or stopped without a result: it is no
    /// longer "in progress" for its partij
    public mutating func stopTracking(matchId: String) {
        for index in 0..<partijen.count where partijen[index].trackingMatchId == matchId {
            partijen[index].trackingMatchId = nil
            partijen[index].trackingOwnIsPlayer1 = nil
            updatedAt = Date()
        }
    }

    /// The partij a tracked match is linked to, if any
    public func partijLinked(to matchId: String) -> TeamPartij? {
        for partij in partijen where partij.linkedMatchId == matchId { return partij }
        return nil
    }

    // Home – away orientation for display and the SBN comparison

    public var homeGames: Int { ownSide == .home ? score.ownGames : score.theirGames }
    public var awayGames: Int { ownSide == .home ? score.theirGames : score.ownGames }
    public var homePartijen: Int { ownSide == .home ? score.ownPartijen : score.theirPartijen }
    public var awayPartijen: Int { ownSide == .home ? score.theirPartijen : score.ownPartijen }
    public var homeCompetitionPoints: Int { ownSide == .home ? score.ownCompetitionPoints : score.theirCompetitionPoints }
    public var awayCompetitionPoints: Int { ownSide == .home ? score.theirCompetitionPoints : score.ownCompetitionPoints }

    /// The winning team's name, once decided
    public var winnerName: String? {
        guard let ownWon = score.ownWon else { return nil }
        return ownWon ? ownName : opponentName
    }

    /// "9-7" in games, home first
    public var gamesText: String { "\(homeGames)-\(awayGames)" }

    /// "Stand" while playing, "Uitslag" when the four partijen are decided
    public var statusText: String {
        let current = score
        if current.isComplete {
            if let winner = winnerName { return "\(winner) wint \(gamesText)" }
            return "Gelijkspel \(gamesText)"
        }
        if current.partijenPlayed == 0 { return "Nog niet begonnen" }
        return "Stand \(gamesText) · \(current.partijenPlayed) van 4 partijen"
    }
}
