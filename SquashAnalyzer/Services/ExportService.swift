import Foundation
import SwiftData
import SwiftUI
import CryptoKit

// MARK: - Full Backup Structures

struct FullBackup: Codable {
    let version: Int
    let backupDate: Date
    let players: [PlayerBackupData]
    let matches: [MatchExportData]
    let standaloneGames: [GameExportData]
}

struct BackupEnvelope: Codable {
    let formatVersion: Int
    let schemaVersion: String
    let appVersion: String
    let createdAt: Date
    let checksum: String
    let payload: FullBackup
}

enum BackupValidationError: LocalizedError {
    case unsupportedVersion(Int)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Deze backupversie (\(version)) wordt niet ondersteund."
        case .checksumMismatch:
            return "De backup is beschadigd of onvolledig; de checksum klopt niet."
        }
    }
}

struct PlayerBackupData: Codable {
    let id: String
    let name: String
    let coachingFocusAreas: [String]
    let coachingNotes: String
    let createdAt: Date
    /// Base64 JPEG (absent in backups made before photos existed)
    let photoBase64: String?
}

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
    let id: String?
    let player1Name: String
    let player2Name: String
    let savedAt: Date
    let updatedAt: Date?
    let matchStartingServer: String?
    let bestOf: Int?
    let status: String?
    let player1CoachingFocus: [String]?
    let player2CoachingFocus: [String]?
    let player1CoachingNotes: String?
    let player2CoachingNotes: String?
    /// Games won before tracking started (absent in older backups)
    var player1GamesBefore: Int? = nil
    var player2GamesBefore: Int? = nil
    /// Games won after tracking stopped, filled in afterwards (absent in older backups)
    var player1GamesAfter: Int? = nil
    var player2GamesAfter: Int? = nil
    let games: [GameExportData]
}

struct GameExportData: Codable {
    let id: String?
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
    let id: String?
    let pointNumber: Int
    let scorer: String
    let pointType: String
    let zone: String
    let shotType: String
    let server: String
    let player1Score: Int
    let player2Score: Int
    let duration: Double
    let timestamp: Date?
}

struct LetExportData: Codable {
    let id: String?
    let letNumber: Int
    let requestedBy: String
    let server: String
    let player1Score: Int
    let player2Score: Int
    let timestamp: Date?
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
        let p1Strokes = game.points.filter { $0.scorerPlayer == .player1 && $0.savedPointType == .stroke }.count
        let p2Strokes = game.points.filter { $0.scorerPlayer == .player2 && $0.savedPointType == .stroke }.count
        let p1Service = game.points.filter { $0.scorerPlayer == .player1 && $0.savedPointType == .servicePoint }.count
        let p2Service = game.points.filter { $0.scorerPlayer == .player2 && $0.savedPointType == .servicePoint }.count

        var text = """
        🏸 SQUASH GAME ANALYSE
        Game \(game.gameNumber): \(p1) vs \(p2)
        Eindstand: \(game.player1Score)-\(game.player2Score) (\(winnerName) wint)

        📊 \(p1.uppercased()):
        • Gewonnen: \(p1Points.count) punten
        • Winners: \(p1Winners) | Forced errors: \(p1Forced) | Eigen fouten: \(p1Unforced)
        • Servicepunten: \(p1Service) | Strokes: \(p1Strokes)
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
        • Servicepunten: \(p2Service) | Strokes: \(p2Strokes)
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
        let result = match.winnerName.map { "(\($0) wint)" } ?? "(incompleet)"
        let sortedGames = match.games.sorted { $0.gameNumber < $1.gameNumber }

        var text = """
        🏸 SQUASH WEDSTRIJD ANALYSE
        \(p1) vs \(p2)
        Eindstand games: \(match.player1GamesWon)-\(match.player2GamesWon) \(result)

