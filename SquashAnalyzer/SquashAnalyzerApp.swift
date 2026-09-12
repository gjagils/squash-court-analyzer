import SwiftUI
import SwiftData

@main
struct SquashAnalyzerApp: App {
    let container: ModelContainer
    let persistenceWarning: String?

    init() {
        // Explicitly disable CloudKit sync: we use iCloud Drive only for file-based
        // backups (ExportService). Without this, SwiftData detects the iCloud entitlements
        // and tries to configure a CloudKit container that doesn't exist yet, causing a crash.
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView(startupPersistenceWarning: persistenceWarning)
        }
        .modelContainer(container)
    }
}
