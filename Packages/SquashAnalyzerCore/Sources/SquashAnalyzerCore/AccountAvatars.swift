import Foundation

// 4.0 (Gerd-Jan, 10 November 2026): a player with an account can put up an
// avatar. Every phone with the app (an account is not needed) fetches it for
// the players in Spelers that are linked to that SBN player, and shows it as
// that player's photo. A photo the user set on this phone always wins: only a
// photo this phone fetched itself is replaced or removed. Which photos those
// are is kept by player id with a checksum of the stored photo, so a photo
// picked by hand later is recognised and left alone.

/// What one fetched avatar on this phone came from
public struct AccountAvatarRecord: Codable, Equatable, Sendable {
    public let sbnPath: String
    public let version: Int64
    /// `BackupCodec.checksum` of the photo as the store kept it
    public let checksum: String

    public init(sbnPath: String, version: Int64, checksum: String) {
        self.sbnPath = sbnPath
        self.version = version
        self.checksum = checksum
    }
}

/// A player in Spelers and the SBN player it is linked to
struct AccountAvatarLink {
    let playerId: String
    let sbnPath: String
}

public enum AccountAvatars {
    public static let recordsKey = "accountAvatarRecords"
    /// Milliseconds of the last check, as text (Android's Int is 32 bits)
    public static let checkedKey = "accountAvatarsCheckedMillis"
    /// At most once an hour by itself; `force` (Mijn team just synced, a new player) asks at once
    static let interval: Int64 = 3_600_000

    /// What to do for one player
    public enum Step: Equatable, Sendable {
        /// Fetch the avatar of this SBN player and use it
        case fetch(sbnPath: String)
        /// The fetched photo is gone on the server: remove it here too
        case remove
        /// The user's own photo, or already up to date
        case keep
        /// A photo picked by hand replaced the fetched one: forget the record, leave the photo
        case forget
    }

    /// The step for a player linked to `sbnPath`. `photoChecksum` is that of the
    /// photo on this phone (nil without one), `serverVersion` the avatar's (nil without one).
    public static func step(sbnPath: String, photoChecksum: String?, record: AccountAvatarRecord?,
                            serverVersion: Int64?) -> Step {
        if let photoChecksum {
            guard let record, record.checksum == photoChecksum else {
                return record == nil ? Step.keep : Step.forget
            }
            // The photo is the one fetched here
            guard let serverVersion else { return Step.remove }
            if record.sbnPath == sbnPath && record.version == serverVersion { return Step.keep }
            return Step.fetch(sbnPath: sbnPath)
        }
        // No photo here: fetch when there is an avatar (a removed photo comes back only with a new version)
        guard let serverVersion else { return record == nil ? Step.keep : Step.forget }
        if let record, record.sbnPath == sbnPath && record.version == serverVersion { return Step.keep }
        return Step.fetch(sbnPath: sbnPath)
    }

    public static func records(in defaults: UserDefaults = UserDefaults.standard) -> [String: AccountAvatarRecord] {
        guard let text = defaults.string(forKey: AccountAvatars.recordsKey), let data = text.data(using: String.Encoding.utf8),
              let value = try? JSONDecoder().decode([String: AccountAvatarRecord].self, from: data) else { return [:] }
        return value
    }

    static func store(_ records: [String: AccountAvatarRecord], in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(records), let text = String(data: data, encoding: String.Encoding.utf8) else { return }
        defaults.set(text, forKey: AccountAvatars.recordsKey)
    }

    /// Fetches the avatars of the linked players in Spelers. Returns how many
    /// photos changed; 0 without network, switch or linked players.
    @MainActor @discardableResult
    public static func sync(players: any PlayerProfileStore, photos: any PlayerPhotoStore,
                            account: PlayerAccount = PlayerAccount.shared, force: Bool = false,
                            now: Date = Date(), in defaults: UserDefaults = UserDefaults.standard) async -> Int {
        guard Features.shared.playerAccount, account.isConfigured else { return 0 }
        let nowMillis = Int64(now.timeIntervalSince1970 * 1000.0)
        let last = Int64(defaults.string(forKey: AccountAvatars.checkedKey) ?? "") ?? Int64(0)
        if !force && nowMillis - last < AccountAvatars.interval { return 0 }
        guard let known = try? await players.loadPlayers() else { return 0 }
        let links = PlayerSBNLinks.all(in: defaults)
        var linked: [AccountAvatarLink] = []
        var paths: [String] = []
        for player in known {
            guard let path = links[player.id] else { continue }
            linked.append(AccountAvatarLink(playerId: player.id, sbnPath: path))
            if !paths.contains(path) { paths.append(path) }
        }
        if linked.isEmpty { return 0 }
        var records = AccountAvatars.records(in: defaults)
        guard let versions = try? await account.avatarVersions(sbnPaths: paths),
              let stored = try? await photos.photos() else { return 0 }
        defaults.set("\(nowMillis)", forKey: AccountAvatars.checkedKey)
        var changed = 0
        for entry in linked {
            var checksum: String? = nil
            if let photo = stored[entry.playerId] { checksum = BackupCodec.checksum(of: photo) }
            let step = AccountAvatars.step(sbnPath: entry.sbnPath, photoChecksum: checksum, record: records[entry.playerId],
                                           serverVersion: versions[entry.sbnPath])
            if step == Step.keep { continue }
            if step == Step.forget {
                records[entry.playerId] = nil
                continue
            }
            do {
                if step == Step.remove {
                    try await photos.setPhoto(nil, for: entry.playerId)
                    records[entry.playerId] = nil
                    changed += 1
                    continue
                }
                guard let version = versions[entry.sbnPath],
                      let image = try await account.avatar(sbnPath: entry.sbnPath) else { continue }
                try await photos.setPhoto(image, for: entry.playerId)
                guard let saved = try await photos.photos()[entry.playerId] else { continue }
                records[entry.playerId] = AccountAvatarRecord(sbnPath: entry.sbnPath, version: version,
                                                              checksum: BackupCodec.checksum(of: saved))
                changed += 1
            } catch {
                continue
            }
        }
        AccountAvatars.store(records, in: defaults)
        return changed
    }

    /// The photo of this player came from an account ("Foto melden" is offered for it)
    public static func isFetched(playerId: String, in defaults: UserDefaults = UserDefaults.standard) -> Bool {
        records(in: defaults)[playerId] != nil
    }
}
