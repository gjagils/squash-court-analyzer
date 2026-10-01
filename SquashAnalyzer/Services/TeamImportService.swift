import Foundation
import SquashAnalyzerCore
import SwiftData

// The format, the checks and the summary are shared with Android
// (SquashAnalyzerCore's `TeamImport`); this file unzips, scales the photos
// (`PlayerPhoto`) and writes SwiftData. Format: docs/team-import/README.md.

extension TeamImportError: @retroactive LocalizedError {
    public var errorDescription: String? { message }
}

/// Downloads a team zip from squashanalyzer.com/teams (Android: HttpTeamDownloader)
struct URLSessionTeamDownloader: TeamDownloader {
    func download(_ url: URL) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        let (data, response) = try await URLSession(configuration: config).data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw TeamImportError.unavailable }
        guard data.count <= TeamImport.maxBytes else { throw TeamImportError.tooLarge }
        guard TeamImport.looksLikeZip(data) else { throw TeamImportError.notAZip }
        return data
    }
}

enum TeamImportService {
    /// Downloads the team behind a squashanalyzer.com/teams link and imports it
    @MainActor
    static func importTeam(link text: String, context: ModelContext,
                           downloader: any TeamDownloader = URLSessionTeamDownloader()) async throws -> TeamImportResult {
        guard let url = TeamImport.link(from: text) else { throw TeamImportError.invalidLink }
        let data: Data
        do {
            data = try await downloader.download(url)
        } catch let error as TeamImportError {
            throw error
        } catch {
            throw TeamImportError.unavailable
        }
        return try importTeam(zipData: data, context: context)
    }

    /// Validates the whole file before touching the database, then adds or updates players.
    @MainActor
    static func importTeam(zipData: Data, context: ModelContext) throws -> TeamImportResult {
        let archive = try ZipArchive(data: zipData)
        guard let jsonPath = TeamImport.teamJSONPath(in: archive.fileEntries.map(\.path)),
              let jsonEntry = archive.entry(named: jsonPath) else { throw TeamImportError.missingTeamJSON }
        let file = try TeamImport.decode(try archive.contents(of: jsonEntry))
        let baseDirectory = TeamImport.baseDirectory(ofTeamJSON: jsonPath)

        // Check every player and photo first so a bad entry never leaves a half-imported team.
        var prepared: [(entry: TeamImportEntry, photo: Data?)] = []
        for entry in try TeamImport.entries(of: file) {
            var photo: Data? = nil
            if let path = entry.photoPath {
                guard let photoEntry = archive.entry(named: baseDirectory + path) ?? archive.entry(named: path) else {
                    throw TeamImportError.photoNotFound(player: entry.name, path: path)
                }
                guard let normalized = PlayerPhoto.normalized(try archive.contents(of: photoEntry)) else {
                    throw TeamImportError.photoUnreadable(player: entry.name, path: path)
                }
                photo = normalized
            }
            prepared.append((entry, photo))
        }

        let existing = try context.fetch(FetchDescriptor<SavedPlayer>())
        var result = TeamImportResult(team: file.team)
        for item in prepared {
            if let index = TeamImport.matchIndex(for: item.entry, in: existing.map(\.name)) {
                let match = existing[index]
                if !item.entry.focus.isEmpty { match.coachingFocusAreas = item.entry.focus }
                if let notes = item.entry.notes { match.coachingNotes = notes }
                if let photo = item.photo { match.photoData = photo }
                result.updated += 1
            } else {
                context.insert(SavedPlayer(
                    name: item.entry.name,
                    coachingFocusAreas: item.entry.focus,
                    coachingNotes: item.entry.notes ?? "",
                    photoData: item.photo
                ))
                result.added += 1
            }
            if item.photo != nil { result.photos += 1 }
        }

        try context.save()
        return result
    }
}
