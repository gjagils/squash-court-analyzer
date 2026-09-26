import SwiftUI
import SwiftData

@main
struct SquashAnalyzerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer
    let persistenceWarning: String?

    init() {
        // Explicitly disable SwiftData's CloudKit mirroring: the store stays local.
        // iCloud Drive holds the file backups (ExportService) and only shared player
        // cards go to CloudKit, through CardSync.
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
            let location = recoveryURL?.path ?? "de Application Support-map"
            persistenceWarning = "De lokale database kon niet worden geopend. De originele bestanden zijn behouden in \(location). Deze sessie gebruikt tijdelijke opslag; exporteer geen vervangende backup voordat de database is hersteld."
        }

        // Shared player cards (CloudKit); not in unit tests or screenshot runs
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #if DEBUG
        let isScreenshot = ScreenshotScenario.isActive
        #else
        let isScreenshot = false
        #endif
        if !isTesting && !isScreenshot && persistenceWarning == nil {
            CardSync.shared.start(modelContainer: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(startupPersistenceWarning: persistenceWarning)
        }
        .modelContainer(container)
    }
}
