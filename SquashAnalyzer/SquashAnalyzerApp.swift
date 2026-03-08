import SwiftUI
import SwiftData

@main
struct SquashAnalyzerApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            SavedMatch.self,
            SavedGame.self,
            SavedPoint.self,
            SavedLet.self,
            SavedPlayer.self,
            SavedRefereeMatch.self
        ])
        // Explicitly disable CloudKit sync: we use iCloud Drive only for file-based
        // backups (ExportService). Without this, SwiftData detects the iCloud entitlements
        // and tries to configure a CloudKit container that doesn't exist yet, causing a crash.
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failed (e.g. after a TestFlight update with model changes).
            // Wipe the old store so the app remains functional, then recreate.
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeFiles = (try? FileManager.default.contentsOfDirectory(
                at: appSupport, includingPropertiesForKeys: nil
            ))?.filter {
                $0.pathExtension == "store"
                || $0.lastPathComponent.hasSuffix(".store-shm")
                || $0.lastPathComponent.hasSuffix(".store-wal")
            } ?? []
            storeFiles.forEach { try? FileManager.default.removeItem(at: $0) }
            // Force-unwrap: if this also fails something is fundamentally wrong
            container = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
