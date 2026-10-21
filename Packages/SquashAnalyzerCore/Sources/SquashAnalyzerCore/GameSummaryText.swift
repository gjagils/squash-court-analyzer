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
            winnerName = L10n.text("Gelijkspel")
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

        var text = L10n.text("🏸 SQUASH GAME ANALYSE") + "\n"
            + "\(p1) vs \(p2)\n"
            + L10n.text("Eindstand: %@-%@ (%@ wint)", String(game.player1Score), String(game.player2Score), winnerName) + "\n"
            + "\n"
            + playerBlock(name: p1, points: p1Points, winners: p1Winners, forced: p1Forced, unforced: p1Unforced,
                          service: p1Service, strokes: p1Strokes)

        if let kinds = ErrorKind.summary(game.errorKindCounts(madeBy: Player.player1)) {
            text += "\n• " + L10n.text("Soort fouten: %@", kinds)
        }
        if let zone = game.bestZone(for: Player.player1) {
            text += "\n• " + L10n.text("Beste zone: %@", zone.title)
        }

        text += "\n" + playerBlock(name: p2, points: p2Points, winners: p2Winners, forced: p2Forced, unforced: p2Unforced,
                                     service: p2Service, strokes: p2Strokes)

        if let kinds = ErrorKind.summary(game.errorKindCounts(madeBy: Player.player2)) {
            text += "\n• " + L10n.text("Soort fouten: %@", kinds)
        }
        if let zone = game.bestZone(for: Player.player2) {
            text += "\n• " + L10n.text("Beste zone: %@", zone.title)
        }

        text += "\n\n" + L10n.text("📲 Gedeeld via Squash Analyzer")
        return text
    }

    /// "📊 NAME:" and the player's three lines
    static func playerBlock(name: String, points: Int, winners: Int, forced: Int, unforced: Int,
                            service: Int, strokes: Int) -> String {
        return "📊 \(name.uppercased()):\n"
            + "• " + L10n.text("Gewonnen: %@ punten", String(points)) + "\n"
            + "• " + L10n.text("Winners: %@ | Forced errors: %@ | Eigen fouten: %@", String(winners), String(forced), String(unforced)) + "\n"
            + "• " + L10n.text("Servicepunten: %@ | Strokes: %@", String(service), String(strokes))
    }
}
