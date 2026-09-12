import Foundation
import SwiftData

// MARK: - Import format
//
// A zip file with `team.json` at the top level and photos referenced relative to it:
//
//   team.zip
//   ├── team.json
//   └── photos/niels.jpg
//
//   {
//     "team": "Squash Club 1",
//     "players": [
//       { "name": "Niels", "photo": "photos/niels.jpg", "focus": ["Backhand"], "notes": "" },
//       { "name": "Paul",  "photo": "photos/paul.jpg" }
//     ]
//   }
//
// Only `name` is required. Existing players are matched by name (case-insensitive)
// and updated; photos are cropped square and scaled to 512px.

struct TeamImportFile: Decodable {
    let team: String?
    let players: [TeamImportPlayer]
}

struct TeamImportPlayer: Decodable {
    let name: String
    let photo: String?
    let focus: [String]?
    let notes: String?
}

struct TeamImportResult {
    var team: String?
    var added = 0
    var updated = 0
    var photos = 0

    var summary: String {
        var parts = ["\(added) nieuw", "\(updated) bijgewerkt", "\(photos) foto's"]
        if let team, !team.isEmpty { parts.insert(team, at: 0) }
        return parts.joined(separator: " · ")
    }
}

enum TeamImportError: LocalizedError {
    case missingTeamJSON
    case invalidTeamJSON(String)
    case emptyName(index: Int)
    case unknownFocusTag(player: String, tag: String)
    case photoNotFound(player: String, path: String)
    case photoUnreadable(player: String, path: String)

    var errorDescription: String? {
        switch self {
        case .missingTeamJSON:
            return "Het zip-bestand bevat geen team.json."
        case .invalidTeamJSON(let detail):
            return "team.json kon niet worden gelezen: \(detail)"
        case .emptyName(let index):
            return "Speler \(index + 1) heeft geen naam."
        case .unknownFocusTag(let player, let tag):
            let allowed = CoachingFocusTag.allCases.map(\.rawValue).joined(separator: ", ")
            return "Onbekend aandachtspunt '\(tag)' bij \(player). Toegestaan: \(allowed)."
        case .photoNotFound(let player, let path):
            return "Foto '\(path)' van \(player) zit niet in het zip-bestand."
        case .photoUnreadable(let player, let path):
            return "Foto '\(path)' van \(player) is geen bruikbare afbeelding."
        }
    }
}

enum TeamImportService {
    /// Validates the whole file before touching the database, then adds or updates players.
    @MainActor
    static func importTeam(zipData: Data, context: ModelContext) throws -> TeamImportResult {
        let archive = try ZipArchive(data: zipData)
        let (file, baseDirectory) = try decodeTeamFile(from: archive)

        // Resolve and validate everything first so a bad entry never leaves a half-imported team.
        var prepared: [(player: TeamImportPlayer, name: String, focus: [String], photo: Data?)] = []
        for (index, player) in file.players.enumerated() {
            let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw TeamImportError.emptyName(index: index) }

            let focus = try (player.focus ?? []).map { raw -> String in
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                guard let tag = CoachingFocusTag.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
                    throw TeamImportError.unknownFocusTag(player: name, tag: raw)
                }
                return tag.rawValue
            }

            var photo: Data? = nil
            if let path = player.photo?.trimmingCharacters(in: .whitespaces), !path.isEmpty {
                guard let entry = archive.entry(named: baseDirectory + path) ?? archive.entry(named: path) else {
                    throw TeamImportError.photoNotFound(player: name, path: path)
                }
                guard let normalized = PlayerPhoto.normalized(try archive.contents(of: entry)) else {
                    throw TeamImportError.photoUnreadable(player: name, path: path)
                }
                photo = normalized
            }
            prepared.append((player, name, focus, photo))
        }

        let existing = try context.fetch(FetchDescriptor<SavedPlayer>())
        var result = TeamImportResult(team: file.team)

        for item in prepared {
            if let match = existing.first(where: { $0.name.caseInsensitiveCompare(item.name) == .orderedSame }) {
                if !item.focus.isEmpty { match.coachingFocusAreas = item.focus }
                if let notes = item.player.notes { match.coachingNotes = notes }
                if let photo = item.photo { match.photoData = photo }
                result.updated += 1
            } else {
                context.insert(SavedPlayer(
                    name: item.name,
                    coachingFocusAreas: item.focus,
                    coachingNotes: item.player.notes ?? "",
                    photoData: item.photo
                ))
                result.added += 1
            }
            if item.photo != nil { result.photos += 1 }
        }

        try context.save()
        return result
    }

    /// Returns the decoded file plus the folder prefix photos are relative to. team.json may sit
    /// at the top level or inside one wrapping folder (Finder zips a folder that way).
    private static func decodeTeamFile(from archive: ZipArchive) throws -> (TeamImportFile, String) {
        let candidates = archive.fileEntries.filter { $0.path.hasSuffix("team.json") }
            .sorted { $0.path.count < $1.path.count }
        guard let entry = candidates.first else { throw TeamImportError.missingTeamJSON }
        let baseDirectory = String(entry.path.dropLast("team.json".count))
        do {
            let file = try JSONDecoder().decode(TeamImportFile.self, from: try archive.contents(of: entry))
            return (file, baseDirectory)
        } catch let error as TeamImportError {
            throw error
        } catch {
            throw TeamImportError.invalidTeamJSON(error.localizedDescription)
        }
    }
}
