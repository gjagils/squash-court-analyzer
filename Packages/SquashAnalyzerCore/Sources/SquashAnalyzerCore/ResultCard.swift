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
