import Foundation
import SwiftData

/// Version 1 is the explicit baseline for all future SwiftData migrations.
/// New model changes should introduce a new VersionedSchema and migration stage.
enum SquashAnalyzerSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SavedMatch.self,
            SavedGame.self,
            SavedPoint.self,
            SavedLet.self,
            SavedPlayer.self,
            SavedRefereeMatch.self
        ]
    }
}

enum SquashAnalyzerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SquashAnalyzerSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}

enum PersistenceRecovery {
    /// Copies the existing store files to a dated recovery folder. Originals are
    /// deliberately never deleted, even when opening or migration fails.
    static func preserveStoreFiles() -> URL? {
        let manager = FileManager.default
        guard let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let files = try? manager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) else {
            return nil
        }

        let storeFiles = files.filter {
            $0.pathExtension == "store" ||
            $0.lastPathComponent.hasSuffix(".store-shm") ||
            $0.lastPathComponent.hasSuffix(".store-wal")
        }
        guard !storeFiles.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let recoveryDirectory = appSupport
            .appendingPathComponent("Recovery", isDirectory: true)
            .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)

        do {
            try manager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
            for source in storeFiles {
                try manager.copyItem(at: source, to: recoveryDirectory.appendingPathComponent(source.lastPathComponent))
            }
            return recoveryDirectory
        } catch {
            return nil
        }
    }
}
