import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The backup file must read the same on iPhone and Android: the checksum of
/// the sample below was computed on Darwin, and these tests also run on Android.
final class BackupTests: XCTestCase {
    static func sample() -> FullBackup {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let points = [
            PointExportData(id: "11111111-2222-4333-8444-555555555555", pointNumber: 1, scorer: "Speler 1", pointType: "Winner",
                            zone: "Voor Links", shotType: "Drive", server: "Speler 1", player1Score: 1, player2Score: 0,
                            duration: 3.25, timestamp: date),
            PointExportData(id: nil, pointNumber: 2, scorer: "Speler 2", pointType: "Unforced Error",
                            zone: "", shotType: "", server: "Speler 1", player1Score: 1, player2Score: 1,
                            duration: 12.0, timestamp: nil),
        ]
        let lets = [LetExportData(id: nil, letNumber: 1, requestedBy: "Speler 2", server: "Speler 1",
                                  player1Score: 1, player2Score: 1, timestamp: date)]
        let game = GameExportData(id: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE", gameNumber: 1, player1Name: "Paul Stéenks",
                                  player2Name: "Jaïr 🎾", player1Score: 11, player2Score: 9, startingServer: "Speler 1",
                                  winner: "Speler 1", savedAt: date, points: points, lets: lets)
        let match = MatchExportData(id: "6F1C2B3A-4D5E-4F60-8A7B-9C0D1E2F3A4B", player1Name: "Paul Stéenks", player2Name: "Jaïr 🎾",
                                    savedAt: date, updatedAt: date, matchStartingServer: "Speler 1", bestOf: 5, status: "completed",
                                    player1CoachingFocus: ["Backhand", "Drop"], player2CoachingFocus: [],
                                    player1CoachingNotes: "Let op \"lengte\" / tempo", player2CoachingNotes: nil,
                                    player1GamesBefore: 1, player2GamesBefore: 0, player1Id: "0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2",
                                    games: [game])
        let player = PlayerBackupData(id: "0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2", name: "Paul Stéenks", coachingFocusAreas: ["Drop"],
                                      coachingNotes: "", createdAt: date, photoBase64: nil, cardId: nil)
        let award = BadgeAwardBackupData(cardId: "0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2", badge: "five-in-a-row",
                                         matchId: "6F1C2B3A-4D5E-4F60-8A7B-9C0D1E2F3A4B", earnedAt: date,
                                         opponentName: "Jaïr 🎾", awardedBy: "install-A", deletedAt: nil)
        return FullBackup(version: 2, backupDate: date, players: [player], matches: [match], standaloneGames: [], badgeAwards: [award])
    }

    /// Made by Apple's JSONEncoder (sorted keys, ISO 8601, "/" escaped as "\\/")
    static let darwinCanonical = "{\"backupDate\":\"2026-09-21T14:13:20Z\",\"badgeAwards\":[{\"awardedBy\":\"install-A\",\"badge\":\"five-in-a-row\",\"cardId\":\"0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2\",\"earnedAt\":\"2026-09-21T14:13:20Z\",\"matchId\":\"6F1C2B3A-4D5E-4F60-8A7B-9C0D1E2F3A4B\",\"opponentName\":\"Jaïr 🎾\"}],\"matches\":[{\"bestOf\":5,\"games\":[{\"gameNumber\":1,\"id\":\"AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE\",\"lets\":[{\"letNumber\":1,\"player1Score\":1,\"player2Score\":1,\"requestedBy\":\"Speler 2\",\"server\":\"Speler 1\",\"timestamp\":\"2026-09-21T14:13:20Z\"}],\"player1Name\":\"Paul Stéenks\",\"player1Score\":11,\"player2Name\":\"Jaïr 🎾\",\"player2Score\":9,\"points\":[{\"duration\":3.25,\"id\":\"11111111-2222-4333-8444-555555555555\",\"player1Score\":1,\"player2Score\":0,\"pointNumber\":1,\"pointType\":\"Winner\",\"scorer\":\"Speler 1\",\"server\":\"Speler 1\",\"shotType\":\"Drive\",\"timestamp\":\"2026-09-21T14:13:20Z\",\"zone\":\"Voor Links\"},{\"duration\":12,\"player1Score\":1,\"player2Score\":1,\"pointNumber\":2,\"pointType\":\"Unforced Error\",\"scorer\":\"Speler 2\",\"server\":\"Speler 1\",\"shotType\":\"\",\"zone\":\"\"}],\"savedAt\":\"2026-09-21T14:13:20Z\",\"startingServer\":\"Speler 1\",\"winner\":\"Speler 1\"}],\"id\":\"6F1C2B3A-4D5E-4F60-8A7B-9C0D1E2F3A4B\",\"matchStartingServer\":\"Speler 1\",\"player1CoachingFocus\":[\"Backhand\",\"Drop\"],\"player1CoachingNotes\":\"Let op \\\"lengte\\\" \\/ tempo\",\"player1GamesBefore\":1,\"player1Id\":\"0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2\",\"player1Name\":\"Paul Stéenks\",\"player2CoachingFocus\":[],\"player2GamesBefore\":0,\"player2Name\":\"Jaïr 🎾\",\"savedAt\":\"2026-09-21T14:13:20Z\",\"status\":\"completed\",\"updatedAt\":\"2026-09-21T14:13:20Z\"}],\"players\":[{\"coachingFocusAreas\":[\"Drop\"],\"coachingNotes\":\"\",\"createdAt\":\"2026-09-21T14:13:20Z\",\"id\":\"0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2\",\"name\":\"Paul Stéenks\"}],\"standaloneGames\":[],\"version\":2}"
    static let darwinChecksum = "166528aa1b3ce9e551a68f8b44158a100415ea460cc0d1c5925298347c4b4445"

