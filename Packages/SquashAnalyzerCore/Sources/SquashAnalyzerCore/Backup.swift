import Foundation
#if !SKIP
import CryptoKit
#endif

// The full backup file (players, coach matches, loose games, badge awards),
// shared by iOS and Android so a backup from one can be restored on the
// other. Moved out of iOS' ExportService with the exact same JSON keys, so
// existing backups keep working. The envelope carries a SHA-256 checksum over
// the payload encoded with sorted keys and ISO 8601 dates.

public struct FullBackup: Codable, Equatable, Sendable {
    public let version: Int
    public let backupDate: Date
    public let players: [PlayerBackupData]
    public let matches: [MatchExportData]
    public let standaloneGames: [GameExportData]
    /// Badge awards including deleted ones (absent in backups made before badges)
    public var badgeAwards: [BadgeAwardBackupData]? = nil

    public init(version: Int, backupDate: Date, players: [PlayerBackupData], matches: [MatchExportData],
                standaloneGames: [GameExportData], badgeAwards: [BadgeAwardBackupData]? = nil) {
        self.version = version
        self.backupDate = backupDate
        self.players = players
        self.matches = matches
        self.standaloneGames = standaloneGames
        self.badgeAwards = badgeAwards
    }
}

public struct BadgeAwardBackupData: Codable, Equatable, Sendable {
    public let cardId: String
    public let badge: String
    public let matchId: String
    public let earnedAt: Date
    public let opponentName: String
    public let awardedBy: String
    public let deletedAt: Date?

    public init(cardId: String, badge: String, matchId: String, earnedAt: Date, opponentName: String, awardedBy: String, deletedAt: Date?) {
        self.cardId = cardId
        self.badge = badge
        self.matchId = matchId
        self.earnedAt = earnedAt
        self.opponentName = opponentName
        self.awardedBy = awardedBy
        self.deletedAt = deletedAt
    }
}

public struct BackupEnvelope: Codable, Sendable {
    public let formatVersion: Int
    public let schemaVersion: String
    public let appVersion: String
    public let createdAt: Date
    public let checksum: String
    public let payload: FullBackup

    public init(formatVersion: Int, schemaVersion: String, appVersion: String, createdAt: Date, checksum: String, payload: FullBackup) {
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.checksum = checksum
        self.payload = payload
    }
}

public enum BackupValidationError: Error, Equatable {
    case unsupportedVersion(Int)
    case checksumMismatch
    case unreadable

    public var message: String {
        switch self {
        case .unsupportedVersion(let version): return "Deze backupversie (\(version)) wordt niet ondersteund."
        case .checksumMismatch: return "De backup is beschadigd of onvolledig; de checksum klopt niet."
        case .unreadable: return "Dit bestand is geen Squash Analyzer-backup."
        }
    }
}

public struct PlayerBackupData: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let coachingFocusAreas: [String]
    public let coachingNotes: String
    public let createdAt: Date
    /// Base64 JPEG (absent in backups made before photos existed)
    public let photoBase64: String?
    /// Linked player card (absent when the player uses their own card, and in older backups)
    public var cardId: String? = nil

    public init(id: String, name: String, coachingFocusAreas: [String], coachingNotes: String, createdAt: Date,
                photoBase64: String?, cardId: String? = nil) {
        self.id = id
        self.name = name
        self.coachingFocusAreas = coachingFocusAreas
        self.coachingNotes = coachingNotes
        self.createdAt = createdAt
        self.photoBase64 = photoBase64
        self.cardId = cardId
    }
}

public struct MatchExportData: Codable, Equatable, Sendable {
    public let id: String?
    public let player1Name: String
    public let player2Name: String
    public let savedAt: Date
    public let updatedAt: Date?
    public let matchStartingServer: String?
    public let bestOf: Int?
    public let status: String?
    public let player1CoachingFocus: [String]?
    public let player2CoachingFocus: [String]?
    public let player1CoachingNotes: String?
    public let player2CoachingNotes: String?
    /// Games won before tracking started (absent in older backups)
    public var player1GamesBefore: Int? = nil
    public var player2GamesBefore: Int? = nil
    /// Games won after tracking stopped, filled in afterwards (absent in older backups)
    public var player1GamesAfter: Int? = nil
    public var player2GamesAfter: Int? = nil
    /// Players picked from "Kies speler" (absent for typed-in names and in older backups)
    public var player1Id: String? = nil
    public var player2Id: String? = nil
    public let games: [GameExportData]

