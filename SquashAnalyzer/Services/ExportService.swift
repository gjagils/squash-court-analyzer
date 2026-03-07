import Foundation
import SwiftData
import SwiftUI

// MARK: - Export Data Structures

struct SquashExport: Codable {
    let version: Int
    let exportedAt: Date
    let type: ExportType
    let match: MatchExportData?
    let game: GameExportData?

    enum ExportType: String, Codable {
        case match, game
    }
}

struct MatchExportData: Codable {
    let player1Name: String
    let player2Name: String
    let savedAt: Date
    let games: [GameExportData]
}

struct GameExportData: Codable {
    let gameNumber: Int
    let player1Name: String
    let player2Name: String
    let player1Score: Int
    let player2Score: Int
    let startingServer: String
    let winner: String?
    let savedAt: Date
    let points: [PointExportData]
    let lets: [LetExportData]
}

struct PointExportData: Codable {
    let pointNumber: Int
    let scorer: String
    let pointType: String
    let zone: String
    let shotType: String
    let server: String
    let player1Score: Int
    let player2Score: Int
    let duration: Double
}

struct LetExportData: Codable {
    let letNumber: Int
    let requestedBy: String
    let server: String
    let player1Score: Int
    let player2Score: Int
}

// MARK: - Export Service

enum ExportService {

    // MARK: - JSON Export

    static func exportJSON(from match: SavedMatch) throws -> Data {
        let matchData = matchExportData(from: match)
        let export = SquashExport(version: 1, exportedAt: Date(), type: .match, match: matchData, game: nil)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(export)
    }

    static func exportJSON(from game: SavedGame) throws -> Data {
        let gameData = gameExportData(from: game)
        let export = SquashExport(version: 1, exportedAt: Date(), type: .game, match: nil, game: gameData)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(export)
    }

    // MARK: - Text Export (WhatsApp / iMessage)

    static func textSummary(from game: SavedGame) -> String {
        let p1 = game.player1Name
        let p2 = game.player2Name
        let winnerName = game.gameWinner == .player1 ? p1 : (game.gameWinner == .player2 ? p2 : "Gelijkspel")

        let p1Points = game.pointsWon(by: .player1)
        let p2Points = game.pointsWon(by: .player2)
        let p1Winners = game.points.filter { $0.scorerPlayer == .player1 && $0.savedPointType == .winner }.count
        let p2Winners = game.points.filter { $0.scorerPlayer == .player2 && $0.savedPointType == .winner }.count
        let p1Forced = game.points.filter { $0.scorerPlayer == .player1 && $0.savedPointType == .forcedError }.count
        let p2Forced = game.points.filter { $0.scorerPlayer == .player2 && $0.savedPointType == .forcedError }.count
        let p1Unforced = game.points.filter { $0.scorerPlayer == .player1 && $0.savedPointType == .unforcedError }.count
        let p2Unforced = game.points.filter { $0.scorerPlayer == .player2 && $0.savedPointType == .unforcedError }.count

        var text = """
        🏸 SQUASH GAME ANALYSE
        Game \(game.gameNumber): \(p1) vs \(p2)
        Eindstand: \(game.player1Score)-\(game.player2Score) (\(winnerName) wint)

        📊 \(p1.uppercased()):
        • Gewonnen: \(p1Points.count) punten
        • Winners: \(p1Winners) | Forced errors: \(p1Forced) | Eigen fouten: \(p1Unforced)
        """

        let p1BestZone = game.points
            .filter { $0.scorerPlayer == .player1 && $0.pointZone != nil }
            .reduce(into: [String: Int]()) { dict, point in
                if let z = point.pointZone { dict[z.rawValue, default: 0] += 1 }
            }
            .max(by: { $0.value < $1.value })?.key
        if let zone = p1BestZone {
            text += "\n• Beste zone: \(zone)"
        }

        text += """

        📊 \(p2.uppercased()):
        • Gewonnen: \(p2Points.count) punten
        • Winners: \(p2Winners) | Forced errors: \(p2Forced) | Eigen fouten: \(p2Unforced)
        """

        let p2BestZone = game.points
            .filter { $0.scorerPlayer == .player2 && $0.pointZone != nil }
            .reduce(into: [String: Int]()) { dict, point in
                if let z = point.pointZone { dict[z.rawValue, default: 0] += 1 }
            }
            .max(by: { $0.value < $1.value })?.key
        if let zone = p2BestZone {
            text += "\n• Beste zone: \(zone)"
        }

        text += "\n\n📲 Gedeeld via Squash Analyzer"
        return text
    }

