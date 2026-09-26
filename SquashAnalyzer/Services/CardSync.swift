import Foundation
import CloudKit
import SwiftData
import os

/// A card that arrived from outside (an accepted CloudKit share or a snapshot
/// link) and waits for the coach to link it to a local player.
struct PendingCard: Identifiable {
    enum Source {
        case snapshot
        case share(zoneOwnerName: String, shareURL: String?)
    }

    let id = UUID()
    let cardId: UUID
    let name: String
    let awards: [AwardValue]
    let source: Source
}

/// Shared player cards in CloudKit. Each shared card is one record zone
/// (`card-<cardId>`) holding a `PlayerCard` record ("card") and one
/// `BadgeAward` record per award (record name = award id). The owner's zone
/// lives in their private database and is shared as a whole with a CKShare that
/// anyone with the link may join; joined cards come in through the shared
/// database. Two `CKSyncEngine`s keep them in sync. Only cards that were shared
/// or joined go to iCloud; every other player's badges stay on the device.
@MainActor
@Observable
final class CardSync {
    static let shared = CardSync()
    static let containerIdentifier = "iCloud.com.squashanalyzer.app"
    static let cardRecordName = "card"

    /// Card waiting to be linked (drives the import sheet)
    var inbox: PendingCard?
    /// Last CloudKit problem worth telling the coach about
    var lastError: String?

    private var modelContainer: ModelContainer?
    private var privateEngine: CKSyncEngine?
    private var sharedEngine: CKSyncEngine?
    private var delegates: [EngineDelegate] = []
    private let log = Logger(subsystem: "com.squashanalyzer.app", category: "CardSync")

    private var cloudContainer: CKContainer { CKContainer(identifier: Self.containerIdentifier) }
    private var context: ModelContext? { modelContainer?.mainContext }

    // MARK: - Lifecycle

    func start(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let hasCards = ((try? modelContainer.mainContext.fetchCount(FetchDescriptor<SavedPlayerCard>())) ?? 0) > 0
        if hasCards { startEngines() }
    }

