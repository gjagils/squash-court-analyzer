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
}