    static func textSummary(from match: SavedMatch) -> String {
        let p1 = match.player1Name
        let p2 = match.player2Name
        let winnerName = match.winnerName ?? "Gelijkspel"
        let sortedGames = match.games.sorted { $0.gameNumber < $1.gameNumber }

        var text = """
        🏸 SQUASH WEDSTRIJD ANALYSE
        \(p1) vs \(p2)
        Eindstand games: \(match.player1GamesWon)-\(match.player2GamesWon) (\(winnerName) wint)

        """

        for game in sortedGames {
            let gWinner = game.gameWinner == .player1 ? p1 : (game.gameWinner == .player2 ? p2 : "?")
            text += "Game \(game.gameNumber): \(game.player1Score)-\(game.player2Score) (\(gWinner))\n"
        }

        // Overall stats
        let allPoints = match.games.flatMap { $0.points }
        let p1Total = allPoints.filter { $0.scorerPlayer == .player1 }.count
        let p2Total = allPoints.filter { $0.scorerPlayer == .player2 }.count
        let p1Winners = allPoints.filter { $0.scorerPlayer == .player1 && $0.savedPointType == .winner }.count
        let p2Winners = allPoints.filter { $0.scorerPlayer == .player2 && $0.savedPointType == .winner }.count

        text += """

        📊 TOTAAL:
        • \(p1): \(p1Total) punten, \(p1Winners) winners
        • \(p2): \(p2Total) punten, \(p2Winners) winners

        📲 Gedeeld via Squash Analyzer
        """

        return text
    }

    // MARK: - Import

    static func importFromJSON(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(SquashExport.self, from: data)

        switch export.type {
        case .match:
            guard let matchData = export.match else { return }
            importMatch(matchData, context: context)
        case .game:
            guard let gameData = export.game else { return }
            importGame(gameData, context: context, matchRef: nil)
        }

        try context.save()
    }

    // MARK: - Text Summary from Live Game

    static func textSummary(from game: Game) -> String {
        let p1 = game.player1Name
        let p2 = game.player2Name
        let winnerName: String
        switch game.winner {
        case .player1: winnerName = p1
        case .player2: winnerName = p2
        case nil: winnerName = "Gelijkspel"
        }

        let p1Points = game.pointsWon(by: .player1).count
        let p2Points = game.pointsWon(by: .player2).count
        let p1Winners = game.winners(by: .player1).count
        let p2Winners = game.winners(by: .player2).count
        let p1Forced = game.forcedErrors(by: .player1).count
        let p2Forced = game.forcedErrors(by: .player2).count
        let p1Unforced = game.unforcedErrors(by: .player1).count
        let p2Unforced = game.unforcedErrors(by: .player2).count

        var text = """
        🏸 SQUASH GAME ANALYSE
        \(p1) vs \(p2)
        Eindstand: \(game.player1Score)-\(game.player2Score) (\(winnerName) wint)

        📊 \(p1.uppercased()):
        • Gewonnen: \(p1Points) punten
        • Winners: \(p1Winners) | Forced errors: \(p1Forced) | Eigen fouten: \(p1Unforced)
        """

        if let zone = game.bestZone(for: .player1) {
            text += "\n• Beste zone: \(zone.rawValue)"
        }

        text += """

        📊 \(p2.uppercased()):
        • Gewonnen: \(p2Points) punten
        • Winners: \(p2Winners) | Forced errors: \(p2Forced) | Eigen fouten: \(p2Unforced)
        """

        if let zone = game.bestZone(for: .player2) {
            text += "\n• Beste zone: \(zone.rawValue)"
        }

        text += "\n\n📲 Gedeeld via Squash Analyzer"
        return text
    }

