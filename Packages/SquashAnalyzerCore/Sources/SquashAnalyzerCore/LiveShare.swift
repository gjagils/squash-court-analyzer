import Foundation
import Observation

// Live meekijken (docs/archief/plan-live-meekijken.md): the coach or referee taps
// "Live delen", shares the link in the WhatsApp group, and the app sends the
// whole match state to the live server (server/live) after every rally. When
// the match is over the session is deleted straight away. Only first names
// leave the phone.

/// Where a live-shared match stands
public enum LiveStatus: String, Codable, Sendable {
    /// Before the first serve
    case warmup
    case playing
    /// Between games
    case between
    case finished
}

/// The whole state of a live-shared match. Always the full state, never a
/// change, so an undone rally or a missed send fixes itself with the next one.
/// The players' photos for the viewer page: small JPEG thumbnails, base64,
/// sent once after the session is made (not with every rally). Only when the
/// coach has "Foto's meesturen" on; the server keeps them in memory with the
/// session and drops them with it.
public struct LivePhotos: Codable, Equatable, Sendable {
    public var p1: String?
    public var p2: String?

    /// The server refuses larger ones (server/live maxPhotoBytes)
    public static let maxBytes = 24 * 1024

    public init(player1: Data?, player2: Data?) {
        p1 = LivePhotos.encoded(player1)
        p2 = LivePhotos.encoded(player2)
    }

    public var isEmpty: Bool { p1 == nil && p2 == nil }

    static func encoded(_ jpeg: Data?) -> String? {
        guard let jpeg, jpeg.count > 3, jpeg.count <= LivePhotos.maxBytes else { return nil }
        // JPEG only (FF D8 FF, the same check as the server), which in base64
        // always starts with "/9j/"; reading bytes out of Data is not in Skip
        let encoded = jpeg.base64EncodedString()
        return encoded.hasPrefix("/9j/") ? encoded : nil
    }
}

public struct LiveSnapshot: Codable, Equatable, Sendable {
    public var p1: String
    public var p2: String
    public var bestOf: Int
    /// Finished games as [player 1, player 2]
    public var games: [[Int]]
    /// The game under way (or just finished) as [player 1, player 2]
    public var score: [Int]
    /// Games won, head start included, as [player 1, player 2]
    public var gamesWon: [Int]
    /// 1 or 2
    public var server: Int
    /// "L" or "R"
    public var side: String
    public var status: LiveStatus
    /// "Jan: Winner · Volley drop"; only when the coach shows it to viewers
    public var lastPoint: String?
    /// 1 or 2 once the match is decided
    public var winner: Int?

    public init(p1: String, p2: String, bestOf: Int, games: [[Int]], score: [Int], gamesWon: [Int],
                server: Int, side: String, status: LiveStatus, lastPoint: String? = nil, winner: Int? = nil) {
        self.p1 = LiveSnapshot.firstName(p1, fallback: "Speler 1")
        self.p2 = LiveSnapshot.firstName(p2, fallback: "Speler 2")
        self.bestOf = bestOf
        self.games = games
        self.score = score
        self.gamesWon = gamesWon
        self.server = server
        self.side = side
        self.status = status
        self.lastPoint = lastPoint
        self.winner = winner
    }

    public static let maxNameLength = 20

    /// First name only: "Jan de Vries" → "Jan", "Anne-Marie" stays. Keeps
    /// letters, hyphens and apostrophes (the server does the same).
    public static func firstName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var first = ""
        for character in trimmed {
            if character == " " || character == "\t" { break }
            first += String(character)
        }
        var kept = ""
        for character in first {
            if isNameLetter(character) || character == "-" || character == "'" {
                kept += String(character)
            }
        }
        if kept.count > maxNameLength {
            kept = String(kept.prefix(maxNameLength))
        }
        return kept.isEmpty ? fallback : kept
    }

    /// Character.isLetter is not in Skip; Kotlin's Char.isLetter() is the same test
    static func isNameLetter(_ character: Character) -> Bool {
        #if SKIP
        return character.isLetter()
        #else
        return character.isLetter
        #endif
    }

    static func number(_ player: Player) -> Int { player == Player.player1 ? 1 : 2 }
    static func side(_ side: ServerSide) -> String { side == ServerSide.left ? "L" : "R" }
}

