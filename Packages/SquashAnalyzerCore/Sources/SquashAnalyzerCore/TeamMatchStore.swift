import Foundation

// MARK: - Opslag

/// Team matches on this phone, newest first
@MainActor
public protocol TeamMatchStore {
    func loadAll() async throws -> [TeamMatch]
    func save(_ match: TeamMatch) async throws
    func delete(id: UUID) async throws
}

/// What is wrong with the file of team matches
public enum TeamMatchFileError: Error, Equatable {
    /// The file could not be read; it was set aside under `savedAs` (in the
    /// same folder) so that nothing is lost and a new save starts clean
    case unreadable(savedAs: String)
}

/// The file holds `{"version": 1, "matches": [...]}`; the first builds wrote a
/// bare array, which is still read
struct TeamMatchEnvelope: Codable {
    var version: Int
    var matches: [TeamMatch]
}

/// The JSON file with all team matches, readable and writable without the
/// main actor (the backup code on iOS and Android needs it synchronously)
public enum TeamMatchFile {
    public static let fileName = "team-matches.json"
    public static let formatVersion = 1

    /// All matches; an absent file is an empty list. A file that cannot be
    /// decoded is moved aside and reported, never silently treated as empty:
    /// the next save would overwrite what is in it.
    public static func load(in directory: URL) throws -> [TeamMatch] {
        let url = directory.appendingPathComponent(TeamMatchFile.fileName)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var decoded: [TeamMatch]? = nil
        if let envelope = try? decoder.decode(TeamMatchEnvelope.self, from: data) {
            decoded = envelope.matches
        } else if let legacy = try? decoder.decode([TeamMatch].self, from: data) {
            decoded = legacy
        }
        guard let matches = decoded else {
            let aside = "team-matches.unreadable-\(Int(Date().timeIntervalSince1970)).json"
            try? FileManager.default.moveItem(at: url, to: directory.appendingPathComponent(aside))
            throw TeamMatchFileError.unreadable(savedAs: aside)
        }
        return matches.map { match in match.normalized() }
    }

    /// Like `load`, for code that cannot handle an error: an unreadable file
    /// is set aside and the list is empty
    public static func read(in directory: URL) -> [TeamMatch] {
        return (try? load(in: directory)) ?? []
    }

    /// Written in one go (`.atomic`): a kill halfway leaves the old file
    public static func write(_ matches: [TeamMatch], in directory: URL) throws {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(TeamMatchFile.fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(TeamMatchEnvelope(version: TeamMatchFile.formatVersion, matches: matches))
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    /// All matches, newest first
    public static func newestFirst(directory: URL) throws -> [TeamMatch] {
        return try load(in: directory).sorted(by: { a, b in a.date > b.date })
    }

    /// Replaces the match with the same id, or adds it
    public static func upsert(_ match: TeamMatch, directory: URL) throws {
        var all = try load(in: directory)
        var replaced = false
        for index in 0..<all.count where all[index].id == match.id {
            all[index] = match
            replaced = true
        }
        if !replaced { all.append(match) }
        try write(all, in: directory)
    }

    public static func remove(id: UUID, directory: URL) throws {
        let kept = try load(in: directory).filter { match in match.id != id }
        try write(kept, in: directory)
    }
}

/// One JSON file with all team matches, used on iOS (Application Support)
/// and Android (the app's files directory). Small and whole: every save
/// rewrites the file.
@MainActor
public final class JSONFileTeamMatchStore: TeamMatchStore {
    public static let fileName = TeamMatchFile.fileName
    private let directory: URL

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
    }

    public func loadAll() async throws -> [TeamMatch] {
        return try TeamMatchFile.newestFirst(directory: directory)
    }

    public func save(_ match: TeamMatch) async throws {
        try TeamMatchFile.upsert(match, directory: directory)
    }

    public func delete(id: UUID) async throws {
        try TeamMatchFile.remove(id: id, directory: directory)
    }
}
