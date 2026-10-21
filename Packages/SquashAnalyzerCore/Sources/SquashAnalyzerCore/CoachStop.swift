import Foundation

/// What "Stop" does with a coach match, the same on iOS and Android
public enum CoachStopAction: Equatable {
    /// The match is over: save it and go home, no questions
    case finish
    /// Nothing recorded yet (no rally, no let, from game 1): drop it silently
    case discard
    /// Ask: later verder, incompleet, uitslag aanvullen, niet opslaan or doorspelen
    case ask
}

extension Match {
    public var stopAction: CoachStopAction {
        if isMatchOver { return .finish }
        if allPoints.isEmpty && allLets.isEmpty && firstGameNumber == 1 { return .discard }
        return .ask
    }

    /// Title and explanation of the stop question
    public static var stopTitle: String { L10n.text("Wedstrijd stoppen?") }

    public var stopMessage: String {
        L10n.text("%@ – %@ staat %@-%@ in games en is nog niet afgelopen. Bewaar hem om later verder te gaan, sla hem op als incompleet, vul de winnaars van de gemiste games in, of gooi hem weg.",
            player1Name, player2Name, String(player1GamesWon), String(player2GamesWon))
    }

    /// The resume question when the Coach tile is tapped with an unfinished match
    public var resumeMessage: String {
        "\(player1Name) – \(player2Name), game \(currentGameNumber): \(currentGame.player1Score) – \(currentGame.player2Score). "
            + L10n.text("Bij een nieuwe wedstrijd komt deze als incompleet in Afgeronde wedstrijden.")
    }
}

extension RefereeMatch {
    /// The resume question when the Scheidsrechter tile is tapped with an unfinished match
    public var resumeMessage: String {
        "\(player1Name) – \(player2Name), game \(currentGameNumber): \(player1Score) – \(player2Score). "
            + L10n.text("Bij een nieuwe wedstrijd komt deze als incompleet in Afgeronde wedstrijden.")
    }
}