        """

        for game in sortedGames {
            let gWinner = game.gameWinner == .player1 ? p1 : (game.gameWinner == .player2 ? p2 : "?")
            text += "Game \(game.gameNumber): \(game.player1Score)-\(game.player2Score) (\(gWinner))\n"
        }
        if match.player1GamesAfter + match.player2GamesAfter > 0 {
            text += "Uitslag achteraf aangevuld: \(p1) \(match.player1GamesAfter) – \(match.player2GamesAfter) \(p2) in games\n"
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

    // MARK: - Full Backup Export

    static func exportFullBackup(
        players: [SavedPlayer],
        matches: [SavedMatch],
        standaloneGames: [SavedGame]
    ) throws -> Data {
        let playerData = players.map {
            PlayerBackupData(
                id: $0.id.uuidString,
                name: $0.name,
                coachingFocusAreas: $0.coachingFocusAreas,
                coachingNotes: $0.coachingNotes,
                createdAt: $0.createdAt,
                photoBase64: $0.photoData?.base64EncodedString()
            )
        }
        let matchData = matches.map { matchExportData(from: $0) }
        let gameData = standaloneGames.map { gameExportData(from: $0) }
        let backup = FullBackup(
            version: 2,
            backupDate: Date(),
            players: playerData,
            matches: matchData,
            standaloneGames: gameData
        )
        let payloadData = try canonicalData(for: backup)
        let envelope = BackupEnvelope(
            formatVersion: 2,
            schemaVersion: "1.0.0",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            createdAt: Date(),
            checksum: SHA256.hash(data: payloadData).map { String(format: "%02x", $0) }.joined(),
            payload: backup
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    // MARK: - Full Backup Import

    /// Imports a full backup. Returns counts of (players, matches, standaloneGames) imported.
    static func importFullBackup(_ data: Data, context: ModelContext) throws -> (players: Int, matches: Int, games: Int) {
        let backup = try decodeAndValidateBackup(data)

        var playerCount = 0
        for pd in backup.players {
            let player = SavedPlayer(
                id: UUID(uuidString: pd.id) ?? UUID(),
                name: pd.name,
                coachingFocusAreas: pd.coachingFocusAreas,
                coachingNotes: pd.coachingNotes,
                createdAt: pd.createdAt,
                photoData: pd.photoBase64.flatMap { Data(base64Encoded: $0) }
            )
            context.insert(player)
            playerCount += 1
        }

        var matchCount = 0
        for matchData in backup.matches {
            importMatch(matchData, context: context)
            matchCount += 1
        }

        var gameCount = 0
        for gameData in backup.standaloneGames {
            importGame(gameData, context: context, matchRef: nil)
            gameCount += 1
        }

        try context.save()
        return (playerCount, matchCount, gameCount)
    }

    /// Deletes all existing data then imports the backup (clean restore).
    static func replaceWithBackup(_ data: Data, context: ModelContext) throws -> (players: Int, matches: Int, games: Int) {
        // Validate completely before touching the user's existing data.
        _ = try decodeAndValidateBackup(data)
        // Delete existing data
        try context.delete(model: SavedPoint.self)
        try context.delete(model: SavedLet.self)
        try context.delete(model: SavedGame.self)
        try context.delete(model: SavedMatch.self)
        try context.delete(model: SavedPlayer.self)
        try context.save()

        return try importFullBackup(data, context: context)
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
        let p1Strokes = game.strokes(by: .player1).count
        let p2Strokes = game.strokes(by: .player2).count
        let p1Service = game.servicePoints(by: .player1).count
        let p2Service = game.servicePoints(by: .player2).count

        var text = """
        🏸 SQUASH GAME ANALYSE
        \(p1) vs \(p2)
        Eindstand: \(game.player1Score)-\(game.player2Score) (\(winnerName) wint)

        📊 \(p1.uppercased()):
        • Gewonnen: \(p1Points) punten
        • Winners: \(p1Winners) | Forced errors: \(p1Forced) | Eigen fouten: \(p1Unforced)
        • Servicepunten: \(p1Service) | Strokes: \(p1Strokes)
        """

        if let zone = game.bestZone(for: .player1) {
            text += "\n• Beste zone: \(zone.rawValue)"
        }

        text += """

        📊 \(p2.uppercased()):
        • Gewonnen: \(p2Points) punten
        • Winners: \(p2Winners) | Forced errors: \(p2Forced) | Eigen fouten: \(p2Unforced)
        • Servicepunten: \(p2Service) | Strokes: \(p2Strokes)
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

    // MARK: - iCloud Backup

