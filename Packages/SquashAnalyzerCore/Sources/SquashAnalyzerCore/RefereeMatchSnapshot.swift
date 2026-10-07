import Foundation

/// A referee match that is still being played, as JSON: iOS keeps it in a
/// file so "Sluiten" halfway can be resumed (Android keeps the same values in
/// Room). Undo is rebuilt from the timeline after restoring (`rebuildUndo`).
public struct RefereeMatchSnapshot: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let id: UUID
        public let scorer: String
        public let score: Int
        public let side: String
        public let isStroke: Bool
    }

    /// Fixed JSON of the in-progress file. A separate shape on purpose, not merged with the other game types: see docs/bewuste-keuzes.md.
    public struct FinishedGame: Codable, Equatable, Sendable {
        public let id: UUID
        public let number: Int
        public let player1Score: Int
        public let player2Score: Int
        public let winner: String
        public let duration: TimeInterval?
        public let points: [Entry]
    }

    public let id: UUID
    public let player1Name: String
    public let player2Name: String
    public let player1Id: UUID?
    public let player2Id: UUID?
    public let bestOf: Int
    public let player1GamesBefore: Int
    public let player2GamesBefore: Int
    public let player1Score: Int
    public let player2Score: Int
    public let currentServer: String
    public let serverSide: String
    public let currentGameNumber: Int
    public let player1PreferredSide: String?
    public let player2PreferredSide: String?
    /// Server and box of the current game's first rally (nil in older files)
    public let openingServer: String?
    public let openingSide: String?
    public let matchStartedAt: Date
    public let gameStartedAt: Date
    public let completedGames: [FinishedGame]
    public let points: [Entry]

    static func entry(_ point: RefereePointEntry) -> Entry {
        Entry(id: point.id, scorer: point.scorer.rawValue, score: point.score, side: point.side.rawValue, isStroke: point.isStroke)
    }

    static func point(_ entry: Entry) -> RefereePointEntry? {
        guard let scorer = Player(rawValue: entry.scorer), let side = ServerSide(rawValue: entry.side) else { return nil }
        return RefereePointEntry(id: entry.id, scorer: scorer, score: entry.score, side: side, isStroke: entry.isStroke)
    }
}

extension RefereeMatch {
    public var snapshot: RefereeMatchSnapshot {
        var games: [RefereeMatchSnapshot.FinishedGame] = []
        for game in completedGames {
            var points: [RefereeMatchSnapshot.Entry] = []
            for point in game.points {
                points.append(RefereeMatchSnapshot.entry(point))
            }
            games.append(RefereeMatchSnapshot.FinishedGame(id: game.id, number: game.number, player1Score: game.player1Score,
                                                           player2Score: game.player2Score, winner: game.winner.rawValue,
                                                           duration: game.duration, points: points))
        }
        var points: [RefereeMatchSnapshot.Entry] = []
        for point in pointHistory {
            points.append(RefereeMatchSnapshot.entry(point))
        }
        return RefereeMatchSnapshot(
            id: id, player1Name: player1Name, player2Name: player2Name, player1Id: player1Id, player2Id: player2Id,
            bestOf: bestOf, player1GamesBefore: player1GamesBefore, player2GamesBefore: player2GamesBefore,
            player1Score: player1Score, player2Score: player2Score, currentServer: currentServer.rawValue,
            serverSide: serverSide.rawValue, currentGameNumber: currentGameNumber,
            player1PreferredSide: player1PreferredSide?.rawValue, player2PreferredSide: player2PreferredSide?.rawValue,
            openingServer: openingServer?.rawValue, openingSide: openingSide?.rawValue,
            matchStartedAt: matchStartedAt, gameStartedAt: gameStartedAt, completedGames: games, points: points)
    }

    /// The match as it was; nil when the snapshot is damaged
    public static func restoring(_ snapshot: RefereeMatchSnapshot) -> RefereeMatch? {
        guard let server = Player(rawValue: snapshot.currentServer),
              let side = ServerSide(rawValue: snapshot.serverSide) else { return nil }
        let match = RefereeMatch(id: snapshot.id, player1Name: snapshot.player1Name, player2Name: snapshot.player2Name,
                                 bestOf: snapshot.bestOf, startingServer: server,
                                 player1GamesBefore: snapshot.player1GamesBefore, player2GamesBefore: snapshot.player2GamesBefore,
                                 matchStartedAt: snapshot.matchStartedAt)
        match.player1Id = snapshot.player1Id
        match.player2Id = snapshot.player2Id
        match.player1Score = snapshot.player1Score
        match.player2Score = snapshot.player2Score
        match.currentServer = server
        match.serverSide = side
        match.currentGameNumber = snapshot.currentGameNumber
        match.player1PreferredSide = snapshot.player1PreferredSide.flatMap { ServerSide(rawValue: $0) }
        match.player2PreferredSide = snapshot.player2PreferredSide.flatMap { ServerSide(rawValue: $0) }
        match.gameStartedAt = snapshot.gameStartedAt
        var games: [CompletedRefereeGame] = []
        for game in snapshot.completedGames {
            guard let winner = Player(rawValue: game.winner) else { return nil }
            var points: [RefereePointEntry] = []
            for entry in game.points {
                if let point = RefereeMatchSnapshot.point(entry) { points.append(point) }
            }
            games.append(CompletedRefereeGame(id: game.id, number: game.number, player1Score: game.player1Score,
                                              player2Score: game.player2Score, winner: winner, duration: game.duration, points: points))
        }
        match.completedGames = games
        var history: [RefereePointEntry] = []
        for entry in snapshot.points {
            if let point = RefereeMatchSnapshot.point(entry) { history.append(point) }
        }
        match.pointHistory = history
        match.openingServer = snapshot.openingServer.flatMap { Player(rawValue: $0) }
        match.openingSide = snapshot.openingSide.flatMap { ServerSide(rawValue: $0) }
        match.rebuildUndo()
        // Time spent with the app closed is not part of the next rally
        match.lastPointAt = history.isEmpty ? nil : Date()
        return match
    }
}
