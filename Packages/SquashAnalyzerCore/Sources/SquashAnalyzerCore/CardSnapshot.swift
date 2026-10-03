import Foundation
#if !SKIP
import Compression
#endif
#if !SKIP
import CryptoKit
#endif

/// One badge award as it travels between devices in a card link.
public struct AwardValue: Equatable, Sendable {
    public let cardId: UUID
    public let badge: BadgeKind
    public let matchId: UUID
    public let earnedAt: Date
    public let opponentName: String
    public let awardedBy: String
    public let deletedAt: Date?

    public init(cardId: UUID, badge: BadgeKind, matchId: UUID, earnedAt: Date, opponentName: String, awardedBy: String, deletedAt: Date?) {
        self.cardId = cardId
        self.badge = badge
        self.matchId = matchId
        self.earnedAt = earnedAt
        self.opponentName = opponentName
        self.awardedBy = awardedBy
        self.deletedAt = deletedAt
    }

    public var id: UUID { AwardValue.awardId(cardId: cardId, badge: badge, matchId: matchId) }

    /// The same award on another card (when a player is linked to a shared card)
    public func onCard(_ cardId: UUID) -> AwardValue {
        AwardValue(cardId: cardId, badge: badge, matchId: matchId, earnedAt: earnedAt,
                   opponentName: opponentName, awardedBy: awardedBy, deletedAt: deletedAt)
    }

    /// Deterministic id: the first 16 bytes of SHA-256 over card, badge and match,
    /// with RFC 4122 version 5 and variant bits. Must stay byte-for-byte identical
    /// on every platform, since devices merge awards by this id.
    public static func awardId(cardId: UUID, badge: BadgeKind, matchId: UUID) -> UUID {
        let text = cardId.uuidString + "|" + badge.rawValue + "|" + matchId.uuidString
        let digest = SHA256.hash(data: text.data(using: .utf8)!)
        var bytes: [Int] = []
        for byte in digest {
            bytes.append(Int(byte))
            if bytes.count == 16 { break }
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]
        var hex = ""
        for index in 0..<16 {
            if index == 4 || index == 6 || index == 8 || index == 10 { hex += "-" }
            hex += digits[bytes[index] / 16] + digits[bytes[index] % 16]
        }
        return UUID(uuidString: hex)!
    }
}

/// A player card in a link: `https://squashanalyzer.com/kaart/#<payload>`, the
/// payload being raw-deflated JSON in base64url. The data sits in the fragment,
/// which browsers never send to the server; the web page draws the card from it
/// and both apps merge it. The byte format is shared with the website, so any
/// change must stay readable by `website/kaart/index.html` and older app builds.
public struct CardSnapshot: Codable, Equatable, Sendable {
    public var v = 1
    /// Card id
    public let c: UUID
    /// Player name
    public let n: String
    /// Awards, deleted ones included so a deletion travels too
    public let a: [Entry]

    public struct Entry: Codable, Equatable, Sendable {
        public let b: String
        public let m: UUID
        /// Earned at, seconds since 1970
        public let t: Int
        public let o: String
        public let w: String
        /// Deleted at, seconds since 1970
        public let d: Int?
    }

    public static let webBase = "https://squashanalyzer.com/kaart/#"
    public static let appBase = "squashanalyzer://kaart#"

    public init(cardId: UUID, name: String, awards: [AwardValue]) {
        c = cardId
        n = name
        a = awards.map { award in
            Entry(b: award.badge.rawValue, m: award.matchId, t: Int(award.earnedAt.timeIntervalSince1970),
                  o: award.opponentName, w: award.awardedBy,
                  d: award.deletedAt.map { Int($0.timeIntervalSince1970) })
        }
    }

    public var cardId: UUID { c }
    public var name: String { n }

    /// Entries with a badge this build does not know are skipped
    public var awards: [AwardValue] {
        a.compactMap { entry in
            guard let badge = BadgeKind(rawValue: entry.b) else { return nil }
            return AwardValue(cardId: c, badge: badge, matchId: entry.m,
                              earnedAt: Date(timeIntervalSince1970: TimeInterval(entry.t)),
                              opponentName: entry.o, awardedBy: entry.w,
                              deletedAt: entry.d.map { Date(timeIntervalSince1970: TimeInterval($0)) })
        }
    }

