import Foundation

// MARK: - What the result card shows

/// One finished game as a chip on the result card ("G2 11-8")
public struct ResultGame: Identifiable, Equatable {
    public let number: Int
    public let player1Score: Int
    public let player2Score: Int
    public let winner: Player
    public var id: Int { number }

    public init(number: Int, player1Score: Int, player2Score: Int, winner: Player) {
        self.number = number
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
    }
}

/// A grey line under the chips, optionally with a timer icon
public struct ResultCaptionLine: Identifiable, Equatable {
    public let text: String
    public let showsTimer: Bool
    public var id: String { text }

    public init(_ text: String, showsTimer: Bool = false) {
        self.text = text
        self.showsTimer = showsTimer
    }
}

/// The content of the "GAME 2 KLAAR" / "WEDSTRIJD KLAAR" card, built from a
/// referee or coach match. Shared by iOS and Android so both show the same.
public struct MatchResult: Equatable {
    public let title: String
    public let player1Name: String
    public let player2Name: String
    /// Points (end of a game) or games (end of the match)
    public let player1Score: Int
    public let player2Score: Int
    public let winner: Player?
    public let winnerText: String?
    public let games: [ResultGame]
    /// Games played before scoring started, shown as "G1 –"
    public let untracked: Int
    public let showsChips: Bool
    public let captions: [ResultCaptionLine]
    /// "Wedstrijd automatisch opgeslagen" (coach)
    public let savedNote: String?
    public let isMatchOver: Bool

    public init(title: String, player1Name: String, player2Name: String, player1Score: Int, player2Score: Int,
                winner: Player?, winnerText: String?, games: [ResultGame], untracked: Int, showsChips: Bool,
                captions: [ResultCaptionLine], savedNote: String?, isMatchOver: Bool) {
        self.title = title
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
        self.winnerText = winnerText
        self.games = games
        self.untracked = untracked
        self.showsChips = showsChips
        self.captions = captions
        self.savedNote = savedNote
        self.isMatchOver = isMatchOver
    }

    /// End of a referee game, before "Volgende game"
    public static func refereeGame(_ match: RefereeMatch) -> MatchResult {
        let winner = match.currentGameWinner
        return MatchResult(
            title: "GAME \(match.currentGameNumber) KLAAR",
            player1Name: match.player1Name, player2Name: match.player2Name,
            player1Score: match.player1Score, player2Score: match.player2Score,
            winner: winner,
            winnerText: winner.map { "\(match.name(for: $0)) wint game \(match.currentGameNumber)" },
            games: refereeGames(match), untracked: match.firstGameNumber - 1, showsChips: true,
            captions: [ResultCaptionLine(standText(match)), ResultCaptionLine(gameStatsText(match), showsTimer: true)],
            savedNote: nil, isMatchOver: false
        )
    }

    /// End of a referee match
    public static func refereeMatch(_ match: RefereeMatch) -> MatchResult {
        let winner = match.matchWinner
        return MatchResult(
            title: "WEDSTRIJD KLAAR",
            player1Name: match.player1Name, player2Name: match.player2Name,
            player1Score: match.player1TotalGames, player2Score: match.player2TotalGames,
            winner: winner,
            winnerText: winner.map { "🏆 \(match.name(for: $0)) wint de wedstrijd" },
            games: refereeGames(match), untracked: match.firstGameNumber - 1, showsChips: true,
            captions: [ResultCaptionLine(matchStatsText(match), showsTimer: true)],
            savedNote: nil, isMatchOver: true
        )
    }

    /// End of a coach game (or of the match when it is over)
    public static func coach(_ match: Match, game: Game) -> MatchResult {
        let over = match.isMatchOver
        let winner = over ? match.matchWinner : game.winner
        var games: [ResultGame] = []
        for index in 0..<match.games.count {
            let played = match.games[index]
            if let gameWinner = played.winner {
                games.append(ResultGame(number: match.gameNumber(at: index), player1Score: played.player1Score,
                                        player2Score: played.player2Score, winner: gameWinner))
            }
        }
        return MatchResult(
            title: over ? "WEDSTRIJD KLAAR" : "GAME \(match.currentGameNumber) KLAAR",
            player1Name: match.player1Name, player2Name: match.player2Name,
            player1Score: over ? match.player1GamesWon : game.player1Score,
            player2Score: over ? match.player2GamesWon : game.player2Score,
            winner: winner,
            winnerText: winner.map { "\(match.name(for: $0)) wint" + (over ? " de wedstrijd" : " game \(match.currentGameNumber)") },
            games: games, untracked: match.firstGameNumber - 1,
            showsChips: games.count > 1 || over || match.firstGameNumber > 1,
            captions: [],
            savedNote: over ? "Wedstrijd automatisch opgeslagen" : "Game automatisch opgeslagen",
            isMatchOver: over
        )
    }

    private static func refereeGames(_ match: RefereeMatch) -> [ResultGame] {
        var games: [ResultGame] = []
        for game in match.completedGames {
            games.append(ResultGame(number: game.number, player1Score: game.player1Score, player2Score: game.player2Score, winner: game.winner))
        }
        if let winner = match.currentGameWinner {
            games.append(ResultGame(number: match.currentGameNumber, player1Score: match.player1Score, player2Score: match.player2Score, winner: winner))
        }
        return games
    }

    /// "Gelijk 1 – 1" or "Jan leidt 2 – 1", games won including this one
    static func standText(_ match: RefereeMatch) -> String {
        let p1 = match.player1TotalGames
        let p2 = match.player2TotalGames
        if p1 == p2 { return "Gelijk \(p1) – \(p2)" }
        let leader = p1 > p2 ? Player.player1 : Player.player2
        return "\(match.name(for: leader)) leidt \(max(p1, p2)) – \(min(p1, p2))"
    }

    /// "8:42 · 19 rallies · 1 stroke"
    static func gameStatsText(_ match: RefereeMatch) -> String {
        let secs = Int(match.currentGameDuration)
        let seconds = secs % 60
        var parts = ["\(secs / 60):" + (seconds < 10 ? "0" : "") + "\(seconds)", "\(match.pointHistory.count) rallies"]
        var strokes = 0
        for entry in match.pointHistory where entry.isStroke { strokes += 1 }
        if strokes > 0 { parts.append("\(strokes) stroke" + (strokes == 1 ? "" : "s")) }
        return parts.joined(separator: " · ")
    }

    /// "42 min · 73 rallies · 2 strokes"
    static func matchStatsText(_ match: RefereeMatch) -> String {
        let minutes = max(1, Int((match.matchDuration / 60.0).rounded()))
        var parts = ["\(minutes) min", "\(match.totalRallies) rallies"]
        let strokes = match.totalStrokes
        if strokes > 0 { parts.append("\(strokes) stroke" + (strokes == 1 ? "" : "s")) }
        return parts.joined(separator: " · ")
    }
}
