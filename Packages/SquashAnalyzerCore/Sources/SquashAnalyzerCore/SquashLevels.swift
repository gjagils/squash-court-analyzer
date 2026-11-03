import Foundation

// MARK: - SquashLevels-profiel (3.2, docs/plan-squashlevels-profiel.md)

/// A saved player's SquashLevels player id, opened in the browser with one
/// tap. The app keeps only the id: it never fetches SquashLevels pages
/// (robots.txt excludes the player pages for scripts) and keeps no levels or
/// rankings. The link that opens is the SBN ranking with the player
/// highlighted, the form Gerd-Jan copied from his browser on 3 November 2026:
/// `https://sbn.squashlevels.com/speelsterkte_ranking?all&page=sbn_rankings&country=8&highlight=286855&show=last10`.
public enum SquashLevels {
    static let hosts = ["sbn.squashlevels.com", "www.squashlevels.com", "squashlevels.com"]

    /// The player id from what was typed or pasted: a bare id ("286855"), or an
    /// https link on a SquashLevels host with `highlight=` or `player=`. Nil for
    /// anything else (another host, http, a port, a login in the link, no id).
    public static func playerId(from typed: String) -> String? {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if isId(text) { return text }
        // A login in the link ("me:pw@host") is never a profile link
        if text.contains("@") { return nil }
        guard let url = URL(string: text), url.scheme == "https", let host = url.host?.lowercased(),
              hosts.contains(host), url.port == nil,
              let query = url.query else { return nil }
        for part in query.components(separatedBy: "&") {
            let pair = part.components(separatedBy: "=")
            if pair.count == 2 && (pair[0] == "highlight" || pair[0] == "player") && isId(pair[1]) { return pair[1] }
        }
        return nil
    }

    /// The page that opens: the SBN ranking with this player highlighted
    public static func url(forPlayerId id: String) -> URL? {
        guard isId(id) else { return nil }
        return URL(string: "https://sbn.squashlevels.com/speelsterkte_ranking?all&page=sbn_rankings&country=8&highlight=" + id + "&show=last10")
    }

    /// Digits only, 1 to 10 of them
    static func isId(_ text: String) -> Bool {
        if text.isEmpty { return false }
        var count = 0
        for character in text {
            if !"0123456789".contains(character) { return false }
            count += 1
        }
        return count <= 10
    }
}

/// One saved player and their SquashLevels id
public struct SquashLevelsLink: Codable, Equatable, Sendable {
    public var playerId: String
    public var levelsId: String

    public init(playerId: String, levelsId: String) {
        self.playerId = playerId
        self.levelsId = levelsId
    }
}

/// The file next to the team matches: `{"version": 1, "links": [{"playerId": "…", "levelsId": "286855"}]}`.
/// Not in SwiftData or Room (schema V7 stays frozen); the full backup carries it
/// (`FullBackup.squashLevelsLinks`).
public enum SquashLevelsFile {
    public static let fileName = "squashlevels.json"
    public static let formatVersion = 1

    struct Envelope: Codable {
        var version: Int
        var links: [SquashLevelsLink]
    }

    public static func read(in directory: URL) -> [SquashLevelsLink] {
        let url = directory.appendingPathComponent(SquashLevelsFile.fileName)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return [] }
        return envelope.links
    }

    public static func write(_ links: [SquashLevelsLink], in directory: URL) throws {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(SquashLevelsFile.fileName)
        let data = try JSONEncoder().encode(Envelope(version: SquashLevelsFile.formatVersion, links: links))
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }

    /// `links` with this player's id set (nil or empty: the link removed)
    public static func setting(_ levelsId: String?, forPlayer playerId: String, in links: [SquashLevelsLink]) -> [SquashLevelsLink] {
        var result: [SquashLevelsLink] = []
        for link in links where link.playerId != playerId { result.append(link) }
        if let levelsId, !levelsId.isEmpty { result.append(SquashLevelsLink(playerId: playerId, levelsId: levelsId)) }
        return result
    }

    /// Merging keeps a link this phone already has for a player; replacing takes the file's
    public static func merged(_ incoming: [SquashLevelsLink], into current: [SquashLevelsLink], replacing: Bool) -> [SquashLevelsLink] {
        if replacing { return incoming }
        var result = current
        for link in incoming {
            var known = false
            for existing in result where existing.playerId == link.playerId { known = true }
            if !known { result.append(link) }
        }
        return result
    }
}

/// The links of this phone. The app sets the folder at start, next to the team
/// matches (as `PracticeMatches`). Saving throws, so the editor can say it failed.
public final class SquashLevelsLinks: @unchecked Sendable {
    public static let shared = SquashLevelsLinks()

    private var links: [SquashLevelsLink] = []
    private var directory: URL? = nil

    public init() {}

    public func configure(directory: URL) {
        self.directory = directory
        links = SquashLevelsFile.read(in: directory)
    }

    public func levelsId(forPlayer playerId: String) -> String? {
        for link in links where link.playerId == playerId { return link.levelsId }
        return nil
    }

    public func set(_ levelsId: String?, forPlayer playerId: String) throws {
        let updated = SquashLevelsFile.setting(levelsId, forPlayer: playerId, in: links)
        if let directory { try SquashLevelsFile.write(updated, in: directory) }
        links = updated
    }

    /// After a restore wrote the file anew
    public func reload() {
        guard let directory else { return }
        links = SquashLevelsFile.read(in: directory)
    }
}
