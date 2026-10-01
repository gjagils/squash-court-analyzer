import Foundation

/// The plain-text summary of one game that the coach dashboard shares (iOS
/// and Android). Moved out of iOS' ExportService; the text is unchanged.
public enum GameSummaryText {
    public static func text(for game: Game) -> String {
        let p1 = game.player1Name
        let p2 = game.player2Name
        let winnerName: String
        if game.winner == Player.player1 {
            winnerName = p1
        } else if game.winner == Player.player2 {
            winnerName = p2
        } else {
            winnerName = "Gelijkspel"
        }

        let p1Points = game.pointsWon(by: Player.player1).count
        let p2Points = game.pointsWon(by: Player.player2).count
        let p1Winners = game.winners(by: Player.player1).count
        let p2Winners = game.winners(by: Player.player2).count
        let p1Forced = game.forcedErrors(by: Player.player1).count
        let p2Forced = game.forcedErrors(by: Player.player2).count
        let p1Unforced = game.unforcedErrors(by: Player.player1).count
        let p2Unforced = game.unforcedErrors(by: Player.player2).count
        let p1Strokes = game.strokes(by: Player.player1).count
        let p2Strokes = game.strokes(by: Player.player2).count
        let p1Service = game.servicePoints(by: Player.player1).count
        let p2Service = game.servicePoints(by: Player.player2).count

        var text = """
        🏸 SQUASH GAME ANALYSE
        \(p1) vs \(p2)
        Eindstand: \(game.player1Score)-\(game.player2Score) (\(winnerName) wint)

        📊 \(p1.uppercased()):
        • Gewonnen: \(p1Points) punten
        • Winners: \(p1Winners) | Forced errors: \(p1Forced) | Eigen fouten: \(p1Unforced)
        • Servicepunten: \(p1Service) | Strokes: \(p1Strokes)
        """

        if let zone = game.bestZone(for: Player.player1) {
            text += "\n• Beste zone: \(zone.rawValue)"
        }

        text += """

        📊 \(p2.uppercased()):
        • Gewonnen: \(p2Points) punten
        • Winners: \(p2Winners) | Forced errors: \(p2Forced) | Eigen fouten: \(p2Unforced)
        • Servicepunten: \(p2Service) | Strokes: \(p2Strokes)
        """

        if let zone = game.bestZone(for: Player.player2) {
            text += "\n• Beste zone: \(zone.rawValue)"
        }

        text += "\n\n📲 Gedeeld via Squash Analyzer"
        return text
    }
}
