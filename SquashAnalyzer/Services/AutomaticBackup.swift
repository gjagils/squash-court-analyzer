import Foundation
import SwiftData
import UIKit
import SquashAnalyzerCore

/// Weekly automatic backup to iCloud Drive, the iOS side of the automatic
/// backups Android writes into a chosen folder. Same rules (Core's
/// `AutoBackupPlan`): once a week, when the app goes to the background, so a
/// Friday evening's matches are in it; the iCloud folder keeps the newest 7
/// (`ExportService.writeBackup` rotates). On by default; skipped
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

    /// Called when the app goes to the background. The data is gathered on
    /// the main thread (SwiftData); finding the iCloud folder (which can take
    /// a moment) and writing the file happen off it, with a background task
    /// so iOS gives it time to finish.
    static func runIfDue(context: ModelContext, now: Date = Date()) {
        guard isEnabled, AutoBackupPlan.isDue(lastBackup: lastBackup, now: now) else { return }
        let data: Data
        do {
            data = try ExportService.exportFullBackup(
                players: try context.fetch(FetchDescriptor<SavedPlayer>()),
                matches: try context.fetch(FetchDescriptor<SavedMatch>()),
                standaloneGames: try context.fetch(FetchDescriptor<SavedGame>(predicate: #Predicate { $0.match == nil })),
                badgeAwards: try context.fetch(FetchDescriptor<SavedBadgeAward>()),
                refereeMatches: try context.fetch(FetchDescriptor<SavedRefereeMatch>())
            )
        } catch {
            return // tried again the next time
        }
        let application = UIApplication.shared
        var taskId = UIBackgroundTaskIdentifier.invalid
        taskId = application.beginBackgroundTask(withName: "Automatische back-up") {
            application.endBackgroundTask(taskId)
            taskId = .invalid
        }
        Task.detached(priority: .utility) {
            let written = ExportService.iCloudDirectory.flatMap { dir in try? ExportService.writeBackup(data, to: dir, now: now) } != nil
            await MainActor.run {
                // No iCloud Drive, or writing failed: tried again the next time
                if written { UserDefaults.standard.set(now, forKey: lastKey) }
                if taskId != .invalid { application.endBackgroundTask(taskId) }
            }
        }
    }
}
