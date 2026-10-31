import SwiftUI
import SwiftData
import SquashAnalyzerCore
import SquashAnalyzerUI

@main
struct SquashAnalyzerApp: App {
    /// Instellingen → Taal ("" = the phone's language)
    @AppStorage(AppLanguage.storageKey) private var appLanguage = ""
    let container: ModelContainer
    let persistenceWarning: String?

    init() {
        // 4.0 behind a switch (docs/releaseplan-3x-4.0.md): only a 4.0 test build sets
        // SQUASH_PLAYER_ACCOUNT=YES, which Info.plist passes on
        Features.shared.playerAccount = Features.isOn(Bundle.main.infoDictionary?["SquashPlayerAccount"] as? String)
        // Live meekijken: the shared LiveShare sends the state through URLSession (server/live)
        LiveShare.shared.transport = URLSessionLiveTransport()
        // The anonymous daily usage count (AppUsage): only release builds report, so
        // the simulator, screenshots and tests never count
        AppUsage.shared.version = AppUsage.marketingVersion(from: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        #if !DEBUG
        AppUsage.shared.transport = URLSessionLiveTransport()
        #endif
        // Live score op het vergrendelscherm: Live Activities (followed matches and the own match)
        ActivityKitLiveFollowPresenter.shared.install()
        #if DEBUG
        LiveActivityDemo.runIfRequested()
        #endif
        // "Deel als plaatje" in the shared share screen
        IOSShare.installResultImageSharing()
        // The coach's notes per game live next to the team matches (GameNotes)
        GameNotes.shared.configure(directory: TeamMatchStorage.directory)
        // Explicitly disable SwiftData's CloudKit mirroring: the store stays local.
        // iCloud Drive holds the file backups (ExportService); player cards are
        // shared as links (CardSnapshot), not through CloudKit.
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: SquashAnalyzerMigrationPlan.self,
                configurations: [config]
            )
            persistenceWarning = nil
        } catch {
            let recoveryURL = PersistenceRecovery.preserveStoreFiles()
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                container = try ModelContainer(
                    for: schema,
                    migrationPlan: SquashAnalyzerMigrationPlan.self,
                    configurations: [memoryConfig]
                )
            } catch {
                fatalError("Ook de veilige tijdelijke opslag kon niet worden gestart: \(error)")
            }
            let location = recoveryURL?.path ?? appText("de Application Support-map")
            persistenceWarning = appText("De lokale database kon niet worden geopend. De originele bestanden zijn behouden in \(location). Deze sessie gebruikt tijdelijke opslag; exporteer geen vervangende backup voordat de database is hersteld.")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(startupPersistenceWarning: persistenceWarning)
                .appAppearance()
                // A new choice in Instellingen → Taal draws every screen anew in that language
                .id(appLanguage)
        }
        .modelContainer(container)
    }
}
