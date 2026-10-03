import Foundation
import SwiftData
import SquashAnalyzerCore

/// Weekly automatic backup to iCloud Drive, the iOS side of the automatic
/// backups Android writes into a chosen folder. Same rules (Core's
/// `AutoBackupPlan`): once a week, when the app goes to the background, so a
/// Friday evening's matches are in it; the iCloud folder keeps the newest 7
/// (`ExportService.saveBackupToiCloud` rotates). On by default; skipped
/// quietly without iCloud Drive.
@MainActor
enum AutomaticBackup {
    static let enabledKey = "automaticICloudBackup"
    static let lastKey = "automaticICloudBackupLast"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var lastBackup: Date? {
        UserDefaults.standard.object(forKey: lastKey) as? Date
    }

    static func runIfDue(context: ModelContext, now: Date = Date()) {
        guard isEnabled, AutoBackupPlan.isDue(lastBackup: lastBackup, now: now) else { return }
        do {
            _ = try ExportService.saveBackupToiCloud(
                players: try context.fetch(FetchDescriptor<SavedPlayer>()),
                matches: try context.fetch(FetchDescriptor<SavedMatch>()),
                standaloneGames: try context.fetch(FetchDescriptor<SavedGame>(predicate: #Predicate { $0.match == nil })),
                badgeAwards: try context.fetch(FetchDescriptor<SavedBadgeAward>()),
                refereeMatches: try context.fetch(FetchDescriptor<SavedRefereeMatch>())
            )
            UserDefaults.standard.set(now, forKey: lastKey)
        } catch {
            // No iCloud Drive, or writing failed: tried again the next time
        }
    }
}