public extension Match {
    /// The live state of this coach match; `showLastPoint` adds the last rally
    /// ("Jan: Winner · Volley drop"), which the coach may keep to themselves
    func liveSnapshot(showLastPoint: Bool = false) -> LiveSnapshot {
        let game = currentGame
        var finished: [[Int]] = []
        for played in games {
            if played.isGameOver { finished.append([played.player1Score, played.player2Score]) }
        }
        let status: LiveStatus
        if isMatchOver {
            status = LiveStatus.finished
        } else if game.isGameOver {
            status = LiveStatus.between
        } else if !game.isStarted {
            status = finished.isEmpty ? LiveStatus.warmup : LiveStatus.between
        } else {
            status = LiveStatus.playing
        }
        var last: String? = nil
        if showLastPoint, let point = game.points.last {
            let name = LiveSnapshot.firstName(name(for: point.scorer), fallback: point.scorer == Player.player1 ? "Speler 1" : "Speler 2")
            last = "\(name): \(point.summary)"
        }
        var winnerNumber: Int? = nil
        if let matchWinner { winnerNumber = LiveSnapshot.number(matchWinner) }
        return LiveSnapshot(p1: player1Name, p2: player2Name, bestOf: bestOf, games: finished,
                            score: [game.player1Score, game.player2Score],
                            gamesWon: [player1GamesWon, player2GamesWon],
                            server: LiveSnapshot.number(game.currentServer), side: LiveSnapshot.side(game.serverSide),
                            status: status, lastPoint: last, winner: winnerNumber)
    }
}

public extension RefereeMatch {
    /// The live state of this referee match
    var liveSnapshot: LiveSnapshot {
        var finished: [[Int]] = []
        for played in completedGames {
            finished.append([played.player1Score, played.player2Score])
        }
        if isGameOver {
            finished.append([player1Score, player2Score])
        }
        let status: LiveStatus
        if isMatchOver {
            status = LiveStatus.finished
        } else if isGameOver {
            status = LiveStatus.between
        } else if player1Score + player2Score == 0 {
            status = completedGames.isEmpty ? LiveStatus.warmup : LiveStatus.between
        } else {
            status = LiveStatus.playing
        }
        var winnerNumber: Int? = nil
        if let matchWinner { winnerNumber = LiveSnapshot.number(matchWinner) }
        return LiveSnapshot(p1: player1Name, p2: player2Name, bestOf: bestOf, games: finished,
                            score: [player1Score, player2Score],
                            gamesWon: [player1TotalGames, player2TotalGames],
                            server: LiveSnapshot.number(currentServer), side: LiveSnapshot.side(serverSide),
                            status: status, winner: winnerNumber)
    }
}

/// One HTTP request to the live server, per platform (iOS: URLSession,
/// Android: HttpURLConnection), like `AICoachTransport`
public protocol LiveTransport: Sendable {
    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse
}

/// The answer to creating a session
struct LiveCreated: Codable {
    let id: String
    let writeKey: String
    let url: String
}

public enum LiveShareError: Error, Equatable {
    case noTransport
    case noConnection
    case refused(status: Int)
}

/// The one live session of this phone. The app sets `transport` at start;
/// the scoring screens call `start`, `update` and `finish`.
@MainActor
@Observable
public final class LiveShare {
    /// Address of the live server (server/live-worker on Cloudflare; the Node
    /// version in server/live is the reserve). Above `shared`: Kotlin
    /// initialises statics top to bottom, and `shared` reads this in its
    /// `baseURL`; the other way round it was null on Android.
    public static let defaultBaseURL = "https://live.squashanalyzer.com"
    /// Old Instellingen key of the Alfa/Beta switch (October 2026, never in a
    /// shipped build): no longer read, kept so a stored value cannot interfere
    public static let serverKey = "liveSharingServer"

