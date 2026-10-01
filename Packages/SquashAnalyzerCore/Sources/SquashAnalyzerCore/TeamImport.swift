import Foundation

// MARK: - Import format
//
// A zip file with `team.json` (at the top level or in one wrapping folder) and
// photos referenced relative to it:
//
//   team.zip
//   ├── team.json
//   └── photos/niels.jpg
//
//   { "team": "Squash Club 1",
//     "players": [ { "name": "Niels", "photo": "photos/niels.jpg", "focus": ["Backhand"], "notes": "" } ] }
//
// Only `name` is required. Shared by iOS and Android: the platforms unzip,
// download and scale photos; the rules (what is valid, which player is
// updated, the summary) live here. Format docs: docs/team-import/README.md.

public struct TeamImportFile: Codable, Sendable {
    public let team: String?
    public let players: [TeamImportPlayer]

    public init(team: String?, players: [TeamImportPlayer]) {
        self.team = team
        self.players = players
    }
}

public struct TeamImportPlayer: Codable, Sendable {
    public let name: String
    public let photo: String?
    public let focus: [String]?
    public let notes: String?

    public init(name: String, photo: String? = nil, focus: [String]? = nil, notes: String? = nil) {
        self.name = name
        self.photo = photo
        self.focus = focus
        self.notes = notes
    }
}

public enum TeamImportError: Error, Equatable {
    case missingTeamJSON
    case invalidTeamJSON
    case emptyName(index: Int)
    case unknownFocusTag(player: String, tag: String)
    case photoNotFound(player: String, path: String)
    case photoUnreadable(player: String, path: String)
    case invalidLink
    case notAZip
    case tooLarge
    case unavailable

    public var message: String {
        switch self {
        case .missingTeamJSON:
            return "Het zip-bestand bevat geen team.json."
        case .invalidTeamJSON:
            return "team.json kon niet worden gelezen. Controleer of het geldige JSON is met een lijst \"players\"."
        case .emptyName(let index):
            return "Speler \(index + 1) heeft geen naam."
        case .unknownFocusTag(let player, let tag):
            var allowed: [String] = []
            for focus in CoachingFocusTag.allCases {
                allowed.append(focus.rawValue)
            }
            return "Onbekend aandachtspunt '\(tag)' bij \(player). Toegestaan: \(allowed.joined(separator: ", "))."
        case .photoNotFound(let player, let path):
            return "Foto '\(path)' van \(player) zit niet in het zip-bestand."
        case .photoUnreadable(let player, let path):
            return "Foto '\(path)' van \(player) is geen bruikbare afbeelding."
        case .invalidLink:
            return "Gebruik een teamlink van squashanalyzer.com, zoals https://squashanalyzer.com/teams/…/team.zip."
        case .notAZip:
            return "Het bestand achter de link is geen team-zip."
        case .tooLarge:
            return "Het teambestand is te groot (meer dan 25 MB)."
        case .unavailable:
            return "Het team kon niet worden opgehaald. Controleer de link en je internetverbinding."
        }
    }
}

/// One checked player, ready to store: the photo is still a path inside the
/// zip, which the platform reads and scales (and reports with
/// `photoNotFound`/`photoUnreadable`)
public struct TeamImportEntry: Equatable, Sendable {
    public let name: String
    public let focus: [String]
    public let notes: String?
    public let photoPath: String?
}

public struct TeamImportResult: Equatable, Sendable {
    public var team: String?
    public var added: Int
    public var updated: Int
    public var photos: Int

    public init(team: String? = nil, added: Int = 0, updated: Int = 0, photos: Int = 0) {
        self.team = team
        self.added = added
        self.updated = updated
        self.photos = photos
    }

    public var summary: String {
        var parts = ["\(added) nieuw", "\(updated) bijgewerkt", "\(photos) foto's"]
        if let team, !team.isEmpty { parts.insert(team, at: 0) }
        return parts.joined(separator: " · ")
    }
}

public enum TeamImport {
    /// Largest team zip the app downloads or opens
    public static let maxBytes = 25_000_000

    /// The team.json to use among the zip's file paths: the shallowest one
    public static func teamJSONPath(in paths: [String]) -> String? {
        var best: String? = nil
        for path in paths where path == "team.json" || path.hasSuffix("/team.json") {
            if best == nil || path.count < best!.count { best = path }
        }
        return best
    }

    /// The folder photo paths are relative to ("" or "team/")
    public static func baseDirectory(ofTeamJSON path: String) -> String {
        String(path.dropLast("team.json".count))
    }

    public static func decode(_ data: Data) throws -> TeamImportFile {
        do {
            return try JSONDecoder().decode(TeamImportFile.self, from: data)
        } catch {
            throw TeamImportError.invalidTeamJSON
        }
    }

    /// Checks every player before anything is stored, so a bad entry never
    /// leaves a half-imported team. Focus tags are matched case-insensitively
    /// and stored with the app's spelling.
    public static func entries(of file: TeamImportFile) throws -> [TeamImportEntry] {
        var result: [TeamImportEntry] = []
        for (index, player) in file.players.enumerated() {
            let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { throw TeamImportError.emptyName(index: index) }
            var focus: [String] = []
            for raw in player.focus ?? [] {
                let wanted = raw.trimmingCharacters(in: .whitespaces).lowercased()
                var found: String? = nil
                for tag in CoachingFocusTag.allCases where tag.rawValue.lowercased() == wanted {
                    found = tag.rawValue
                }
                guard let tag = found else { throw TeamImportError.unknownFocusTag(player: name, tag: raw) }
                focus.append(tag)
            }
            let path = player.photo?.trimmingCharacters(in: .whitespaces) ?? ""
            result.append(TeamImportEntry(name: name, focus: focus, notes: player.notes, photoPath: path.isEmpty ? nil : path))
        }
        return result
    }

    /// The existing player an entry updates: same name, ignoring case and
    /// surrounding spaces; nil means a new player
    public static func matchIndex(for entry: TeamImportEntry, in existingNames: [String]) -> Int? {
        let wanted = entry.name.lowercased()
        for (index, name) in existingNames.enumerated()
        where name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == wanted {
            return index
        }
        return nil
    }

    /// A team link the app may download: only HTTPS zips under
    /// squashanalyzer.com/teams/, where Gerd-Jan publishes teams
    public static func link(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), host == "squashanalyzer.com" || host == "www.squashanalyzer.com" else { return nil }
        let path = url.path
        guard path.hasPrefix("/teams/"), path.lowercased().hasSuffix(".zip"), !path.contains("..") else { return nil }
        return url
    }

    /// Whether downloaded bytes start like a zip file ("PK")
    public static func looksLikeZip(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        // Compared as data: byte literals differ between Swift and Kotlin
        return data.subdata(in: 0..<2) == "PK".data(using: String.Encoding.utf8)!
    }
}

/// Downloads a team zip: URLSession on iOS, HttpURLConnection on Android
public protocol TeamDownloader: Sendable {
    func download(_ url: URL) async throws -> Data
}

/// Imports the team behind a squashanalyzer.com/teams link into the player
/// list; Android's Spelers screen gets one (download, unzip, photos, Room).
/// iOS has its own `TeamImportService` with SwiftData.
public protocol TeamLinkImporter: Sendable {
    func importTeam(link: String) async throws -> TeamImportResult
    /// A team zip picked from the phone's files
    func importTeam(zip: Data) async throws -> TeamImportResult
}