    // MARK: - Write to temp file

    static func writeToTempFile(_ data: Data, filename: String) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: - Private helpers

    private static func matchExportData(from match: SavedMatch) -> MatchExportData {
        let games = match.games.sorted { $0.gameNumber < $1.gameNumber }.map { gameExportData(from: $0) }
        return MatchExportData(
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            savedAt: match.savedAt,
            games: games
        )
    }

    private static func gameExportData(from game: SavedGame) -> GameExportData {
        let points = game.points.sorted { $0.pointNumber < $1.pointNumber }.map {
            PointExportData(
                pointNumber: $0.pointNumber,
                scorer: $0.scorer,
                pointType: $0.pointType,
                zone: $0.zone,
                shotType: $0.shotType,
                server: $0.server,
                player1Score: $0.player1Score,
                player2Score: $0.player2Score,
                duration: $0.duration
            )
        }
        let lets = game.lets.sorted { $0.letNumber < $1.letNumber }.map {
            LetExportData(
                letNumber: $0.letNumber,
                requestedBy: $0.requestedBy,
                server: $0.server,
                player1Score: $0.player1Score,
                player2Score: $0.player2Score
            )
        }
        return GameExportData(
            gameNumber: game.gameNumber,
            player1Name: game.player1Name,
            player2Name: game.player2Name,
            player1Score: game.player1Score,
            player2Score: game.player2Score,
            startingServer: game.startingServer,
            winner: game.winner,
            savedAt: game.savedAt,
            points: points,
            lets: lets
        )
    }

    private static func importMatch(_ matchData: MatchExportData, context: ModelContext) {
        // Check for duplicate (same players + savedAt)
        let savedMatch = SavedMatch(
            player1Name: matchData.player1Name,
            player2Name: matchData.player2Name,
            matchStartingServer: Player(rawValue: matchData.games.first?.startingServer ?? "") ?? .player1,
            bestOf: 5,
            savedAt: matchData.savedAt
        )
        context.insert(savedMatch)
        for gameData in matchData.games {
            importGame(gameData, context: context, matchRef: savedMatch)
        }
    }

    @discardableResult
    private static func importGame(_ gameData: GameExportData, context: ModelContext, matchRef: SavedMatch?) -> SavedGame {
        let savedGame = SavedGame(
            gameNumber: gameData.gameNumber,
            player1Name: gameData.player1Name,
            player2Name: gameData.player2Name,
            player1Score: gameData.player1Score,
            player2Score: gameData.player2Score,
            startingServer: Player(rawValue: gameData.startingServer) ?? .player1,
            winner: gameData.winner.flatMap { Player(rawValue: $0) }
        )
        savedGame.savedAt = gameData.savedAt
        savedGame.match = matchRef

        context.insert(savedGame)

        for pd in gameData.points {
            let sp = SavedPoint(
                pointNumber: pd.pointNumber,
                scorer: Player(rawValue: pd.scorer) ?? .player1,
                pointType: PointType(rawValue: pd.pointType) ?? .winner,
                zone: CourtZone(rawValue: pd.zone),
                shotType: ShotType(rawValue: pd.shotType),
                server: Player(rawValue: pd.server) ?? .player1,
                player1Score: pd.player1Score,
                player2Score: pd.player2Score,
                duration: pd.duration
            )
            sp.game = savedGame
            savedGame.points.append(sp)
            context.insert(sp)
        }

        for ld in gameData.lets {
            let sl = SavedLet(
                letNumber: ld.letNumber,
                requestedBy: Player(rawValue: ld.requestedBy) ?? .player1,
                server: Player(rawValue: ld.server) ?? .player1,
                player1Score: ld.player1Score,
                player2Score: ld.player2Score
            )
            sl.game = savedGame
            savedGame.lets.append(sl)
            context.insert(sl)
        }

        matchRef?.games.append(savedGame)
        return savedGame
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Items Wrapper (Identifiable for .sheet)

struct ShareItemsWrapper: Identifiable {
    let id = UUID()
    let items: [Any]
}
