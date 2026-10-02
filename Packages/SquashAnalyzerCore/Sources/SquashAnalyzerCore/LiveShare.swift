import Foundation
import Observation

// Live meekijken (docs/plan-live-meekijken.md): the coach or referee taps
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
            first.append(character)
        }
        var kept = ""
        for character in first {
            if character.isLetter || character == "-" || character == "'" {
                kept.append(character)
            }
        }
        if kept.count > maxNameLength {
            kept = String(kept.prefix(maxNameLength))
        }
        return kept.isEmpty ? fallback : kept
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
    public static let shared = LiveShare()

    /// Address of the live server (server/live, behind the reverse proxy)
    public static let defaultBaseURL = "https://live.squashanalyzer.com"

    public var transport: (any LiveTransport)? = nil
    public var baseURL: String = LiveShare.defaultBaseURL

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
    private var pending: LiveSnapshot? = nil
    private var sending = false
    /// Delete the session once the final state is sent
    private var finishing = false

    public init(transport: (any LiveTransport)? = nil) {
        self.transport = transport
    }

    public func isLive(_ id: UUID) -> Bool { matchId == id && link != nil }

    /// Starts sharing `matchId` and returns the link. Sharing another match
    /// first stops the old one.
    public func start(matchId id: UUID, snapshot: LiveSnapshot) async throws -> String {
        if let link, matchId == id { return link }
        if matchId != nil { await stop() }
        try await create(snapshot)
        matchId = id
        linkChanged = false
        return link ?? ""
    }

    /// Sends the new state of the live match (nothing when `matchId` is not
    /// live). Sends that pile up are merged: only the newest state goes.
    public func update(matchId id: UUID, snapshot: LiveSnapshot) {
        guard matchId == id, sessionId != nil else { return }
        pending = snapshot
        guard !sending else { return }
        Task { await flush() }
    }

    /// The match is over: send the final state, then delete the session at once
    public func finish(matchId id: UUID, snapshot: LiveSnapshot) async {
        guard matchId == id, sessionId != nil else { return }
        pending = snapshot
        finishing = true
        // A send under way picks up the final state and deletes afterwards
        if !sending { await flush() }
    }

    /// Stop sharing: the session is deleted on the server
    public func stop() async {
        let id = sessionId
        let key = writeKey
        sessionId = nil
        writeKey = nil
        link = nil
        matchId = nil
        pending = nil
        finishing = false
        linkChanged = false
        offline = false
        guard let id, let key, let transport, let url = URL(string: "\(baseURL)/api/live/\(id)") else { return }
        _ = try? await transport.send(method: "DELETE", url: url, headers: ["Authorization": "Bearer \(key)"], body: nil)
    }

    /// Clears the "share the new link" note once the coach shared it
    public func acknowledgeLink() {
        linkChanged = false
    }

    private func create(_ snapshot: LiveSnapshot) async throws {
        guard let transport else { throw LiveShareError.noTransport }
        guard let url = URL(string: "\(baseURL)/api/live") else { throw LiveShareError.noConnection }
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
    }

    private func flush() async {
        guard !sending else { return }
        sending = true
        while let next = pending {
            pending = nil
            let ok = await put(next)
            if !ok {
                // Keep the newest state for the next rally (unless a newer one came in)
                if pending == nil { pending = next }
                break
            }
        }
        sending = false
        // Match over: gone at once, also when the last send failed (the server
        // forgets it anyway after its idle time)
        if finishing { await stop() }
    }

    /// Sends one state; a session the server no longer knows is made again
    private func put(_ snapshot: LiveSnapshot) async -> Bool {
        guard let transport, let id = sessionId, let key = writeKey,
              let url = URL(string: "\(baseURL)/api/live/\(id)"),
              let body = try? JSONEncoder().encode(snapshot) else { return false }
        do {
            let response = try await transport.send(method: "PUT", url: url,
                                                    headers: ["Content-Type": "application/json", "Authorization": "Bearer \(key)"],
                                                    body: body)
            if response.status == 404 || response.status == 401 {
                try await create(snapshot)
                linkChanged = true
                return true
            }
            offline = !(response.status >= 200 && response.status < 300)
            return !offline
        } catch {
            offline = true
            return false
        }
    }
}
