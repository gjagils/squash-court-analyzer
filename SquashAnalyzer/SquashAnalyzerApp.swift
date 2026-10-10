import SwiftUI
import SwiftData
import SquashAnalyzerCore
import SquashAnalyzerUI

@main
struct SquashAnalyzerApp: App {
    let container: ModelContainer
    let persistenceWarning: String?

    init() {
        // Live meekijken: the shared LiveShare sends the state through URLSession (server/live)
        LiveShare.shared.transport = URLSessionLiveTransport()
        // "Deel als plaatje" in the shared share screen
        IOSShare.installResultImageSharing()
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
            let location = recoveryURL?.path ?? "de Application Support-map"
            persistenceWarning = "De lokale database kon niet worden geopend. De originele bestanden zijn behouden in \(location). Deze sessie gebruikt tijdelijke opslag; exporteer geen vervangende backup voordat de database is hersteld."
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(startupPersistenceWarning: persistenceWarning)
                .appAppearance()
        }
        .modelContainer(container)
    }
}
