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

// MARK: - Coach matches

/// Coachwedstrijden through `SwiftDataMatchRepository` (as before), for the
/// shared `CoachSessionView`
@MainActor
final class SwiftDataCoachMatchStore: CoachMatchStore {
    private let repository: SwiftDataMatchRepository

    init(context: ModelContext) {
        repository = SwiftDataMatchRepository(context: context)
    }

    func loadInProgress() async throws -> Match? {
        try repository.mostRecentInProgressMatch()
    }

    func save(_ match: Match) async throws {
        // A decided match is finished (Android's store does the same)
        if match.isMatchOver { match.status = .completed }
        try repository.upsert(match)
    }

    func abandon(_ match: Match) async throws {
        try repository.markAbandoned(match)
    }

    func discard(_ match: Match) async throws {
        try repository.delete(match)
    }
}

// MARK: - Afgeronde wedstrijden

/// Finished and abandoned coach and referee matches for the shared
/// `SharedMatchHistoryView`. A match still in progress is not listed: the
/// Coach and Scheidsrechter tiles offer it again (as on Android).
@MainActor
final class SwiftDataMatchHistoryStore: MatchHistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadHistory() async throws -> [MatchHistorySummary] {
        let withBadges = Set(try context.fetch(FetchDescriptor<SavedBadgeAward>())
            .filter { $0.deletedAt == nil }.map { $0.matchId })
        let inProgress = MatchStatus.inProgress.rawValue
        let coach = try context.fetch(FetchDescriptor<SavedMatch>(predicate: #Predicate { $0.status != inProgress }))
            .map { saved -> MatchHistorySummary in
                let games = saved.games.sorted { $0.gameNumber < $1.gameNumber }.compactMap { game -> HistoryGameScore? in
                    guard let winner = game.winner else { return nil }
                    return HistoryGameScore(player1Score: game.player1Score, player2Score: game.player2Score, winner: winner)
                }
                return MatchHistorySummary(
                    id: saved.id.uuidString, kind: "coach", player1Name: saved.player1Name, player2Name: saved.player2Name,
                    player1Games: saved.player1GamesWon, player2Games: saved.player2GamesWon,
                    status: saved.status, updatedAt: saved.updatedAt, games: games,
                    untrackedBefore: saved.player1GamesBefore + saved.player2GamesBefore,
                    untrackedAfter: saved.player1GamesAfter + saved.player2GamesAfter,
                    bestOf: saved.bestOf, hasBadges: withBadges.contains(saved.id))
            }
        var referee: [MatchHistorySummary] = []
        for saved in try context.fetch(FetchDescriptor<SavedRefereeMatch>()) {
            let id = refereeId(saved)
            let games = saved.gameResults.sorted { $0.number < $1.number }.map {
                HistoryGameScore(player1Score: $0.player1Score, player2Score: $0.player2Score, winner: $0.winnerRaw)
            }
            referee.append(MatchHistorySummary(
                id: id.uuidString, kind: "referee", player1Name: saved.player1Name, player2Name: saved.player2Name,
                player1Games: saved.player1GamesWon, player2Games: saved.player2GamesWon,
                status: saved.winnerName == nil ? MatchStatus.abandoned.rawValue : MatchStatus.completed.rawValue,
                updatedAt: saved.savedAt, games: games,
                untrackedBefore: saved.player1GamesBefore + saved.player2GamesBefore,
                bestOf: saved.bestOf, hasBadges: withBadges.contains(id)))
        }
        if context.hasChanges { try context.save() }
        return (coach + referee).sorted { $0.updatedAt > $1.updatedAt }
    }

    func coachMatch(id: String) async throws -> Match? {
        try savedMatch(id)?.toMatch()
    }

    /// Only the game scores are kept for a referee match (for sharing the result)
    func refereeMatch(id: String) async throws -> RefereeMatch? {
        guard let saved = try savedRefereeMatch(id) else { return nil }
        let match = RefereeMatch(id: refereeId(saved), player1Name: saved.player1Name, player2Name: saved.player2Name,
                                 bestOf: saved.bestOf, startingServer: .player1,
                                 player1GamesBefore: saved.player1GamesBefore, player2GamesBefore: saved.player2GamesBefore)
        match.completedGames = saved.gameResults.sorted { $0.number < $1.number }.compactMap { result in
            guard let winner = Player(rawValue: result.winnerRaw) else { return nil }
            return CompletedRefereeGame(number: result.number, player1Score: result.player1Score,
                                        player2Score: result.player2Score, winner: winner)
        }
        return match
    }

    func saveCoachMatch(_ match: Match) async throws {
        try SwiftDataMatchRepository(context: context).upsert(match)
    }

    func delete(_ entry: MatchHistorySummary) async throws {
        if entry.kind == "coach" {
            if let saved = try savedMatch(entry.id) {
                try BadgeAwarder(context: context).markAwardsDeleted(forMatch: saved.id)
                context.delete(saved)
            }
        } else if let saved = try savedRefereeMatch(entry.id) {
            try BadgeAwarder(context: context).markAwardsDeleted(forMatch: refereeId(saved))
            context.delete(saved)
        }
        try context.save()
    }

    /// Referee matches saved before badges have no id yet: given one now, so a row can be opened or deleted
    private func refereeId(_ saved: SavedRefereeMatch) -> UUID {
        if let id = saved.matchId { return id }
        let id = UUID()
        saved.matchId = id
        return id
    }

    private func savedMatch(_ id: String) throws -> SavedMatch? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try context.fetch(FetchDescriptor<SavedMatch>(predicate: #Predicate { $0.id == uuid })).first
    }

    private func savedRefereeMatch(_ id: String) throws -> SavedRefereeMatch? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try context.fetch(FetchDescriptor<SavedRefereeMatch>(predicate: #Predicate { $0.matchId == uuid })).first
    }
}

// MARK: - AI Coach

/// The Keychain key and URLSession sender for the shared analysis screen
enum IOSAICoach {
    static var context: AICoachContext {
        AICoachContext(keyStore: APIKeyManager.shared, client: AICoachClient(transport: URLSessionAICoachTransport()))
    }
}

// MARK: - Badges per player

/// A player's badges for the shared badge screen (`SharedPlayerBadgesView`)
@MainActor
final class SwiftDataBadgeSummaryStore: PlayerBadgeSummaryStore, @unchecked Sendable {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func player(_ id: String) throws -> SavedPlayer? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try context.fetch(FetchDescriptor<SavedPlayer>(predicate: #Predicate { $0.id == uuid })).first
    }

    private func activeAwards(_ playerId: String) throws -> [SavedBadgeAward] {
        guard let card = try player(playerId)?.badgeCardId else { return [] }
        return try context.fetch(FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.cardId == card && $0.deletedAt == nil }))
    }

    nonisolated func badges(forPlayer playerId: String) async throws -> [BadgeKind] {
        try await MainActor.run {
            var kinds: [BadgeKind] = []
            for award in try activeAwards(playerId) {
                if let kind = award.badgeKind, !kinds.contains(kind) { kinds.append(kind) }
            }
            return kinds
        }
    }

    nonisolated func badgeCounts(forPlayers playerIds: [String]) async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for id in playerIds {
            counts[id] = try await badges(forPlayer: id).count
        }
        return counts
    }

    nonisolated func cardSnapshot(forPlayer playerId: String) async throws -> CardSnapshot? {
        try await MainActor.run {
            guard let saved = try player(playerId) else { return nil }
            return try CardStore(context: context).snapshot(for: saved)
        }
    }

    nonisolated func moments(forPlayer playerId: String) async throws -> [BadgeMoment] {
        try await MainActor.run {
            try activeAwards(playerId).sorted { $0.earnedAt > $1.earnedAt }.compactMap { award in
                guard let kind = award.badgeKind else { return nil }
                return BadgeMoment(id: award.id.uuidString, badge: kind, earnedAt: award.earnedAt, opponentName: award.opponentName)
            }
        }
    }

    nonisolated func deleteMoment(_ id: String) async throws {
        try await MainActor.run {
            guard let uuid = UUID(uuidString: id),
                  let award = try context.fetch(FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.id == uuid })).first else { return }
            // Only marked: a recomputed match does not bring it back
            award.deletedAt = Date()
            try context.save()
        }
    }
}

extension IOSShare {
    /// "Deel kaart" with the picture of the card (Android draws it in CardImage.kt)
    static func card(_ snapshot: CardSnapshot, text: String) {
        var items: [Any] = []
        if let image = PlayerCardImage.render(snapshot: snapshot) { items.append(image) }
        items.append(text)
        present(items)
    }
}
