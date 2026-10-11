import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Notitie per game (C3) and service/return (C4)
final class GameNotesTests: XCTestCase {
    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("gamenotes-\(UUID().uuidString)")
    }

    @MainActor
    func testANoteIsKeptPerGameAndAnEmptyOneRemoved() {
        let directory = folder()
        let notes = GameNotes()
        notes.configure(directory: directory)
        let game = UUID()
        XCTAssertEqual(notes.note(for: game), "")
        notes.set("  Backhand-volley te laat  ", for: game)
        XCTAssertEqual(notes.note(for: game), "Backhand-volley te laat")

        // Read again from the file, as after a restart
        let again = GameNotes()
        again.configure(directory: directory)
        XCTAssertEqual(again.note(for: game), "Backhand-volley te laat")
        again.set("   ", for: game)
        XCTAssertEqual(again.note(for: game), "")
        XCTAssertTrue(GameNoteFile.read(in: directory).isEmpty)
        try? FileManager.default.removeItem(at: directory)
    }

    func testNotesTravelInTheBackup() throws {
        let source = folder()
        let game = UUID()
        try GameNoteFile.write([GameNoteFile.key(game): "Meer lengte"], in: source)
        let plain = FullBackup(version: 2, backupDate: Date(timeIntervalSince1970: 1_793_181_600.0), players: [], matches: [], standaloneGames: [])
        let attached = TeamBackup.attach(plain, directory: source)
        XCTAssertEqual(attached.gameNotes, [GameNote(gameId: GameNoteFile.key(game), text: "Meer lengte")])
        let decoded = try BackupCodec.decode(try BackupCodec.encode(attached, appVersion: "test"))
        XCTAssertEqual(decoded.gameNotes, attached.gameNotes)

        // Merging keeps what the other phone wrote; replacing takes the file's
        let other = folder()
        try GameNoteFile.write([GameNoteFile.key(game): "Eigen notitie"], in: other)
        try TeamBackup.restore(decoded, directory: other, replacing: false)
        XCTAssertEqual(GameNoteFile.read(in: other)[GameNoteFile.key(game)], "Eigen notitie")
        try TeamBackup.restore(decoded, directory: other, replacing: true)
        XCTAssertEqual(GameNoteFile.read(in: other)[GameNoteFile.key(game)], "Meer lengte")

        // Without notes nothing is written into the backup
        let empty = folder()
        XCTAssertNil(TeamBackup.attach(plain, directory: empty).gameNotes)
        for url in [source, other, empty] { try? FileManager.default.removeItem(at: url) }
    }

    func testServiceAndReturnCountWhoServedEachRally() {
        let game = Game()
        game.assignStartingServer(Player.player1)
        // Player 1 serves and wins twice, then loses the rally: hand-out
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        game.addPoint(to: Player.player2, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        // Player 2 serves: wins one, then player 1 wins it back
        game.addPoint(to: Player.player2, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)

        let stats = ServiceReturnStats.of(game, for: Player.player1)
        XCTAssertEqual(stats, ServiceReturnStats(served: 3, wonOnServe: 2, received: 2, wonOnReturn: 1))
        XCTAssertEqual(ServiceReturnStats.line(stats.wonOnServe, of: stats.served), "2 van 3 gewonnen (67%)")
        XCTAssertEqual(ServiceReturnStats.line(0, of: 0), "Geen rally's")
        let other = ServiceReturnStats.of(game, for: Player.player2)
        XCTAssertEqual(other.served, 2)
        XCTAssertEqual(other.wonOnReturn, 1)
    }
}
