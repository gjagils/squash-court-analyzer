import Foundation

/// What the share picture of a game or match shows ("Deel als plaatje"),
/// laid out like the result card at the end of a game: title, both names,
/// a big score, who won and a chip per game. Built from `MatchShareReport`, so
/// coach and referee, iOS (SwiftUI) and Android (Canvas) draw the same thing.
public struct ResultCard: Equatable {
    public struct Chip: Equatable {
        /// "G1"
        public let label: String
        /// "15-17"
        public let score: String
        /// nil while the game is still being played
        public let winner: Player?
    }

    /// One line under the score of a team match: who played whom and how it went
    public struct Row: Equatable {
        /// "E1"
        public let label: String
        /// The home player (the orange side), then the away player
        public let home: String
        public let away: String
        /// Games of this partij, home first: "2-3"
        public let score: String
        /// The games, home first: "14-12 · 5-11 · 3-11"; "–" for a game without a score
        public let games: String
        /// Who won the partij (player1 = home); nil while it is open
        public let winner: Player?

        public init(label: String, home: String, away: String, score: String, games: String, winner: Player?) {
            self.label = label
            self.home = home
            self.away = away
            self.score = score
            self.games = games
            self.winner = winner
        }
    }

    /// "WEDSTRIJD KLAAR", "GAME 2 KLAAR" or "TUSSENSTAND"
    public let title: String
    public let player1Name: String
    public let player2Name: String
    /// Games (match over, or in between) or points (the game just won)
    public let player1Score: Int
    public let player2Score: Int
    /// Highlighted side; nil when nobody has won yet
    public let winner: Player?
    /// "Niels wint de wedstrijd"
    public let winnerText: String?
    public let chips: [Chip]
    public let footer: String
    /// The players' photos (Spelers), drawn in the circles instead of the
    /// person icon; nil when the player has none
    public var player1Photo: Data? = nil
    public var player2Photo: Data? = nil
    /// A line per partij at the bottom of a team match picture (empty for a single match)
    public var rows: [Row] = []

    public init(title: String, player1Name: String, player2Name: String, player1Score: Int, player2Score: Int,
                winner: Player?, winnerText: String?, chips: [Chip], footer: String = "Squash Analyzer") {
        self.title = title
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
        self.winnerText = winnerText
        self.chips = chips
        self.footer = footer
    }

    public func name(for player: Player) -> String {
        player == Player.player1 ? player1Name : player2Name
    }

    public func photo(for player: Player) -> Data? {
        player == Player.player1 ? player1Photo : player2Photo
    }

    /// The same card with the players' photos
    public func withPhotos(_ photo1: Data?, _ photo2: Data?) -> ResultCard {
        var card = self
        card.player1Photo = photo1
        card.player2Photo = photo2
        return card
    }

    /// The card for the state of a match: the end of the match, the game that
    /// was just won, or the stand while a game is under way
    public static func from(_ report: MatchShareReport) -> ResultCard {
        var chips: [Chip] = []
        for game in report.games {
            chips.append(Chip(label: "G\(game.number)", score: "\(game.player1Score)-\(game.player2Score)", winner: game.winner))
        }
        if let winner = report.matchWinner {
            return ResultCard(title: "WEDSTRIJD KLAAR", player1Name: report.player1Name, player2Name: report.player2Name,
                              player1Score: report.player1Games, player2Score: report.player2Games,
                              winner: winner, winnerText: "\(report.name(for: winner)) wint de wedstrijd", chips: chips)
        }
        if let last = report.games.last, let winner = last.winner {
            return ResultCard(title: "GAME \(last.number) KLAAR", player1Name: report.player1Name, player2Name: report.player2Name,
                              player1Score: last.player1Score, player2Score: last.player2Score,
                              winner: winner, winnerText: "\(report.name(for: winner)) wint game \(last.number)", chips: chips)
        }
        var leader: Player? = nil
        if report.player1Games > report.player2Games { leader = Player.player1 }
        if report.player2Games > report.player1Games { leader = Player.player2 }
        var text: String? = nil
        if let leader {
            text = "\(report.name(for: leader)) leidt \(max(report.player1Games, report.player2Games))-\(min(report.player1Games, report.player2Games))"
        }
        return ResultCard(title: "TUSSENSTAND", player1Name: report.player1Name, player2Name: report.player2Name,
                          player1Score: report.player1Games, player2Score: report.player2Games,
                          winner: leader, winnerText: text, chips: chips)
    }
}