    /// Settings switch "Live meekijken" (on by default): only then the
    /// scoring screens show the LIVE button
    public static let enabledKey = "liveSharingEnabled"
    /// Instellingen: send the players' photos along (on by default)
    public static let photosKey = "liveSharingPhotos"

    public static let shared = LiveShare()

    public var transport: (any LiveTransport)? = nil
    /// Set by tests (and for a local server); otherwise `defaultBaseURL`
    private var customBaseURL: String? = nil
    public var baseURL: String {
        get { customBaseURL ?? LiveShare.defaultBaseURL }
        set { customBaseURL = newValue }
    }
    /// The server the live session was made on: a change of the setting
    /// during a match does not move the session
    private var sessionBaseURL: String = LiveShare.defaultBaseURL

    /// The match that is live, nil when nothing is shared
    public private(set) var matchId: UUID? = nil
    /// The link to share; changes only when the server lost the session
    public private(set) var link: String? = nil
    /// Set when the session had to be made again (server restart): share the new link
    public private(set) var linkChanged = false
    /// The last send failed (no network); the next rally tries again
    public private(set) var offline = false

    private var sessionId: String? = nil
    private var writeKey: String? = nil
    /// The newest state still to send (one channel: this phone has one live match)
    private let queue = LatestValueSender<LiveSnapshot>()
    private static let channel = "match"
    /// Sent after creating the session, and again when it had to be made again
    private var photos: LivePhotos? = nil
    /// Let go of the session once the final state is sent
    private var finishing = false
    /// A failed final send is tried again after this many seconds, up to `maxFinishRetries` times
    public var finishRetryDelay: Double = 20.0
    public static let maxFinishRetries = 30
    private var finishRetries = 0
    private var retryScheduled = false

    public init(transport: (any LiveTransport)? = nil) {
        self.transport = transport
    }

    public func isLive(_ id: UUID) -> Bool { matchId == id && link != nil }

    /// Starts sharing `matchId` and returns the link. Sharing another match
    /// first stops the old one.
    public func start(matchId id: UUID, snapshot: LiveSnapshot, photos: LivePhotos? = nil) async throws -> String {
        // `self.` everywhere: in Kotlin the parameter is called `matchId` too
        if let link, self.matchId == id { return link }
        if self.matchId != nil { await stop() }
        self.photos = photos
        try await create(snapshot)
        self.matchId = id
        linkChanged = false
        return link ?? ""
    }

    /// Sends the new state of the live match (nothing when `matchId` is not
    /// live). Sends that pile up are merged: only the newest state goes.
    public func update(matchId id: UUID, snapshot: LiveSnapshot) {
        guard self.matchId == id, sessionId != nil else { return }
        queue.set(snapshot, for: LiveShare.channel)
        guard !queue.isSending(LiveShare.channel) else { return }
        Task { await flush() }
    }

    /// The match is over: send the final state and let go of the session. It
    /// is not deleted: viewers keep the final score until the server removes
    /// it, 2 hours after this last update. "Live stoppen" does delete at once.
    public func finish(matchId id: UUID, snapshot: LiveSnapshot) async {
        guard self.matchId == id, sessionId != nil else { return }
        queue.set(snapshot, for: LiveShare.channel)
        finishing = true
        // A send under way picks up the final state and lets go afterwards
        if !queue.isSending(LiveShare.channel) { await flush() }
    }

    /// Stop sharing: the session is deleted on the server
    public func stop() async {
        let id = sessionId
        let key = writeKey
        reset()
        guard let id, let key, let transport, let url = URL(string: "\(sessionBaseURL)/api/live/\(id)") else { return }
        await LiveWrite.delete(url, key: key, transport: transport)
    }

