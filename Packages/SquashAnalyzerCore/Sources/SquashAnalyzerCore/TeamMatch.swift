import Foundation

// MARK: - Competitie: een SBN-teamwedstrijd van vier partijen
//
// An SBN team match is four singles (E1–E4, best of five to 11). The result
// is the games won over the four partijen; competition points are those
// games plus 3 bonus points for the winner. Winner: most games; tie → most
// partijen won; still tied → most rally points (rules confirmed by Gerd-Jan,
// October 2026). Everything here is pure and shared with Android; the
// screens live in SquashAnalyzerUI, the file store below is used by both
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
        bestOf = summary.bestOf
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
        bestOf = match.bestOf
    }

    /// Keeps the games as they are, but as a partij filled in by hand
    public mutating func unlink() {
        linkedMatchId = nil
        linkedKind = nil
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

    public init(id: UUID = UUID(), date: Date, home: String, away: String, ownSide: TeamSide,
                fixtureId: String? = nil, partijen: [TeamPartij] = [], updatedAt: Date = Date()) {
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

    /// A match of Mijn team: our side follows from the team's name
    public static func from(fixture: LeagueFixture, ownTeam: String) -> TeamMatch {
        let side: TeamSide = TeamMatch.sameTeam(fixture.home, ownTeam) ? .home : .away
        return TeamMatch(date: fixture.date, home: fixture.home, away: fixture.away, ownSide: side, fixtureId: fixture.id)
    }

    static func sameTeam(_ a: String, _ b: String) -> Bool {
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
        var replaced = false
        for index in 0..<partijen.count where partijen[index].slot == partij.slot {
            partijen[index] = partij
            replaced = true
        }
        if !replaced { partijen.append(partij) }
        updatedAt = Date()
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

// MARK: - Verslag

/// The team match as a WhatsApp message, in the layouts of "Deel score":
/// Scorekaart (a monospace table), Verslag (per partij) and the short
/// three-liner. The picture is `ResultCard.from(_:)` below.
public enum TeamMatchReport {
    /// The full report ("Verslag")
    public static func text(_ match: TeamMatch) -> String {
        text(match, style: MatchShareStyle.report)
    }

    public static func text(_ match: TeamMatch, style: MatchShareStyle) -> String {
        switch style {
        case .compact: return compact(match)
        case .scorecard: return scorecard(match)
        case .report: return report(match)
        }
    }

    // Building blocks

    /// "9–8" in games, the winner's games first
    private static func winnerScore(_ match: TeamMatch) -> String {
        let own = match.score.ownGames
        let their = match.score.theirGames
        return own >= their ? "\(own)–\(their)" : "\(their)–\(own)"
    }

    /// The result, or the stand while the team match is not over
    static func resultLine(_ match: TeamMatch) -> String {
        let current = match.score
        if current.isComplete {
            if let winner = match.winnerName { return "🏆 *\(winner) wint met \(winnerScore(match))*" }
            return "🤝 *Gelijkspel \(match.homeGames)–\(match.awayGames)*"
        }
        if current.partijenPlayed == 0 { return "Nog niet begonnen" }
        if current.ownGames == current.theirGames { return "Stand: gelijk \(match.homeGames)–\(match.awayGames)" }
        let leader = current.ownGames > current.theirGames ? match.ownName : match.opponentName
        return "Stand: \(leader) leidt met \(winnerScore(match)) · \(current.partijenPlayed) van 4 partijen"
    }

    /// "Competitiepunten: All Inn 12 · Delft 8" once the match is decided
    static func pointsLine(_ match: TeamMatch) -> String? {
        guard match.score.isComplete else { return nil }
        return "Competitiepunten: \(match.home) \(match.homeCompetitionPoints) · \(match.away) \(match.awayCompetitionPoints)"
    }

    /// Home player first, as SBN prints it
    static func names(_ partij: TeamPartij, match: TeamMatch) -> String {
        let own = partij.ownPlayer.isEmpty ? "?" : partij.ownPlayer
        let their = partij.opponentPlayer.isEmpty ? "?" : partij.opponentPlayer
        return match.ownSide == TeamSide.home ? "\(own) – \(their)" : "\(their) – \(own)"
    }

    /// "3-1" of a partij, home first
    static func standText(_ partij: TeamPartij, match: TeamMatch) -> String {
        match.ownSide == TeamSide.home ? "\(partij.ownGames)-\(partij.theirGames)" : "\(partij.theirGames)-\(partij.ownGames)"
    }

    /// "11-8, 9-11", home first
    static func gamesText(_ partij: TeamPartij, match: TeamMatch) -> String {
        match.ownSide == TeamSide.home ? partij.gamesText : flipped(partij)
    }

    static func flipped(_ partij: TeamPartij) -> String {
        var parts: [String] = []
        for game in partij.games {
            if let own = game.ownPoints, let their = game.theirPoints {
                parts.append("\(their)-\(own)")
            } else {
                parts.append("–")
            }
        }
        return parts.joined(separator: ", ")
    }

    private static func sorted(_ match: TeamMatch) -> [TeamPartij] {
        match.partijen.sorted(by: { a, b in a.slot < b.slot })
    }

    // 1. Kort

    private static func compact(_ match: TeamMatch) -> String {
        var lines: [String] = []
        lines.append("🏆 *Teamwedstrijd · \(shortDay(match.date))*")
        let homeLeads = match.homeGames > match.awayGames
        let awayLeads = match.awayGames > match.homeGames
        let home = homeLeads ? "*\(match.home)*" : match.home
        let away = awayLeads ? "*\(match.away)*" : match.away
        lines.append("\(home) \(match.homeGames) – \(match.awayGames) \(away)")
        var detail = "\(match.homePartijen)-\(match.awayPartijen) in partijen"
        if let points = pointsLine(match) { detail += " · " + points.replacingOccurrences(of: "Competitiepunten: ", with: "punten ") }
        lines.append(detail)
        return lines.joined(separator: "\n")
    }

    // 2. Scorekaart

    /// Monospace table: per partij the home and the away player, one column per game
    private static func scorecard(_ match: TeamMatch) -> String {
        let nameWidth = 12
        // Every row has as many game columns as the longest partij, so the
        // column with the games won lines up
        var columns = 1
        for partij in match.partijen where partij.games.count > columns { columns = partij.games.count }
        func pad(_ s: String, _ w: Int, right: Bool = false) -> String {
            let t = String(s.prefix(w))
            let fill = String(repeating: " ", count: max(0, w - t.count))
            return right ? fill + t : t + fill
        }
        var lines: [String] = []
        lines.append("🏆 *TEAM SCOREKAART*")
        lines.append("\(shortDay(match.date)) · \(match.home) – \(match.away)")
        lines.append("")
        lines.append("```")
        for partij in sorted(match) {
            let own = partij.ownPlayer.isEmpty ? "?" : partij.ownPlayer
            let their = partij.opponentPlayer.isEmpty ? "?" : partij.opponentPlayer
            let homeName = match.ownSide == TeamSide.home ? own : their
            let awayName = match.ownSide == TeamSide.home ? their : own
            var row1 = pad(partij.label + " " + homeName, nameWidth)
            var row2 = pad("   " + awayName, nameWidth)
            for game in partij.games {
                let homePoints = match.ownSide == TeamSide.home ? game.ownPoints : game.theirPoints
                let awayPoints = match.ownSide == TeamSide.home ? game.theirPoints : game.ownPoints
                row1 += pad(homePoints.map { value in String(value) } ?? "–", 4, right: true)
                row2 += pad(awayPoints.map { value in String(value) } ?? "–", 4, right: true)
            }
            for _ in partij.games.count..<columns {
                row1 += "    "
                row2 += "    "
            }
            if partij.hasEntry {
                row1 += "  " + String(standText(partij, match: match).prefix(1))
                row2 += "  " + String(standText(partij, match: match).suffix(1))
            }
            lines.append(row1)
            lines.append(row2)
        }
        lines.append("```")
        lines.append(resultLine(match))
        if let points = pointsLine(match) { lines.append(points) }
        return lines.joined(separator: "\n")
    }

    // 3. Verslag

    private static func report(_ match: TeamMatch) -> String {
        var lines: [String] = []
        lines.append("🏆 *TEAMWEDSTRIJD*")
        lines.append("📅 \(longDay(match.date))")
        lines.append("👥 \(match.home) – \(match.away)")
        lines.append("")
        for partij in sorted(match) {
            let who = names(partij, match: match)
            if !partij.hasEntry {
                lines.append("*\(partij.label)* \(who): nog niet gespeeld")
            } else {
                var line = "*\(partij.label)* \(who) · \(standText(partij, match: match)) (\(gamesText(partij, match: match)))"
                if let won = partij.ownWon {
                    let winner = won ? partij.ownPlayer : partij.opponentPlayer
                    if !winner.isEmpty { line += " ✅ \(winner)" }
                }
                lines.append(line)
            }
        }
        lines.append("")
        lines.append(resultLine(match))
        let current = match.score
        var stats = ["🎯 \(match.homePartijen)-\(match.awayPartijen) in partijen"]
        if current.pointsKnown && current.partijenPlayed > 0 {
            stats.append("🎾 rallypunten \(match.ownSide == TeamSide.home ? current.ownPoints : current.theirPoints)-\(match.ownSide == TeamSide.home ? current.theirPoints : current.ownPoints)")
        }
        lines.append(stats.joined(separator: " · "))
        if let points = pointsLine(match) { lines.append(points) }
        lines.append("")
        lines.append("_Gescoord met Squash Analyzer_")
        return lines.joined(separator: "\n")
    }

    // Dates (DateFormatter: Date.FormatStyle does not exist in Skip)

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// "vr 30 okt"
    public static func dayText(_ date: Date) -> String { format(date, "EEE d MMM") }
    static func shortDay(_ date: Date) -> String { dayText(date) }
    /// "vrijdag 30 oktober 2026"
    static func longDay(_ date: Date) -> String { format(date, "EEEE d MMMM yyyy") }
}

extension ResultCard {
    /// The picture of a team match: both team names, the games as the big
    /// score (home is the orange side), who won, and a chip per partij.
    public static func from(_ match: TeamMatch) -> ResultCard {
        var chips: [Chip] = []
        for partij in match.partijen.sorted(by: { a, b in a.slot < b.slot }) where partij.hasEntry {
            var winner: Player? = nil
            if let ownWon = partij.ownWon {
                let homeWon = ownWon == (match.ownSide == TeamSide.home)
                winner = homeWon ? Player.player1 : Player.player2
            }
            chips.append(Chip(label: partij.label, score: TeamMatchReport.standText(partij, match: match), winner: winner))
        }
        let current = match.score
        var winner: Player? = nil
        var text: String? = nil
        var title = "TUSSENSTAND"
        if current.isComplete {
            title = "TEAMWEDSTRIJD KLAAR"
            if let ownWon = current.ownWon {
                let homeWon = ownWon == (match.ownSide == TeamSide.home)
                winner = homeWon ? Player.player1 : Player.player2
                text = "\(match.winnerName ?? "") wint de teamwedstrijd"
            } else {
                text = "Gelijkspel"
            }
        } else if current.partijenPlayed == 0 {
            title = "TEAMWEDSTRIJD"
        } else if match.homeGames != match.awayGames {
            winner = match.homeGames > match.awayGames ? Player.player1 : Player.player2
            text = "\(match.homeGames > match.awayGames ? match.home : match.away) leidt \(max(match.homeGames, match.awayGames))-\(min(match.homeGames, match.awayGames))"
        }
        return ResultCard(title: title, player1Name: match.home, player2Name: match.away,
                          player1Score: match.homeGames, player2Score: match.awayGames,
                          winner: winner, winnerText: text, chips: chips)
    }
}

// MARK: - Opslag

/// Team matches on this phone, newest first
@MainActor
public protocol TeamMatchStore {
    func loadAll() async throws -> [TeamMatch]
    func save(_ match: TeamMatch) async throws
    func delete(id: UUID) async throws
}

/// The JSON file with all team matches, readable and writable without the
/// main actor (the backup code on iOS and Android needs it synchronously)
public enum TeamMatchFile {
    public static let fileName = "team-matches.json"

    public static func read(in directory: URL) -> [TeamMatch] {
        let url = directory.appendingPathComponent(TeamMatchFile.fileName)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TeamMatch].self, from: data)) ?? []
    }

    public static func write(_ matches: [TeamMatch], in directory: URL) throws {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(TeamMatchFile.fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(matches)
        try data.write(to: url)
    }
}

/// One JSON file with all team matches, used on iOS (Application Support)
/// and Android (the app's files directory). Small and whole: every save
/// rewrites the file.
@MainActor
public final class JSONFileTeamMatchStore: TeamMatchStore {
    public static let fileName = TeamMatchFile.fileName
    private let directory: URL

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
    }

    public func loadAll() async throws -> [TeamMatch] {
        return TeamMatchFile.read(in: directory).sorted(by: { a, b in a.date > b.date })
    }

    public func save(_ match: TeamMatch) async throws {
        var all = TeamMatchFile.read(in: directory)
        var replaced = false
        for index in 0..<all.count where all[index].id == match.id {
            all[index] = match
            replaced = true
        }
        if !replaced { all.append(match) }
        try TeamMatchFile.write(all, in: directory)
    }

    public func delete(id: UUID) async throws {
        let kept = TeamMatchFile.read(in: directory).filter { match in match.id != id }
        try TeamMatchFile.write(kept, in: directory)
    }
}
