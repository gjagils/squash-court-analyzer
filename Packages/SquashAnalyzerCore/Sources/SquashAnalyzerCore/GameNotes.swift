import Foundation
import Observation

// Notitie per game (backlog C3, 12 oktober 2026): what the coach noticed in a
// game ("backhand-volley te laat"), shown in the analysis and on the coach
// card. Kept in a JSON file next to the team matches, by game id, so no
// SwiftData or Room migration is needed; the full backup carries it
// (`FullBackup.gameNotes`). Notes are the coach's own: they stay out of the
// texts that are shared.

/// One note as stored in the file and the backup (a list, not a dictionary:
/// Skip cannot encode a `[String: String]`)
public struct GameNote: Codable, Equatable, Sendable {
    public let gameId: String
    public let text: String

    public init(gameId: String, text: String) {
        self.gameId = gameId
        self.text = text
    }
}

/// The file with the notes: `{"version": 1, "notes": [{"gameId": "…", "text": "…"}]}`
public enum GameNoteFile {
    public static let fileName = "game-notes.json"
    public static let formatVersion = 1

    struct Envelope: Codable {
        var version: Int
        var notes: [GameNote]
    }

    /// As a list, sorted by game id so the file and the backup are stable
    public static func list(_ notes: [String: String]) -> [GameNote] {
        var result: [GameNote] = []
        for (gameId, text) in notes { result.append(GameNote(gameId: gameId, text: text)) }
        result.sort { a, b in a.gameId < b.gameId }
        return result
    }

    public static func dictionary(_ notes: [GameNote]) -> [String: String] {
        var result: [String: String] = [:]
        for note in notes { result[note.gameId] = note.text }
        return result
    }

    /// All notes by game id (upper-case UUID string); empty when there is no file or it cannot be read
    public static func read(in directory: URL) -> [String: String] {
        let url = directory.appendingPathComponent(GameNoteFile.fileName)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return [:] }
        return dictionary(envelope.notes)
    }

    /// Written in one go (`.atomic`)
    public static func write(_ notes: [String: String], in directory: URL) throws {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(GameNoteFile.fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Envelope(version: GameNoteFile.formatVersion, notes: list(notes)))
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    static func key(_ gameId: UUID) -> String { gameId.uuidString.uppercased() }

    /// The text as stored: trimmed; nil for nothing
    static func cleaned(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// The notes for the screens: read once, written on every change. The app
/// sets the folder at start (iOS: next to the team matches; Android: filesDir).
@MainActor
@Observable
public final class GameNotes {
    public static let shared = GameNotes()

    public private(set) var notes: [String: String] = [:]
    private var directory: URL? = nil
    /// The last save failed (shown under the editor)
    public private(set) var saveFailed = false

    public init() {
    }

    public func configure(directory: URL) {
        self.directory = directory
        notes = GameNoteFile.read(in: directory)
    }

    public func note(for gameId: UUID) -> String {
        notes[GameNoteFile.key(gameId)] ?? ""
    }

    /// Saves the note of a game; an empty text removes it
    public func set(_ text: String, for gameId: UUID) {
        var updated = notes
        updated[GameNoteFile.key(gameId)] = GameNoteFile.cleaned(text)
        notes = updated
        guard let directory else { return }
        do {
            try GameNoteFile.write(updated, in: directory)
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }

    /// After a restore wrote the file anew
    public func reload() {
        guard let directory else { return }
        notes = GameNoteFile.read(in: directory)
    }
}

/// Rally's won on the player's own serve and on the opponent's (backlog C4)
public struct ServiceReturnStats: Equatable, Sendable {
    public let served: Int
    public let wonOnServe: Int
    public let received: Int
    public let wonOnReturn: Int

    public init(served: Int, wonOnServe: Int, received: Int, wonOnReturn: Int) {
        self.served = served
        self.wonOnServe = wonOnServe
        self.received = received
        self.wonOnReturn = wonOnReturn
    }

    /// The rallies of `game` by who served them (`Point.server`)
    public static func of(_ game: Game, for player: Player) -> ServiceReturnStats {
        var served = 0
        var wonOnServe = 0
        var received = 0
        var wonOnReturn = 0
        for point in game.points {
            if point.server == player {
                served += 1
                if point.scorer == player { wonOnServe += 1 }
            } else {
                received += 1
                if point.scorer == player { wonOnReturn += 1 }
            }
        }
        return ServiceReturnStats(served: served, wonOnServe: wonOnServe, received: received, wonOnReturn: wonOnReturn)
    }

    /// 0...100, nil without rallies
    public static func percentage(_ won: Int, of total: Int) -> Int? {
        guard total > 0 else { return nil }
        return Int((Double(won) * 100.0 / Double(total)).rounded())
    }

    /// "7 van 10 gewonnen (70%)", or "Geen rally's" without any
    public static func line(_ won: Int, of total: Int) -> String {
        guard let percentage = percentage(won, of: total) else { return "Geen rally's" }
        return "\(won) van \(total) gewonnen (\(percentage)%)"
    }
}
