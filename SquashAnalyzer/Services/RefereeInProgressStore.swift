import Foundation
import SquashAnalyzerCore

/// The referee match being played, kept as a file (Core's
/// RefereeMatchSnapshot) after every change, so "Sluiten" halfway or closing
/// the app can be resumed, as on Android. Finished matches go to SwiftData as
/// before (`SavedRefereeMatch`); then this file is removed.
enum RefereeInProgressStore {
    private static var url: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("referee-in-progress.json")
    }

    static func save(_ match: RefereeMatch) {
        guard let data = try? JSONEncoder().encode(match.snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> RefereeMatch? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(RefereeMatchSnapshot.self, from: data) else { return nil }
        return RefereeMatch.restoring(snapshot)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
