import Foundation
import Observation

// 4.0: matches waiting to go to a player's account. A finished match for a
// linked player goes in here first, with its own match id, and leaves only
// once the Worker took it: no signal in the sports hall, or the app closed, and
// it simply goes later. Sending again never makes a second request (the Worker
// ignores a match id it already has). Kept in a JSON file next to the team
// matches, like the game notes, so no SwiftData or Room migration is needed.
// Oefenpartijen (`PracticeMatches`) never go in, and leave if marked later.

/// One match for one player
public struct AccountOutboxEntry: Codable, Equatable, Sendable {
    public var match: AccountMatchUpload
    /// Who it is for; nil for an own match (the signed-in player's, counted at once).
    /// Not named `to`: Kotlin's `encode(to:)` would hide it.
    public var recipient: AccountRecipient?
    /// The name the sender uses in the app
    public var senderName: String
    /// Milliseconds since 1970
    public var addedAt: Int64
    public var attempts: Int

    public init(match: AccountMatchUpload, to: AccountRecipient?, senderName: String, addedAt: Int64, attempts: Int = 0) {
        self.match = match
        recipient = to
        self.senderName = senderName
        self.addedAt = addedAt
        self.attempts = attempts
    }

    public var isOwn: Bool { recipient == nil }

    /// The same match for another player is another entry
    public var key: String {
        let code = recipient?.code ?? ""
        let path = recipient?.sbnPath ?? ""
        return "\(match.matchId)|\(code)|\(path)"
    }
}

/// The file: `{"version": 1, "waiting": [ … ]}` (not "entries": as a
/// CodingKey that clashes with Kotlin's `Enum.entries`)
public enum AccountOutboxFile {
    public static let fileName = "account-outbox.json"
    public static let formatVersion = 1

    struct Envelope: Codable {
        var version: Int
        var waiting: [AccountOutboxEntry]
    }

    /// Empty when there is no file or it cannot be read
    public static func read(in directory: URL) -> [AccountOutboxEntry] {
        let url = directory.appendingPathComponent(AccountOutboxFile.fileName)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return [] }
        return envelope.waiting
    }

    /// Written in one go (`.atomic`)
    public static func write(_ entries: [AccountOutboxEntry], in directory: URL) throws {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(AccountOutboxFile.fileName)
        let data = try JSONEncoder().encode(Envelope(version: AccountOutboxFile.formatVersion, waiting: entries))
        try data.write(to: url, options: Data.WritingOptions.atomic)
    }
}

/// The queue for the screens ("wordt verstuurd") and for `PlayerAccount.sendOutbox`
@MainActor
@Observable
public final class AccountOutbox {
    /// After this long a match is dropped: the Worker wipes unanswered requests after 90 days too
    public static let maxAgeDays = 90

    public static let shared = AccountOutbox()

    public private(set) var entries: [AccountOutboxEntry] = []
    private var directory: URL? = nil

    public init() {}

    public func configure(directory: URL) {
        self.directory = directory
        entries = AccountOutboxFile.read(in: directory)
    }

    /// Queues `match` for `to` (nil: the own account). False for nothing to send:
    /// no match (an oefenpartij gives nil) or a match marked as practice.
    /// Queuing the same match for the same player again replaces the waiting copy.
    @discardableResult
    public func add(_ match: AccountMatchUpload?, to: AccountRecipient?, senderName: String, now: Date = Date()) -> Bool {
        guard let match else { return false }
        if PracticeMatches.shared.contains(id: match.matchId) { return false }
        let entry = AccountOutboxEntry(match: match, to: to, senderName: senderName, addedAt: AuthSession.millis(now))
        var updated = entries.filter { existing in existing.key != entry.key }
        updated.append(entry)
        save(updated)
        return true
    }

    /// The match is still waiting to go ("wordt verstuurd")
    public func isWaiting(matchId: String) -> Bool {
        let wanted = matchId.uppercased()
        return entries.contains { entry in entry.match.matchId == wanted }
    }

    public func remove(_ keys: [String]) {
        if keys.isEmpty { return }
        save(entries.filter { entry in !keys.contains(entry.key) })
    }

    public func countAttempt(_ keys: [String]) {
        var updated: [AccountOutboxEntry] = []
        for entry in entries {
            var copy = entry
            if keys.contains(entry.key) { copy.attempts += 1 }
            updated.append(copy)
        }
        save(updated)
    }

    /// Entries to drop before sending: too old, or marked as practice since
    public func stale(now: Date) -> [String] {
        let cutoff = AuthSession.millis(now) - Int64(AccountOutbox.maxAgeDays) * Int64(24 * 60 * 60 * 1000)
        var keys: [String] = []
        for entry in entries {
            if entry.addedAt < cutoff || PracticeMatches.shared.contains(id: entry.match.matchId) { keys.append(entry.key) }
        }
        return keys
    }

    /// Empties the queue (deleting the account takes the own matches with it)
    public func removeOwn() {
        save(entries.filter { entry in !entry.isOwn })
    }

    private func save(_ updated: [AccountOutboxEntry]) {
        entries = updated
        guard let directory else { return }
        try? AccountOutboxFile.write(updated, in: directory)
    }
}