    public init(id: String?, player1Name: String, player2Name: String, savedAt: Date, updatedAt: Date?,
                matchStartingServer: String?, bestOf: Int?, status: String?,
                player1CoachingFocus: [String]?, player2CoachingFocus: [String]?,
                player1CoachingNotes: String?, player2CoachingNotes: String?,
                player1GamesBefore: Int? = nil, player2GamesBefore: Int? = nil,
                player1GamesAfter: Int? = nil, player2GamesAfter: Int? = nil,
                player1Id: String? = nil, player2Id: String? = nil, games: [GameExportData]) {
        self.id = id
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.savedAt = savedAt
        self.updatedAt = updatedAt
        self.matchStartingServer = matchStartingServer
        self.bestOf = bestOf
        self.status = status
        self.player1CoachingFocus = player1CoachingFocus
        self.player2CoachingFocus = player2CoachingFocus
        self.player1CoachingNotes = player1CoachingNotes
        self.player2CoachingNotes = player2CoachingNotes
        self.player1GamesBefore = player1GamesBefore
        self.player2GamesBefore = player2GamesBefore
        self.player1GamesAfter = player1GamesAfter
        self.player2GamesAfter = player2GamesAfter
        self.player1Id = player1Id
        self.player2Id = player2Id
        self.games = games
    }
}

public struct GameExportData: Codable, Equatable, Sendable {
    public let id: String?
    public let gameNumber: Int
    public let player1Name: String
    public let player2Name: String
    public let player1Score: Int
    public let player2Score: Int
    public let startingServer: String
    public let winner: String?
    public let savedAt: Date
    public let points: [PointExportData]
    public let lets: [LetExportData]

    public init(id: String?, gameNumber: Int, player1Name: String, player2Name: String, player1Score: Int, player2Score: Int,
                startingServer: String, winner: String?, savedAt: Date, points: [PointExportData], lets: [LetExportData]) {
        self.id = id
        self.gameNumber = gameNumber
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.startingServer = startingServer
        self.winner = winner
        self.savedAt = savedAt
        self.points = points
        self.lets = lets
    }
}

public struct PointExportData: Codable, Equatable, Sendable {
    public let id: String?
    public let pointNumber: Int
    public let scorer: String
    public let pointType: String
    public let zone: String
    public let shotType: String
    public let server: String
    public let player1Score: Int
    public let player2Score: Int
    public let duration: Double
    public let timestamp: Date?
    /// Volley switch; written only when true, absent in older backups
    public var isVolley: Bool? = nil

    public init(id: String?, pointNumber: Int, scorer: String, pointType: String, zone: String, shotType: String,
                server: String, player1Score: Int, player2Score: Int, duration: Double, timestamp: Date?,
                isVolley: Bool? = nil) {
        self.id = id
        self.pointNumber = pointNumber
        self.scorer = scorer
        self.pointType = pointType
        self.zone = zone
        self.shotType = shotType
        self.server = server
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.duration = duration
        self.timestamp = timestamp
        self.isVolley = isVolley
    }
}

public struct LetExportData: Codable, Equatable, Sendable {
    public let id: String?
    public let letNumber: Int
    public let requestedBy: String
    public let server: String
    public let player1Score: Int
    public let player2Score: Int
    public let timestamp: Date?

    public init(id: String?, letNumber: Int, requestedBy: String, server: String, player1Score: Int, player2Score: Int, timestamp: Date?) {
        self.id = id
        self.letNumber = letNumber
        self.requestedBy = requestedBy
        self.server = server
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.timestamp = timestamp
    }
}

/// Writing and reading the backup file
public enum BackupCodec {
    /// The payload as the checksum sees it: sorted keys, ISO 8601 dates
    public static func canonicalData(for backup: FullBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(backup)
    }

    /// Lowercase hex SHA-256
    public static func checksum(of data: Data) -> String {
        let digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
        var hex = ""
        for byte in SHA256.hash(data: data) {
            let value = Int(byte)
            hex += digits[value / 16] + digits[value % 16]
        }
        return hex
    }

    /// A version-2 backup file: an envelope with the checksum around the payload
    public static func encode(_ backup: FullBackup, appVersion: String, createdAt: Date = Date()) throws -> Data {
        let envelope = BackupEnvelope(formatVersion: 2, schemaVersion: "1.0.0", appVersion: appVersion, createdAt: createdAt,
                                      checksum: checksum(of: try canonicalData(for: backup)), payload: backup)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    /// Reads a backup file: a version-2 envelope (checksum verified) or an
    /// old version-1 file. Throws before anything is changed on the device.
    public static func decode(_ data: Data) throws -> FullBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let envelope = try? decoder.decode(BackupEnvelope.self, from: data) {
            guard envelope.formatVersion == 2 else { throw BackupValidationError.unsupportedVersion(envelope.formatVersion) }
            guard checksum(of: try canonicalData(for: envelope.payload)) == envelope.checksum else {
                throw BackupValidationError.checksumMismatch
            }
            return envelope.payload
        }
        // Version 1 backups remain importable for existing App Store users
        guard let legacy = try? decoder.decode(FullBackup.self, from: data) else { throw BackupValidationError.unreadable }
        guard legacy.version == 1 else { throw BackupValidationError.unsupportedVersion(legacy.version) }
        return legacy
    }
}