    /// Tries the final score again a little later; gives up after
    /// `maxFinishRetries` (the server forgets the session anyway)
    private func scheduleFinishRetry() {
        guard !retryScheduled else { return }
        guard finishRetries < LiveShare.maxFinishRetries else {
            reset()
            return
        }
        finishRetries += 1
        retryScheduled = true
        let delay = UInt64(finishRetryDelay * 1_000_000_000.0)
        Task {
            try? await Task.sleep(nanoseconds: delay)
            await self.retryAfterDelay()
        }
    }

    private func retryAfterDelay() async {
        retryScheduled = false
        await retryPending()
    }

    /// Sends what is still waiting (the final score after a failed send) right
    /// away, e.g. when the app becomes active again
    public func retryPending() async {
        guard queue.hasPending(LiveShare.channel), !queue.isSending(LiveShare.channel), sessionId != nil else { return }
        await flush()
    }

    /// Forget the session on this phone only (the server keeps it)
    private func reset() {
        finishRetries = 0
        retryScheduled = false
        sessionId = nil
        writeKey = nil
        link = nil
        matchId = nil
        queue.drop(LiveShare.channel)
        photos = nil
        finishing = false
        linkChanged = false
        offline = false
    }

    /// Clears the "share the new link" note once the coach shared it
    public func acknowledgeLink() {
        linkChanged = false
    }

    private func create(_ snapshot: LiveSnapshot) async throws {
        guard let transport else { throw LiveShareError.noTransport }
        sessionBaseURL = baseURL
        guard let url = URL(string: "\(sessionBaseURL)/api/live") else { throw LiveShareError.noConnection }
        let body = try JSONEncoder().encode(snapshot)
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "POST", url: url, headers: ["Content-Type": "application/json"], body: body)
        } catch {
            throw LiveShareError.noConnection
        }
        guard response.status == 201, let created = try? JSONDecoder().decode(LiveCreated.self, from: response.body) else {
            throw LiveShareError.refused(status: response.status)
        }
        sessionId = created.id
        writeKey = created.writeKey
        link = created.url
        offline = false
        await sendPhotos()
    }

    /// The photos, if any; a failure only means viewers see the first letters
    private func sendPhotos() async {
        guard let photos, !photos.isEmpty, let transport, let id = sessionId, let key = writeKey,
              let url = URL(string: "\(sessionBaseURL)/api/live/\(id)/photos"),
              let body = try? JSONEncoder().encode(photos) else { return }
        _ = await LiveWrite.put(body, to: url, key: key, transport: transport)
    }

    /// Sends the newest state; a failed one is kept for the next rally
    private func flush() async {
        guard !queue.isSending(LiveShare.channel) else { return }
        await queue.flush(LiveShare.channel) { snapshot in await self.put(snapshot) }
        // Match over: this phone lets go once the final score is there; the
        // server keeps it for viewers and removes it after its idle time (2 hours).
        // Not sent (no network): kept and tried again, so viewers still get it.
        if finishing {
            if !queue.hasPending(LiveShare.channel) {
                reset()
            } else {
                scheduleFinishRetry()
            }
        }
    }

    /// Sends one state; a session the server no longer knows is made again
    private func put(_ snapshot: LiveSnapshot) async -> Bool {
        guard let transport, let id = sessionId, let key = writeKey,
              let url = URL(string: "\(sessionBaseURL)/api/live/\(id)"),
              let body = try? JSONEncoder().encode(snapshot) else { return false }
        guard let status = await LiveWrite.put(body, to: url, key: key, transport: transport) else {
            offline = true
            return false
        }
        if status == 404 || status == 401 {
            // At the end of a match a gone page is not made again: the final
            // score would go to a link nobody has
            if finishing { return true }
            do {
                try await create(snapshot)
            } catch {
                offline = true
                return false
            }
            linkChanged = true
            return true
        }
        offline = !LiveWrite.isSuccess(status)
        return !offline
    }
}