    enum iCloudError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "iCloud Drive is niet beschikbaar. Controleer of je bent ingelogd bij iCloud en iCloud Drive is ingeschakeld in Instellingen → Squash Analyzer."
        }
    }

    /// The iCloud container identifier (must match what is configured in Signing & Capabilities).
    static let iCloudContainerID = "iCloud.com.squashanalyzer.app"

    /// Returns the app's folder inside iCloud Drive (Documents), creating it when needed.
    static var iCloudDirectory: URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID) else {
            return nil
        }
        let dir = base.appendingPathComponent("Documents")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Creates a full backup and writes it directly to iCloud Drive.
    /// Returns the URL of the saved file.
    static func saveBackupToiCloud(
        players: [SavedPlayer],
        matches: [SavedMatch],
        standaloneGames: [SavedGame]
    ) throws -> URL {
        guard let dir = iCloudDirectory else {
            throw iCloudError.unavailable
        }
        let data = try exportFullBackup(players: players, matches: matches, standaloneGames: standaloneGames)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "squash-backup-\(formatter.string(from: Date())).json"
        let fileURL = dir.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        try data.write(to: dir.appendingPathComponent("latest-backup.json"), options: .atomic)
        rotateBackups(in: dir, keeping: 7)
        return fileURL
    }

    // MARK: - Private helpers

    private static func canonicalData(for backup: FullBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(backup)
    }

    private static func decodeAndValidateBackup(_ data: Data) throws -> FullBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let envelope = try? decoder.decode(BackupEnvelope.self, from: data) {
            guard envelope.formatVersion == 2 else {
                throw BackupValidationError.unsupportedVersion(envelope.formatVersion)
            }
            let payloadData = try canonicalData(for: envelope.payload)
            let checksum = SHA256.hash(data: payloadData).map { String(format: "%02x", $0) }.joined()
            guard checksum == envelope.checksum else {
                throw BackupValidationError.checksumMismatch
            }
            return envelope.payload
        }

        // Version 1 backups remain importable for existing App Store users.
        let legacy = try decoder.decode(FullBackup.self, from: data)
        guard legacy.version == 1 else {
            throw BackupValidationError.unsupportedVersion(legacy.version)
        }
        return legacy
    }

    private static func rotateBackups(in directory: URL, keeping limit: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        let datedBackups = files
            .filter { $0.lastPathComponent.hasPrefix("squash-backup-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        for expired in datedBackups.dropFirst(limit) {
            try? FileManager.default.removeItem(at: expired)
        }
    }

    private static func matchExportData(from match: SavedMatch) -> MatchExportData {
        let games = match.games.sorted { $0.gameNumber < $1.gameNumber }.map { gameExportData(from: $0) }
        return MatchExportData(
            id: match.id.uuidString,
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            savedAt: match.savedAt,
            updatedAt: match.updatedAt,
            matchStartingServer: match.matchStartingServer,
            bestOf: match.bestOf,
            status: match.status,
            player1CoachingFocus: match.player1CoachingFocus,
            player2CoachingFocus: match.player2CoachingFocus,
            player1CoachingNotes: match.player1CoachingNotes,
            player2CoachingNotes: match.player2CoachingNotes,
            player1GamesBefore: match.player1GamesBefore,
            player2GamesBefore: match.player2GamesBefore,
            player1GamesAfter: match.player1GamesAfter,
            player2GamesAfter: match.player2GamesAfter,
            games: games
        )
    }

    private static func gameExportData(from game: SavedGame) -> GameExportData {
        let points = game.points.sorted { $0.pointNumber < $1.pointNumber }.map {
            PointExportData(
                id: $0.id.uuidString,
                pointNumber: $0.pointNumber,
                scorer: $0.scorer,
                pointType: $0.pointType,
                zone: $0.zone,
                shotType: $0.shotType,
                server: $0.server,
                player1Score: $0.player1Score,
                player2Score: $0.player2Score,
                duration: $0.duration,
                timestamp: $0.timestamp
            )
        }
        let lets = game.lets.sorted { $0.letNumber < $1.letNumber }.map {
            LetExportData(
                id: $0.id.uuidString,
                letNumber: $0.letNumber,
                requestedBy: $0.requestedBy,
                server: $0.server,
                player1Score: $0.player1Score,
                player2Score: $0.player2Score,
                timestamp: $0.timestamp
            )
        }
        return GameExportData(
            id: game.id.uuidString,
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
            id: matchData.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
            player1Name: matchData.player1Name,
            player2Name: matchData.player2Name,
            matchStartingServer: Player(rawValue: matchData.matchStartingServer ?? matchData.games.first?.startingServer ?? "") ?? .player1,
            bestOf: matchData.bestOf ?? 5,
            savedAt: matchData.savedAt,
            updatedAt: matchData.updatedAt ?? matchData.savedAt,
            status: MatchStatus(rawValue: matchData.status ?? "") ?? .completed
        )
        savedMatch.player1CoachingFocus = matchData.player1CoachingFocus ?? []
        savedMatch.player2CoachingFocus = matchData.player2CoachingFocus ?? []
        savedMatch.player1CoachingNotes = matchData.player1CoachingNotes ?? ""
        savedMatch.player2CoachingNotes = matchData.player2CoachingNotes ?? ""
        savedMatch.player1GamesBefore = matchData.player1GamesBefore ?? 0
        savedMatch.player2GamesBefore = matchData.player2GamesBefore ?? 0
        savedMatch.player1GamesAfter = matchData.player1GamesAfter ?? 0
        savedMatch.player2GamesAfter = matchData.player2GamesAfter ?? 0
        context.insert(savedMatch)
        for gameData in matchData.games {
            importGame(gameData, context: context, matchRef: savedMatch)
        }
    }

    @discardableResult
    private static func importGame(_ gameData: GameExportData, context: ModelContext, matchRef: SavedMatch?) -> SavedGame {
        let savedGame = SavedGame(
            id: gameData.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
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
                id: pd.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
                pointNumber: pd.pointNumber,
                scorer: Player(rawValue: pd.scorer) ?? .player1,
                pointType: SavedPoint.pointType(raw: pd.pointType, shotType: pd.shotType),
                zone: CourtZone(rawValue: pd.zone),
                shotType: ShotType(rawValue: pd.shotType),
                server: Player(rawValue: pd.server) ?? .player1,
                player1Score: pd.player1Score,
                player2Score: pd.player2Score,
                timestamp: pd.timestamp ?? Date(),
                duration: pd.duration
            )
            sp.game = savedGame
            savedGame.points.append(sp)
            context.insert(sp)
        }

        for ld in gameData.lets {
            let sl = SavedLet(
                id: ld.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
                letNumber: ld.letNumber,
                requestedBy: Player(rawValue: ld.requestedBy) ?? .player1,
                server: Player(rawValue: ld.server) ?? .player1,
                player1Score: ld.player1Score,
                player2Score: ld.player2Score,
                timestamp: ld.timestamp ?? Date()
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
