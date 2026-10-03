import Foundation
import SwiftData
import SquashAnalyzerCore

/// The referee match being played, kept as a file (Core's
/// RefereeMatchSnapshot) after every change, so "Sluiten" halfway or closing
/// the app can be resumed, as on Android. Finished matches go to SwiftData as
/// before (`SavedRefereeMatch`); then this file is removed.
enum RefereeInProgressStore {
    /// Application Support; tests point it at a folder of their own
    static var folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

    private static var url: URL {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("referee-in-progress.json")
    }

    static func save(_ match: RefereeMatch) {
        guard let data = try? JSONEncoder().encode(match.snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// The unfinished match, if any. A file that cannot be read back (damaged,
    /// or from a format this version no longer knows) is removed, so the
    /// question "Wedstrijd hervatten?" does not keep failing on it.
    static func load() -> RefereeMatch? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(RefereeMatchSnapshot.self, from: data) else {
            clear()
            return nil
        }
        return RefereeMatch.restoring(snapshot)
    }

    /// "Nieuwe wedstrijd" while one is unfinished: it goes into Afgeronde
    /// wedstrijden as incomplete (only its finished games), with its badges,
    /// as Android keeps it as abandoned. Then the file is removed.
    @MainActor static func keepAsAbandoned(_ match: RefereeMatch, in context: ModelContext) {
        // Not a single rally played: nothing worth keeping
        guard !match.pointHistory.isEmpty || !match.completedGames.isEmpty else {
            clear()
            return
        }
        let results = match.allGameResults.map {
            RefereeGameResult(number: $0.number, player1Score: $0.player1Score, player2Score: $0.player2Score, winner: $0.winner)
        }
        let saved = SavedRefereeMatch(
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            bestOf: match.bestOf,
            gameResults: results,
            player1GamesBefore: match.player1GamesBefore,
            player2GamesBefore: match.player2GamesBefore
        )
        saved.matchId = match.id
        saved.player1Id = match.player1Id
        saved.player2Id = match.player2Id
        context.insert(saved)
        try? BadgeAwarder(context: context).syncAwards(
            matchId: match.id,
            playerIds: match.playerIds,
            playerNames: [.player1: match.player1Name, .player2: match.player2Name],
            input: match.badgeInput
        )
        try? context.save()
        clear()
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
