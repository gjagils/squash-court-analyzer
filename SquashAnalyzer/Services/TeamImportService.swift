import Foundation
import SquashAnalyzerCore
import SquashAnalyzerUI
import SwiftData

// The format, the checks and the summary are shared with Android
// (SquashAnalyzerCore's `TeamImport`); this file unzips, scales the photos
// (`PlayerPhoto`) and writes SwiftData. Since 3.1 build 5 only for the sample
// players and the screenshot scenarios: the Team button and the
// squashanalyzer.com/teams links are gone (backlog S3). Format:
// docs/archief/team-import/README.md.

extension TeamImportError: @retroactive LocalizedError {
    public var errorDescription: String? { message }
}

enum TeamImportService {
    /// Bob and Wim for everyone (SquashAnalyzerUI's SamplePlayers): once per
    /// install, also next to existing players, which they never change (a real
    /// "Wim" keeps his photo). Not during tests.
    @MainActor
    static func addSamplePlayersIfNew(context: ModelContext) {
        guard SamplePlayers.isPending,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        defer { SamplePlayers.markDone() }
        guard let data = SamplePlayers.zipData() else { return }
        _ = try? importTeam(zipData: data, context: context, addOnly: true)
    }

    /// Validates the whole file before touching the database, then adds or updates players.
    /// With `addOnly` a player whose name already exists is left as it is.
    @MainActor
    static func importTeam(zipData: Data, context: ModelContext, addOnly: Bool = false) throws -> TeamImportResult {
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
                if addOnly { continue }
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