    private func startEngines() {
        guard privateEngine == nil, modelContainer != nil else { return }
        let privateDelegate = EngineDelegate(scope: .private)
        let sharedDelegate = EngineDelegate(scope: .shared)
        delegates = [privateDelegate, sharedDelegate]
        privateEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: cloudContainer.privateCloudDatabase,
            stateSerialization: Self.loadState(.private),
            delegate: privateDelegate))
        sharedEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: cloudContainer.sharedCloudDatabase,
            stateSerialization: Self.loadState(.shared),
            delegate: sharedDelegate))
    }

    func fetchChanges() async {
        for engine in [privateEngine, sharedEngine].compactMap({ $0 }) {
            try? await engine.fetchChanges()
        }
    }

    // MARK: - Zones and records

    static func zoneID(for card: SavedPlayerCard) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "card-\(card.cardId.uuidString)",
                        ownerName: card.isOwner ? CKCurrentUserDefaultName : card.zoneOwnerName)
    }

    static func cardId(from zoneID: CKRecordZone.ID) -> UUID? {
        guard zoneID.zoneName.hasPrefix("card-") else { return nil }
        return UUID(uuidString: String(zoneID.zoneName.dropFirst(5)))
    }

    private func engine(for card: SavedPlayerCard) -> CKSyncEngine? {
        card.isOwner ? privateEngine : sharedEngine
    }

    private func cloudCard(_ cardId: UUID) -> SavedPlayerCard? {
        guard let context else { return nil }
        return try? CardStore(context: context).card(cardId)
    }

    // MARK: - Local changes → CloudKit

    /// Queues awards that were added or changed locally for the cards in CloudKit
    func awardsChanged(_ awards: [SavedBadgeAward]) {
        guard context != nil else { return }
        for award in awards {
            guard let card = cloudCard(award.cardId), let engine = engine(for: card) else { continue }
            let recordID = CKRecord.ID(recordName: award.id.uuidString, zoneID: Self.zoneID(for: card))
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        }
    }

    /// Queues the removal of awards that were never really earned (an undone rally, a discarded match)
    func awardsRemoved(_ awards: [(id: UUID, cardId: UUID)]) {
        guard context != nil else { return }
        for award in awards {
            guard let card = cloudCard(award.cardId), let engine = engine(for: card) else { continue }
            let recordID = CKRecord.ID(recordName: award.id.uuidString, zoneID: Self.zoneID(for: card))
            engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
        }
    }

    /// The record the engine should send for a pending change; nil drops the change
    fileprivate func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let context, let cardId = Self.cardId(from: recordID.zoneID), let card = cloudCard(cardId) else { return nil }
        if recordID.recordName == Self.cardRecordName {
            let record = Self.makeRecord(type: "PlayerCard", id: recordID, systemFields: card.systemFields)
            record["name"] = card.name
            return record
        }
        guard let awardId = UUID(uuidString: recordID.recordName) else { return nil }
        var descriptor = FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.id == awardId })
        descriptor.fetchLimit = 1
        guard let award = try? context.fetch(descriptor).first else { return nil }
        return Self.awardRecord(award, zoneID: recordID.zoneID)
    }

    static func awardRecord(_ award: SavedBadgeAward, zoneID: CKRecordZone.ID) -> CKRecord {
        let id = CKRecord.ID(recordName: award.id.uuidString, zoneID: zoneID)
        let record = makeRecord(type: "BadgeAward", id: id, systemFields: award.cloudSystemFields)
        record["cardId"] = award.cardId.uuidString
        record["badge"] = award.badge
        record["matchId"] = award.matchId.uuidString
        record["earnedAt"] = award.earnedAt
        record["opponentName"] = award.opponentName
        record["awardedBy"] = award.awardedBy
        record["deletedAt"] = award.deletedAt
        return record
    }

    static func makeRecord(type: CKRecord.RecordType, id: CKRecord.ID, systemFields: Data?) -> CKRecord {
        if let systemFields, let coder = try? NSKeyedUnarchiver(forReadingFrom: systemFields) {
            coder.requiresSecureCoding = true
            let record = CKRecord(coder: coder)
            coder.finishDecoding()
            if let record, record.recordID == id { return record }
        }
        return CKRecord(recordType: type, recordID: id)
    }

    static func systemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    // MARK: - CloudKit → local

    /// Merges a record from CloudKit into the store. A local deletion that the
    /// server does not know yet is sent back.
    private func apply(_ record: CKRecord) {
        guard let context, let cardId = Self.cardId(from: record.recordID.zoneID) else { return }
        if record.recordType == "PlayerCard" {
            if let card = cloudCard(cardId) {
                card.name = record["name"] as? String ?? card.name
                card.systemFields = Self.systemFields(of: record)
            }
            return
        }
        guard record.recordType == "BadgeAward",
              let badge = (record["badge"] as? String).flatMap(BadgeKind.init(rawValue:)),
              let matchId = (record["matchId"] as? String).flatMap(UUID.init(uuidString:)) else { return }
        let value = AwardValue(cardId: cardId, badge: badge, matchId: matchId,
                               earnedAt: record["earnedAt"] as? Date ?? Date(),
                               opponentName: record["opponentName"] as? String ?? "",
                               awardedBy: record["awardedBy"] as? String ?? "",
                               deletedAt: record["deletedAt"] as? Date)
        let store = CardStore(context: context)
        _ = try? store.merge([value])
        let awardId = value.id
        var descriptor = FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.id == awardId })
        descriptor.fetchLimit = 1
        if let local = try? context.fetch(descriptor).first {
            local.cloudSystemFields = Self.systemFields(of: record)
            if local.deletedAt != nil, value.deletedAt == nil {
                awardsChanged([local])
            }
        }
    }

    fileprivate func handle(_ event: CKSyncEngine.Event, scope: CKDatabase.Scope) {
        guard let context else { return }
        switch event {
        case .stateUpdate(let update):
            Self.saveState(update.stateSerialization, scope: scope)

        case .accountChange(let change):
            switch change.changeType {
            case .signIn: break
            case .signOut, .switchAccounts: forgetCloudState()
            @unknown default: break
            }

        case .fetchedDatabaseChanges(let changes):
            // A zone that disappeared: the owner stopped sharing, or this device left the card
            for deletion in changes.deletions {
                if let cardId = Self.cardId(from: deletion.zoneID), let card = cloudCard(cardId) {
                    context.delete(card)
                }
            }
            try? context.save()

        case .fetchedRecordZoneChanges(let changes):
            changes.modifications.forEach { apply($0.record) }
            try? context.save()

        case .sentRecordZoneChanges(let sent):
            sent.savedRecords.forEach { apply($0) }
            for failure in sent.failedRecordSaves {
                let recordID = failure.record.recordID
                switch failure.error.code {
                case .serverRecordChanged:
                    if let server = failure.error.serverRecord { apply(server) }
                    engineForScope(scope)?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                case .zoneNotFound:
                    if scope == .private {
                        privateEngine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: recordID.zoneID))])
                        privateEngine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    }
                case .unknownItem:
                    clearSystemFields(of: recordID)
                    engineForScope(scope)?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                     .notAuthenticated, .operationCancelled, .requestRateLimited:
                    break   // the engine retries these itself
                default:
                    log.error("Saving \(recordID.recordName) failed: \(failure.error.localizedDescription)")
                    lastError = failure.error.localizedDescription
                }
            }
            try? context.save()

        default:
            break
        }
    }

    private func engineForScope(_ scope: CKDatabase.Scope) -> CKSyncEngine? {
        scope == .private ? privateEngine : sharedEngine
    }

    fileprivate func nextBatch(_ syncContext: CKSyncEngine.SendChangesContext, engine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = engine.state.pendingRecordZoneChanges.filter { syncContext.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await MainActor.run { CardSync.shared.record(for: recordID) }
        }
    }

    private func clearSystemFields(of recordID: CKRecord.ID) {
        guard let context, let awardId = UUID(uuidString: recordID.recordName) else { return }
        var descriptor = FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.id == awardId })
        descriptor.fetchLimit = 1
        (try? context.fetch(descriptor).first)?.cloudSystemFields = nil
    }

    /// Another iCloud account: the cards belong to the old one. Local badges stay.
    private func forgetCloudState() {
        guard let context else { return }
        try? context.delete(model: SavedPlayerCard.self)
        for award in (try? context.fetch(FetchDescriptor<SavedBadgeAward>())) ?? [] {
            award.cloudSystemFields = nil
        }
        try? context.save()
        for scope in [CKDatabase.Scope.private, .shared] {
            UserDefaults.standard.removeObject(forKey: Self.stateKey(scope))
        }
    }

    // MARK: - Sharing a card (owner)

    /// Puts the player's card in iCloud (first time only) and returns the
    /// invitation link. For a joined card this is the link it was shared with.
    func invitationURL(for player: SavedPlayer) async throws -> URL {
        guard let context else { throw CardLinkError.notShared }
        let cardId = player.badgeCardId
        if let card = cloudCard(cardId) {
            if let url = card.shareURL.flatMap(URL.init(string:)) { return url }
            if !card.isOwner { throw CardLinkError.notShared }
        }
        guard try await cloudContainer.accountStatus() == .available else { throw CardLinkError.noICloud }

        let database = cloudContainer.privateCloudDatabase
        let zone = CKRecordZone(zoneName: "card-\(cardId.uuidString)")
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])

        let share = CKShare(recordZoneID: zone.zoneID)
        share[CKShare.SystemFieldKey.title] = "Badgekaart \(player.name)"
        share.publicPermission = .readWrite

        let cardRecord = CKRecord(recordType: "PlayerCard", recordID: CKRecord.ID(recordName: Self.cardRecordName, zoneID: zone.zoneID))
        cardRecord["name"] = player.name
        let awards = try CardStore(context: context).awards(onCard: cardId)
        let awardRecords = awards.map { Self.awardRecord($0, zoneID: zone.zoneID) }

        let (saveResults, _) = try await database.modifyRecords(saving: [share, cardRecord] + awardRecords, deleting: [],
                                                                savePolicy: .changedKeys)
        var shareURL: URL?
        for (_, result) in saveResults {
            guard case .success(let saved) = result else { continue }
            if let savedShare = saved as? CKShare {
                shareURL = savedShare.url
            } else if let awardId = UUID(uuidString: saved.recordID.recordName),
                      let award = awards.first(where: { $0.id == awardId }) {
                award.cloudSystemFields = Self.systemFields(of: saved)
            }
        }
        if case .failure(let error) = saveResults[share.recordID] { throw error }
        guard let shareURL else { throw CardLinkError.notShared }

        let card = cloudCard(cardId) ?? {
            let card = SavedPlayerCard(cardId: cardId, name: player.name, isOwner: true, zoneOwnerName: CKCurrentUserDefaultName)
            context.insert(card)
            return card
        }()
        card.shareURL = shareURL.absoluteString
        if case .success(let saved) = saveResults[cardRecord.recordID] {
            card.systemFields = Self.systemFields(of: saved)
        }
        try context.save()
        startEngines()
        return shareURL
    }

    /// Owner: removes the card from iCloud, so the other coaches lose the link.
    /// Joined card: leaves it. The badges stay on this device either way.
    func stopSharing(_ card: SavedPlayerCard) async throws {
        guard let context else { return }
        let zoneID = Self.zoneID(for: card)
        let database = card.isOwner ? cloudContainer.privateCloudDatabase : cloudContainer.sharedCloudDatabase
        do {
            _ = try await database.modifyRecordZones(saving: [], deleting: [zoneID])
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // Already gone
        }
        for award in try CardStore(context: context).awards(onCard: card.cardId) {
            award.cloudSystemFields = nil
        }
        context.delete(card)
        try context.save()
    }

    // MARK: - Joining a card (share link opened)

    func accept(_ metadata: CKShare.Metadata) async {
        guard metadata.participantRole != .owner else { return }
        let zoneID = metadata.share.recordID.zoneID
        guard let cardId = Self.cardId(from: zoneID) else { return }
        do {
            _ = try await cloudContainer.accept(metadata)
            var records: [CKRecord] = []
            var token: CKServerChangeToken?
            var moreComing = true
            while moreComing {
                let changes = try await cloudContainer.sharedCloudDatabase.recordZoneChanges(inZoneWith: zoneID, since: token)
                records += changes.modificationResultsByID.values.compactMap { try? $0.get().record }
                token = changes.changeToken
                moreComing = changes.moreComing
            }
            let name = records.first { $0.recordType == "PlayerCard" }?["name"] as? String
                ?? metadata.share[CKShare.SystemFieldKey.title] as? String ?? "Speler"
            let awards: [AwardValue] = records.compactMap { record in
                guard record.recordType == "BadgeAward",
                      let badge = (record["badge"] as? String).flatMap(BadgeKind.init(rawValue:)),
                      let matchId = (record["matchId"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
                return AwardValue(cardId: cardId, badge: badge, matchId: matchId,
                                  earnedAt: record["earnedAt"] as? Date ?? Date(),
                                  opponentName: record["opponentName"] as? String ?? "",
                                  awardedBy: record["awardedBy"] as? String ?? "",
                                  deletedAt: record["deletedAt"] as? Date)
            }
            inbox = PendingCard(cardId: cardId, name: name, awards: awards,
                                source: .share(zoneOwnerName: zoneID.ownerName, shareURL: metadata.share.url?.absoluteString))
        } catch {
            log.error("Accepting a card failed: \(error.localizedDescription)")
            lastError = "De kaart kon niet worden geopend: \(error.localizedDescription)"
        }
    }

    /// Links a pending card to a local player (or a new one), merges its badges
    /// and, for a CloudKit card, sends this device's badges for that player along.
    func completeLink(_ pending: PendingCard, to player: SavedPlayer?) throws {
        guard let context else { return }
        let store = CardStore(context: context)
        try store.link(cardId: pending.cardId, name: pending.name, to: player)
        var changed = try store.merge(pending.awards)
        if case .share(let owner, let url) = pending.source, cloudCard(pending.cardId) == nil {
            context.insert(SavedPlayerCard(cardId: pending.cardId, name: pending.name, isOwner: false,
                                           zoneOwnerName: owner, shareURL: url))
            // Everything this device has on the card that the zone does not have yet
            changed += try store.awards(onCard: pending.cardId).filter { $0.cloudSystemFields == nil }
        }
        try context.save()
        startEngines()
        awardsChanged(changed)
    }

    // MARK: - Engine state

    private static func stateKey(_ scope: CKDatabase.Scope) -> String {
        "cardSyncState.\(scope == .private ? "private" : "shared")"
    }

    private static func loadState(_ scope: CKDatabase.Scope) -> CKSyncEngine.State.Serialization? {
        guard let data = UserDefaults.standard.data(forKey: stateKey(scope)) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private static func saveState(_ state: CKSyncEngine.State.Serialization, scope: CKDatabase.Scope) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey(scope))
        }
    }
}

/// Forwards engine callbacks to `CardSync` on the main actor
private final class EngineDelegate: CKSyncEngineDelegate, @unchecked Sendable {
    let scope: CKDatabase.Scope

    init(scope: CKDatabase.Scope) {
        self.scope = scope
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await MainActor.run { CardSync.shared.handle(event, scope: scope) }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await CardSync.shared.nextBatch(context, engine: syncEngine)
    }
}