    func testCanonicalJSONIsTheSameOnEveryPlatform() throws {
        let data = try BackupCodec.canonicalData(for: BackupTests.sample())
        XCTAssertEqual(String(data: data, encoding: .utf8), BackupTests.darwinCanonical)
        XCTAssertEqual(BackupCodec.checksum(of: data), BackupTests.darwinChecksum)
    }

    private func thrown(_ body: () throws -> Void) -> Error? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    func testRoundTripThroughTheFile() throws {
        let data = try BackupCodec.encode(BackupTests.sample(), appVersion: "test", createdAt: Date(timeIntervalSince1970: 1_790_000_100))
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("\"checksum\" : \"\(BackupTests.darwinChecksum)\""))
        XCTAssertEqual(try BackupCodec.decode(data), BackupTests.sample())
    }

    func testATamperedFileIsRefused() throws {
        let data = try BackupCodec.encode(BackupTests.sample(), appVersion: "test")
        let tampered = (String(data: data, encoding: .utf8) ?? "").replacingOccurrences(of: "\"player1Score\" : 11", with: "\"player1Score\" : 12")
        let error = thrown { _ = try BackupCodec.decode(tampered.data(using: String.Encoding.utf8)!) }
        XCTAssertEqual(error as? BackupValidationError, BackupValidationError.checksumMismatch)
    }

    func testOldAndUnknownFiles() throws {
        let legacy = "{\"version\":1,\"backupDate\":\"2026-01-01T10:00:00Z\",\"players\":[],\"matches\":[],\"standaloneGames\":[]}"
        let read = try BackupCodec.decode(legacy.data(using: String.Encoding.utf8)!)
        XCTAssertEqual(read.version, 1)
        XCTAssertNil(read.badgeAwards)

        let future = legacy.replacingOccurrences(of: "\"version\":1", with: "\"version\":7")
        let futureError = thrown { _ = try BackupCodec.decode(future.data(using: String.Encoding.utf8)!) }
        XCTAssertEqual(futureError as? BackupValidationError, BackupValidationError.unsupportedVersion(7))

        let garbage = thrown { _ = try BackupCodec.decode("geen backup".data(using: String.Encoding.utf8)!) }
        XCTAssertEqual(garbage as? BackupValidationError, BackupValidationError.unreadable)
    }

    /// Referee matches (format 3): the same JSON on both platforms; a backup
    /// without them stays format 2, byte for byte (the golden test above)
    func testRefereeMatchesMakeFormat3() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        var backup = BackupTests.sample()
        XCTAssertEqual(BackupCodec.formatVersion(for: backup), 2)
        backup.refereeMatches = [RefereeMatchBackupData(
            id: "9F8E7D6C-5B4A-4392-8180-706F5E4D3C2B", player1Name: "Jan", player2Name: "Piet",
            player1Id: nil, player2Id: "0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2", bestOf: 5,
            player1GamesBefore: 0, player2GamesBefore: 1,
            games: [RefereeMatchBackupData.Game(number: 2, player1Score: 11, player2Score: 7, winner: "Speler 1")],
            savedAt: date, status: "abandoned")]
        XCTAssertEqual(BackupCodec.formatVersion(for: backup), 3)

        let canonical = String(data: try BackupCodec.canonicalData(for: backup), encoding: .utf8) ?? ""
        XCTAssertTrue(canonical.contains("\"refereeMatches\":[{\"bestOf\":5,\"games\":[{\"number\":2,\"player1Score\":11,\"player2Score\":7,\"winner\":\"Speler 1\"}],\"id\":\"9F8E7D6C-5B4A-4392-8180-706F5E4D3C2B\",\"player1GamesBefore\":0,\"player1Name\":\"Jan\",\"player2GamesBefore\":1,\"player2Id\":\"0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2\",\"player2Name\":\"Piet\",\"savedAt\":\"2026-09-21T14:13:20Z\",\"status\":\"abandoned\"}]"), canonical)

        let data = try BackupCodec.encode(backup, appVersion: "test")
        XCTAssertTrue((String(data: data, encoding: .utf8) ?? "").contains("\"formatVersion\" : 3"))
        XCTAssertEqual(try BackupCodec.decode(data), backup)

        // An empty list is not written as format 3
        backup.refereeMatches = []
        XCTAssertEqual(BackupCodec.formatVersion(for: backup), 2)
    }

    /// T12: rally durations print the same in Swift and Kotlin JSON
    func testDurationsPrintTheSameOnBothPlatforms() throws {
        var texts: [String] = []
        for duration in [0.0004, 3.3333333333, 1234.5678, 0.001, 12.0] {
            let point = PointExportData(id: nil, pointNumber: 1, scorer: "Speler 1", pointType: "Winner", zone: "", shotType: "",
                                        server: "Speler 1", player1Score: 1, player2Score: 0, duration: duration, timestamp: nil)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let json = String(data: try encoder.encode(point), encoding: .utf8) ?? ""
            let start = json.range(of: "\"duration\":")!.upperBound
            texts.append(String(json[start...].prefix { $0 != "," }))
        }
        XCTAssertEqual(texts, ["0", "3.333", "1234.568", "0.001", "12"])
    }

    func testOldIOSPointsAreNormalized() {
        let ace = PointExportData(id: nil, pointNumber: 1, scorer: "Speler 2", pointType: "Winner", zone: "Achter Links", shotType: "Ace",
                                  server: "Speler 2", player1Score: 0, player2Score: 1, duration: 4, timestamp: nil).normalized
        XCTAssertEqual(ace.pointType, PointType.servicePoint.rawValue)
        XCTAssertEqual(ace.shotType, "")
        XCTAssertEqual(ace.zone, "Achter Links")
        let stroke = PointExportData(id: nil, pointNumber: 2, scorer: "Speler 1", pointType: "Winner", zone: "", shotType: "Stroke",
                                     server: "Speler 1", player1Score: 1, player2Score: 1, duration: 4, timestamp: nil).normalized
        XCTAssertEqual(stroke.pointType, PointType.stroke.rawValue)
        let odd = PointExportData(id: nil, pointNumber: 3, scorer: "Iemand", pointType: "Raar", zone: "Dak", shotType: "Smash",
                                  server: "?", player1Score: 2, player2Score: 1, duration: 4, timestamp: nil).normalized
        XCTAssertEqual(odd.pointType, PointType.winner.rawValue)
        XCTAssertEqual(odd.scorer, Player.player1.rawValue)
        XCTAssertEqual(odd.zone, "")
        XCTAssertEqual(odd.shotType, "")
        XCTAssertEqual(BackupCounts(players: 2, matches: 3, games: 7, badges: 1).summary, "2 spelers, 3 wedstrijden, 7 games, 1 badges")
    }

    func testAutomaticBackupPlan() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertTrue(AutoBackupPlan.isDue(lastBackup: nil, now: now))
        // Weekly: last Friday 22:00 → this Friday 20:00 is due, Saturday after a Friday is not
        XCTAssertTrue(AutoBackupPlan.isDue(lastBackup: now.addingTimeInterval(-(7 * 24 - 2) * 3600), now: now))
        XCTAssertFalse(AutoBackupPlan.isDue(lastBackup: now.addingTimeInterval(-24 * 3600), now: now))
        XCTAssertFalse(AutoBackupPlan.isDue(lastBackup: now.addingTimeInterval(-(6 * 24 - 1) * 3600), now: now))
        XCTAssertTrue(AutoBackupPlan.isDue(lastBackup: now.addingTimeInterval(-6 * 24 * 3600), now: now))

        var names = ["latest-backup.json", "notities.txt", "squash-backup-2026-10-01-090552.json"]
        for day in 1...9 {
            names.append("squash-backup-2026-09-0\(day)-120000.json")
        }
        XCTAssertEqual(AutoBackupPlan.filesToDelete(names),
                       ["squash-backup-2026-09-03-120000.json", "squash-backup-2026-09-02-120000.json", "squash-backup-2026-09-01-120000.json"])
        XCTAssertTrue(AutoBackupPlan.filesToDelete(["squash-backup-a.json"]).isEmpty)
        XCTAssertTrue(AutoBackupPlan.fileName(at: now).hasPrefix("squash-backup-2026-09-2"))
        XCTAssertTrue(AutoBackupPlan.fileName(at: now).hasSuffix(".json"))
    }
}