    public func payload() throws -> String {
        let json = try JSONEncoder().encode(self)
        return try CardSnapshot.deflate(json).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public func webURL() throws -> URL {
        URL(string: CardSnapshot.webBase + (try payload()))!
    }

    /// A link longer than this is refused before decoding (a real card is a few KB)
    static let maxPayloadLength = 64 * 1024
    /// Decompressing stops past this, so a tiny "zip bomb" cannot fill memory
    static let maxInflatedBytes = 256 * 1024

    public init(payload: String) throws {
        guard payload.count <= CardSnapshot.maxPayloadLength else { throw CardSnapshotError.unreadable }
        var base64 = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        for _ in 0..<padding { base64 += "=" }
        guard let deflated = Data(base64Encoded: base64) else { throw CardSnapshotError.unreadable }
        let json = try CardSnapshot.inflate(deflated)
        self = try JSONDecoder().decode(CardSnapshot.self, from: json)
    }

    /// Reads a card link from the website or the app's own scheme; nil for any other URL
    public init?(url: URL) {
        let host = url.host ?? ""
        let isWeb = (host == "squashanalyzer.com" || host == "www.squashanalyzer.com") && url.path.hasPrefix("/kaart")
        let isApp = url.scheme == "squashanalyzer" && host == "kaart"
        guard isWeb || isApp, let fragment = url.fragment, !fragment.isEmpty else { return nil }
        // Assigned directly, not via `guard let snapshot = try? ...; self = snapshot`:
        // Skip renames the guard binding but not the expanded `self =` assignment.
        do {
            self = try CardSnapshot(payload: fragment)
        } catch {
            return nil
        }
    }

    // Raw DEFLATE (RFC 1951, no zlib header): Apple's `.zlib` algorithm, Java's
    // `nowrap` mode and the website's `DecompressionStream("deflate-raw")` all
    // agree on it. The compressed bytes may differ per platform; only the
    // decompressed JSON has to match.

    static func deflate(_ data: Data) throws -> Data {
        #if SKIP
        let deflater = java.util.zip.Deflater(java.util.zip.Deflater.DEFAULT_COMPRESSION, true)
        deflater.setInput(data.platformValue)
        deflater.finish()
        let output = java.io.ByteArrayOutputStream()
        let buffer = kotlin.ByteArray(size: 1024)
        while !deflater.finished() {
            let count = deflater.deflate(buffer)
            output.write(buffer, 0, count)
        }
        deflater.end()
        return Data(platformValue: output.toByteArray())
        #else
        return try (data as NSData).compressed(using: .zlib) as Data
        #endif
    }

    static func inflate(_ data: Data) throws -> Data {
        #if SKIP
        let inflater = java.util.zip.Inflater(true)
        // nowrap mode wants one extra dummy input byte after the stream
        inflater.setInput(data.platformValue.copyOf(data.count + 1))
        let output = java.io.ByteArrayOutputStream()
        let buffer = kotlin.ByteArray(size: 1024)
        while !inflater.finished() {
            let count = inflater.inflate(buffer)
            if count == 0 && (inflater.needsInput() || inflater.needsDictionary()) {
                inflater.end()
                throw CardSnapshotError.unreadable
            }
            output.write(buffer, 0, count)
            if output.size() > maxInflatedBytes {
                inflater.end()
                throw CardSnapshotError.unreadable
            }
        }
        inflater.end()
        return Data(platformValue: output.toByteArray())
        #else
        // Streamed, so decompressing stops as soon as the output is too large
        var output = Data()
        let filter = try OutputFilter(.decompress, using: .zlib) { chunk in
            guard let chunk else { return }
            output.append(chunk)
            if output.count > maxInflatedBytes { throw CardSnapshotError.unreadable }
        }
        do {
            try filter.write(data)
            try filter.finalize()
        } catch {
            throw CardSnapshotError.unreadable
        }
        return output
        #endif
    }
}

public enum CardSnapshotError: Error {
    case unreadable
}