// MARK: - Restoring on another platform

extension PointExportData {
    /// Only values the app can store: iOS' old points kept "Stroke"/"Ace" as
    /// the shot type (now point types, like `SavedPoint.pointType(raw:shotType:)`),
    /// and an unknown zone, shot or player falls back instead of failing the restore.
    /// (Looked up via `allCases`: an `X(rawValue:)` call here transpiles to the
    /// enum's private Kotlin constructor in the app build.)
    public var normalized: PointExportData {
        var type = PointType.winner
        if shotType == "Stroke" {
            type = PointType.stroke
        } else if shotType == "Ace" {
            type = PointType.servicePoint
        } else {
            for candidate in PointType.allCases where candidate.rawValue == pointType {
                type = candidate
            }
        }
        var zoneValue = ""
        for candidate in CourtZone.allCases where candidate.rawValue == zone {
            zoneValue = candidate.rawValue
        }
        var shotValue = ""
        for candidate in ShotType.allCases where candidate.rawValue == shotType {
            shotValue = candidate.rawValue
        }
        let players = [Player.player1.rawValue, Player.player2.rawValue]
        return PointExportData(id: id, pointNumber: pointNumber,
                               scorer: players.contains(scorer) ? scorer : Player.player1.rawValue,
                               pointType: type.rawValue, zone: zoneValue, shotType: shotValue,
                               server: players.contains(server) ? server : Player.player1.rawValue,
                               player1Score: player1Score, player2Score: player2Score, duration: duration, timestamp: timestamp,
                               isVolley: isVolley == true ? true : nil)
    }
}

/// What a restore added
public struct BackupCounts: Equatable, Sendable {
    public let players: Int
    public let matches: Int
    public let games: Int
    public let badges: Int

    public init(players: Int, matches: Int, games: Int, badges: Int) {
        self.players = players
        self.matches = matches
        self.games = games
        self.badges = badges
    }

    public var summary: String {
        "\(players) spelers, \(matches) wedstrijden, \(games) games, \(badges) badges"
    }
}

/// The app's data as a backup, and a backup back into the app (Room on Android)
public protocol BackupStore: AnyObject, Sendable {
    func makeBackup() async throws -> FullBackup
    /// `replacing` first removes players, coach matches and badges (referee
    /// matches are not in the backup format and stay, as on iOS); otherwise
    /// only what is not there yet is added, and a deleted badge stays deleted.
    func restore(_ backup: FullBackup, replacing: Bool) async throws -> BackupCounts
}

/// Choosing where a backup file goes and which one to read (the platform's file picker)
public protocol BackupFiles: AnyObject, Sendable {
    /// False when the user cancelled
    func save(_ data: Data, suggestedName: String) async throws -> Bool
    /// Nil when the user cancelled
    func open() async throws -> Data?
}

// MARK: - Automatic backups

/// When an automatic backup is due and which old files go, on iOS (iCloud
/// Drive) and Android (a chosen folder): dated files `squash-backup-…json`,
/// newest 7 kept, so about seven weeks back.
public enum AutoBackupPlan {
    public static let keep = 7
    public static let prefix = "squash-backup-"

    /// Once a week: the app is mostly used one evening a week (Friday), and
    /// the backup is made when the app goes to the background, so that
    /// evening's matches are in it. Due when there was none yet or the last
    /// is 6 days old (not 7, so a session a bit earlier than last week still counts).
    public static func isDue(lastBackup: Date?, now: Date = Date()) -> Bool {
        guard let lastBackup else { return true }
        return now.timeIntervalSince(lastBackup) >= 6 * 24 * 3600
    }

    /// "squash-backup-2026-10-01-090552.json"; the name sorts by time
    public static func fileName(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return prefix + formatter.string(from: date) + ".json"
    }

    /// The dated backups beyond the newest `keep`; other files are left alone
    public static func filesToDelete(_ names: [String], keep: Int = AutoBackupPlan.keep) -> [String] {
        var backups: [String] = []
        for name in names where name.hasPrefix(prefix) && name.hasSuffix(".json") {
            backups.append(name)
        }
        backups.sort { first, second in first > second }
        return Array(backups.dropFirst(keep))
    }
}

/// Turning automatic backups on and off (Android: a folder the user picks)
public protocol AutoBackupControl: AnyObject, Sendable {
    /// The chosen folder's name while automatic backups are on, nil when off
    func folderName() -> String?
    func lastBackupDate() -> Date?
    /// Asks for a folder, turns automatic backups on and makes one right away; false when cancelled
    func turnOn() async throws -> Bool
    func turnOff()
}
