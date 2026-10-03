import Foundation
import SwiftData
import UIKit
import SquashAnalyzerCore
import SquashAnalyzerUI

// The iPhone side of the shared screens (T20): SwiftData behind the store
// protocols that Android implements over Room. The shared views in
// SquashAnalyzerUI only know these protocols.

// MARK: - Share sheet

/// The system share sheet from anywhere (the shared screens give a text or a
/// picture, not a view to attach a sheet to): shown over the top-most screen.
@MainActor
enum IOSShare {
    static func present(_ items: [Any]) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        top.present(sheet, animated: true)
    }

    static func text(_ text: String) {
        present([text])
    }

    /// "Deel als plaatje" in the shared share screen (Android draws it in ResultImage.kt)
    static func installResultImageSharing() {
        ResultImageSharing.share = { card in
            guard let image = ResultCardImage.render(card) else { return }
            IOSShare.present([image])
        }
    }
}

// MARK: - Players

/// Spelers in SwiftData (`SavedPlayer`), for "Kies speler" in the shared match start
@MainActor
final class SwiftDataPlayerStore: PlayerProfileStore, PlayerPhotoStore, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func all() throws -> [SavedPlayer] {
        try context.fetch(FetchDescriptor<SavedPlayer>(sortBy: [SortDescriptor(\.name)]))
    }

    private func player(_ id: String) throws -> SavedPlayer? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try context.fetch(FetchDescriptor<SavedPlayer>(predicate: #Predicate { $0.id == uuid })).first
    }

    nonisolated func loadPlayers() async throws -> [PlayerProfile] {
        try await MainActor.run {
            try all().map { saved in
                PlayerProfile(id: saved.id.uuidString, name: saved.name, coachingFocusAreas: saved.coachingFocusAreas,
                              coachingNotes: saved.coachingNotes, createdAt: saved.createdAt.timeIntervalSince1970)
            }
        }
    }

    nonisolated func savePlayer(_ player: PlayerProfile) async throws {
        try await MainActor.run {
            guard player.isValid, let uuid = UUID(uuidString: player.id) else { return }
            if let saved = try self.player(player.id) {
                saved.name = player.trimmedName
                saved.coachingFocusAreas = player.coachingFocusAreas
                saved.coachingNotes = player.coachingNotes
            } else {
                context.insert(SavedPlayer(id: uuid, name: player.trimmedName, coachingFocusAreas: player.coachingFocusAreas,
                                           coachingNotes: player.coachingNotes,
                                           createdAt: Date(timeIntervalSince1970: player.createdAt)))
            }
            try context.save()
        }
    }

    nonisolated func deletePlayer(_ id: String) async throws {
        try await MainActor.run {
            guard let saved = try self.player(id) else { return }
            context.delete(saved)
            try context.save()
        }
    }

    nonisolated func photos() async throws -> [String: Data] {
        try await MainActor.run {
            var result: [String: Data] = [:]
            for saved in try all() {
                if let photo = saved.photoData { result[saved.id.uuidString] = photo }
            }
            return result
        }
    }

    nonisolated func setPhoto(_ image: Data?, for playerId: String) async throws {
        try await MainActor.run {
            guard let saved = try self.player(playerId) else { return }
            saved.photoData = image.flatMap { PlayerPhoto.normalized($0) }
            try context.save()
        }
    }
}

// MARK: - Referee matches

/// Scheidsrechterwedstrijden: the match being played as a file (as before),
/// a finished or abandoned one as `SavedRefereeMatch` with its badges. The
/// same steps Android takes with Room; no schema change.
@MainActor
final class SwiftDataRefereeMatchStore: RefereeMatchStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadInProgress() async throws -> RefereeMatch? {
        RefereeInProgressStore.load()
    }

    func save(_ match: RefereeMatch) async throws {
        let existing = try savedMatch(for: match.id)
        if match.isMatchOver {
            // Finished: in Afgeronde wedstrijden, with its badges
            let saved = existing ?? insertSaved(for: match)
            saved.gameResults = RefereeInProgressStore.results(of: match)
            try BadgeAwarder(context: context).syncAwards(
                matchId: match.id, playerIds: match.playerIds,
                playerNames: [.player1: match.player1Name, .player2: match.player2Name], input: match.badgeInput)
            try context.save()
            RefereeInProgressStore.clear()
        } else {
            // Undo after the last rally: no longer finished, so out of the list again
            if let existing {
                context.delete(existing)
                try BadgeAwarder(context: context).removeAwards(forMatch: match.id)
                try context.save()
            }
            RefereeInProgressStore.save(match)
        }
    }

    func abandon(_ match: RefereeMatch) async throws {
        if let existing = try savedMatch(for: match.id) {
            // Already in the list (finished): nothing to add
            _ = existing
            RefereeInProgressStore.clear()
            return
        }
        RefereeInProgressStore.keepAsAbandoned(match, in: context)
    }

    private func savedMatch(for id: UUID) throws -> SavedRefereeMatch? {
        try context.fetch(FetchDescriptor<SavedRefereeMatch>(predicate: #Predicate { $0.matchId == id })).first
    }

    private func insertSaved(for match: RefereeMatch) -> SavedRefereeMatch {
        let saved = SavedRefereeMatch(player1Name: match.player1Name, player2Name: match.player2Name, bestOf: match.bestOf,
                                      gameResults: [], player1GamesBefore: match.player1GamesBefore,
                                      player2GamesBefore: match.player2GamesBefore)
        saved.matchId = match.id
        saved.player1Id = match.player1Id
        saved.player2Id = match.player2Id
        context.insert(saved)
        return saved
    }
}

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
        let saved = SavedRefereeMatch(
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            bestOf: match.bestOf,
            gameResults: results(of: match),
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

    static func results(of match: RefereeMatch) -> [RefereeGameResult] {
        match.allGameResults.map {
            RefereeGameResult(number: $0.number, player1Score: $0.player1Score, player2Score: $0.player2Score, winner: $0.winner)
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
