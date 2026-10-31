import Foundation

// Oefenpartij (backlog C8, 3.1): a coach or referee match marked in the setup
// as practice. It is kept and can be opened like any match, but earns no badges
// (match or career), does not count in a player's profile and trend, and is
// left out of the career history of the other matches. Kept as a list of match
// ids in a JSON file next to the team matches, like the game notes, so no
// SwiftData or Room migration is needed; the full backup carries it
// (`FullBackup.practiceMatchIds`).

/// The file: `{"version": 1, "ids": ["…", …]}` (upper-case UUID strings, sorted)
public enum PracticeMatchFile {
    public static let fileName = "practice-matches.json"
    public static let formatVersion = 1

    struct Envelope: Codable {
        var version: Int
        var ids: [String]
    }

    /// The ids in the file; empty when there is no file or it cannot be read
    public static func read(in directory: URL) -> [String] {
        let url = directory.appendingPathComponent(PracticeMatchFile.fileName)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return [] }
        return envelope.ids
    }

    /// Written in one go (`.atomic`), sorted and without duplicates
    public static func write(_ ids: [String], in directory: URL) throws {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(PracticeMatchFile.fileName)
        var unique: [String] = []
        for id in ids where !unique.contains(id) { unique.append(id) }
        unique.sort()
        let data = try JSONEncoder().encode(Envelope(version: PracticeMatchFile.formatVersion, ids: unique))
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    static func key(_ id: UUID) -> String { id.uuidString.uppercased() }
}

/// Which matches are practice. The app sets the folder at start (iOS: next to
/// the team matches; Android: the same folder as the game notes). Read by the
/// badge rules and the trend, possibly off the main thread; written only from
/// the setup and a restore, so a plain value behind a class is enough.
public final class PracticeMatches: @unchecked Sendable {
    public static let shared = PracticeMatches()

    private var ids: [String] = []
    private var directory: URL? = nil

    public init() {}

    public func configure(directory: URL) {
        self.directory = directory
        ids = PracticeMatchFile.read(in: directory)
    }

    public func contains(_ id: UUID) -> Bool { ids.contains(PracticeMatchFile.key(id)) }

    /// For ids kept as text (history entries, award match ids)
    public func contains(id: String) -> Bool { ids.contains(id.uppercased()) }

    /// Marks a match as practice (or not). Saved at once; a failed save keeps the mark for this run.
    public func set(_ practice: Bool, for id: UUID) {
        let key = PracticeMatchFile.key(id)
        var updated = ids.filter { existing in existing != key }
        if practice { updated.append(key) }
        ids = updated
        guard let directory else { return }
        try? PracticeMatchFile.write(updated, in: directory)
    }

    /// After a restore wrote the file anew
    public func reload() {
        guard let directory else { return }
        ids = PracticeMatchFile.read(in: directory)
    }
}
