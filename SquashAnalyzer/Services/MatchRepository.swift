import Foundation
import SwiftData

protocol MatchRepository {
    @MainActor func upsert(_ match: Match) throws
    @MainActor func mostRecentInProgressMatch() throws -> Match?
    @MainActor func markAbandoned(_ match: Match) throws
}

enum PersistenceError: LocalizedError {
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "De wedstrijd kon niet worden opgeslagen: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class SwiftDataMatchRepository: MatchRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ match: Match) throws {
        do {
            let matchID = match.id
            let descriptor = FetchDescriptor<SavedMatch>(
                predicate: #Predicate { $0.id == matchID }
            )
            let saved = try context.fetch(descriptor).first ?? makeMatch(from: match)

            saved.player1Name = match.player1Name
            saved.player2Name = match.player2Name
            saved.matchStartingServer = match.matchStartingServer.rawValue
            saved.bestOf = match.bestOf
            saved.updatedAt = Date()
            saved.matchStatus = match.isMatchOver ? .completed : match.status
            saved.player1CoachingFocus = match.player1CoachingFocus
            saved.player2CoachingFocus = match.player2CoachingFocus
            saved.player1CoachingNotes = match.player1CoachingNotes
            saved.player2CoachingNotes = match.player2CoachingNotes

            // A match contains few records. Replacing its child snapshot keeps the
            // write path simple and prevents standalone/linked duplicate games.
            for oldGame in saved.games {
                context.delete(oldGame)
            }
            saved.games.removeAll()

            for (index, game) in match.games.enumerated() {
                let savedGame = SavedGame.from(game, gameNumber: index + 1, context: context)
                savedGame.match = saved
                saved.games.append(savedGame)
            }

            try context.save()
            match.updatedAt = saved.updatedAt
            match.status = saved.matchStatus
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed(error)
        }
    }

    func mostRecentInProgressMatch() throws -> Match? {
        let inProgress = MatchStatus.inProgress.rawValue
        var descriptor = FetchDescriptor<SavedMatch>(
            predicate: #Predicate { $0.status == inProgress },
            sortBy: [SortDescriptor(\SavedMatch.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.toMatch()
    }

    func markAbandoned(_ match: Match) throws {
        match.status = .abandoned
        try upsert(match)
    }

    private func makeMatch(from match: Match) -> SavedMatch {
        let saved = SavedMatch(
            id: match.id,
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            matchStartingServer: match.matchStartingServer,
            bestOf: match.bestOf,
            savedAt: Date(),
            updatedAt: Date(),
            status: match.status
        )
        context.insert(saved)
        return saved
    }
}
