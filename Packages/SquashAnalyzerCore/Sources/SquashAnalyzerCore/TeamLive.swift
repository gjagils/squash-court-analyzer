import Foundation
import Observation

// Live meekijken per teamwedstrijd (docs/plan-live-teamwedstrijd.md): one
// live page for the whole team evening (server/live-worker, `/t/<id>`), with
// the four partijen on it. Every phone that has the team key writes its own
// partij: a hand-filled result when the team match is saved, and point by
// point while a coach or referee match started for that partij is played.
// Only team names, first names and the stand leave the phone.

/// One partij as the live server wants it, the home player first (`p1`)
public struct TeamLivePartij: Codable, Equatable, Sendable {
    /// First name; empty = none filled in (the page shows "Squash Delft 8 E1")
    public var p1: String
    public var p2: String
    public var bestOf: Int
    /// Finished games with a score, [home, away]
    public var games: [[Int]]
    /// The game under way, [home, away]
    public var score: [Int]
    /// Games won, [home, away]; more than `games` when scores are unknown
    public var gamesWon: [Int]
    public var server: Int
    public var side: String
    public var status: LiveStatus
    public var lastPoint: String?
    public var winner: Int?

    public init(p1: String, p2: String, bestOf: Int, games: [[Int]], score: [Int], gamesWon: [Int],
                server: Int, side: String, status: LiveStatus, lastPoint: String? = nil, winner: Int? = nil) {
        self.p1 = p1
        self.p2 = p2
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

    /// The live state of a tracked match for this partij. `homeIsPlayer1` says
    /// which player of the match is the home player; if it is player 2 the
    /// whole state is turned around. Names are the labels given (already
    /// first names, or empty for the default).
    public init(snapshot: LiveSnapshot, homeIsPlayer1: Bool, homeLabel: String, awayLabel: String) {
        func pair(_ values: [Int]) -> [Int] {
            if values.count < 2 { return [0, 0] }
            return homeIsPlayer1 ? [values[0], values[1]] : [values[1], values[0]]
        }
        var turned: [[Int]] = []
        for game in snapshot.games { turned.append(pair(game)) }
        self.p1 = homeLabel
        self.p2 = awayLabel
        self.bestOf = snapshot.bestOf
        self.games = turned
        self.score = pair(snapshot.score)
        self.gamesWon = pair(snapshot.gamesWon)
        self.server = homeIsPlayer1 ? snapshot.server : 3 - snapshot.server
        self.side = snapshot.side
        self.status = snapshot.status
        self.lastPoint = snapshot.lastPoint
        if let won = snapshot.winner {
            self.winner = homeIsPlayer1 ? won : 3 - won
        } else {
            self.winner = nil
        }
    }
}

public struct TeamLiveHeader: Codable, Equatable, Sendable {
    public var home: String
    public var away: String
    /// Milliseconds since 1970 (an Int64: a Double is written as 1.79E12 on Android)
    public var date: Int64

    public init(home: String, away: String, date: Int64) {
        self.home = home
        self.away = away
        self.date = date
    }
}

public struct TeamLiveCreated: Codable, Equatable, Sendable {
    public let id: String
    /// For the invitation: writes a partij
    public let writeKey: String
    /// Stays on this phone: ends the live page
    public let ownerKey: String?
    public let url: String
}

/// What a key may do on the live page
public enum TeamLiveRole: String, Codable, Sendable {
    case owner
    case writer
}

struct TeamLiveRoleAnswer: Codable {
    var role: TeamLiveRole
}

/// What the server holds: the team match and the partijen by slot ("1"..."4")
public struct TeamLiveState: Codable, Equatable, Sendable {
    public var team: TeamLiveHeader
    public var partijen: [String: TeamLivePartij]
    public var updatedAt: Double
}

struct TeamLiveEmpty: Codable {
    var empty: Bool
}

// MARK: - Uitnodiging

/// What a fellow coach needs to join a live team match: the id and the team
/// key, as a link (`squashanalyzer.com/team/#id.key`, the fragment never goes
/// to a server) or a code to paste.
public struct TeamInvite: Equatable, Sendable {
    public let id: String
    public let key: String

    public init(id: String, key: String) {
        self.id = id
        self.key = key
    }

    public var code: String { id + "." + key }
    public var link: String { "https://squashanalyzer.com/team/#" + code }

    static let idAlphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
    static let keyAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    private static func allIn(_ text: String, _ alphabet: String) -> Bool {
        if text.isEmpty { return false }
        for character in text where !alphabet.contains(character) { return false }
        return true
    }

    /// "id.key" with an id of 12 and a key of 20 to 64 characters, or nil
    static func fromCode(_ code: String) -> TeamInvite? {
        let parts = code.components(separatedBy: ".")
        if parts.count != 2 { return nil }
        let id = parts[0]
        let key = parts[1]
        if id.count != 12 || key.count < 20 || key.count > 64 { return nil }
        if !allIn(id, idAlphabet) || !allIn(key, keyAlphabet) { return nil }
        return TeamInvite(id: id, key: key)
    }

    /// A pasted link, a link inside a message, `squashanalyzer://team#code`, or the bare code.
    /// Words and the part after the last "#" are cut by hand: Skip has no CharacterSet splitting.
    public static func parse(_ text: String) -> TeamInvite? {
        var words: [String] = []
        var word = ""
        for character in text {
            if character == " " || character == "\n" || character == "\t" || character == "\r" {
                if !word.isEmpty {
                    words.append(word)
                    word = ""
                }
            } else {
                word += String(character)
            }
        }
        if !word.isEmpty { words.append(word) }
        for item in words {
            var candidate = ""
            for character in item {
                if character == "#" {
                    candidate = ""
                } else {
                    candidate += String(character)
                }
            }
            if let invite = fromCode(trimmedEnd(candidate)) { return invite }
        }
        return nil
    }

    /// A link in a sentence often ends in a full stop, comma or bracket
    private static func trimmedEnd(_ text: String) -> String {
        var result = text
        while let last = result.last, ".,;:!?)>\"'".contains(last) {
            result = String(result.dropLast())
        }
        return result
    }

    /// The page of viewers
    public func viewerLink(baseURL: String) -> String { baseURL + "/t/" + id }
}

// MARK: - Een partij van en naar de live-pagina

public extension TeamPartij {
    /// The partij for the live page: home player first, only games with a
    /// score listed (the rest is in `gamesWon`). Nil without any games.
    func livePayload(in match: TeamMatch) -> TeamLivePartij? {
        guard hasEntry else { return nil }
        let homeIsOwn = match.ownSide == TeamSide.home
        var scored: [[Int]] = []
        for game in games {
            if let own = game.ownPoints, let their = game.theirPoints {
                scored.append(homeIsOwn ? [own, their] : [their, own])
            }
        }
        let ownName = LiveSnapshot.firstName(ownPlayer, fallback: "")
        let theirName = LiveSnapshot.firstName(opponentPlayer, fallback: "")
        let homeGames = homeIsOwn ? ownGames : theirGames
        let awayGames = homeIsOwn ? theirGames : ownGames
        var winner: Int? = nil
        if let won = ownWon { winner = (won == homeIsOwn) ? 1 : 2 }
        return TeamLivePartij(p1: homeIsOwn ? ownName : theirName, p2: homeIsOwn ? theirName : ownName,
                              bestOf: bestOf, games: scored, score: [0, 0], gamesWon: [homeGames, awayGames],
                              server: 1, side: "R", status: isOver ? LiveStatus.finished : LiveStatus.between,
                              winner: winner)
    }

    /// A partij from the live page, seen from our team; nil when it holds nothing yet
    static func fromLive(_ live: TeamLivePartij, slot: Int, ownIsHome: Bool) -> TeamPartij? {
        if live.gamesWon.count < 2 { return nil }
        let total = live.gamesWon[0] + live.gamesWon[1]
        if total == 0 && live.games.isEmpty { return nil }
        // Another phone (or a bad copy of the app) must not make a partij
        // "7-0" or put more games on it than it takes to decide it
        let bestOf = live.bestOf >= 1 && live.bestOf <= 7 ? live.bestOf : 5
        let toWin = MatchStand.gamesToWin(bestOf: bestOf)
        let homeWon = max(0, min(live.gamesWon[0], toWin))
        var awayWon = max(0, min(live.gamesWon[1], toWin))
        if homeWon == toWin && awayWon == toWin { awayWon = toWin - 1 }
        var games: [TeamGame] = []
        var homeWonScored = 0
        var awayWonScored = 0
        for game in live.games {
            if game.count < 2 { continue }
            // The partij was decided at the games to win: nothing after that counts
            if homeWonScored >= toWin || awayWonScored >= toWin { break }
            let home = game[0]
            let away = game[1]
            if home > away { homeWonScored += 1 } else { awayWonScored += 1 }
            games.append(TeamGame(own: ownIsHome ? home : away, their: ownIsHome ? away : home))
        }
        // Games without a known score: only who won them is known
        let homeUnscored = max(0, homeWon - homeWonScored)
        let awayUnscored = max(0, awayWon - awayWonScored)
        for _ in 0..<homeUnscored { games.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: ownIsHome)) }
        for _ in 0..<awayUnscored { games.append(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: !ownIsHome)) }
        var partij = TeamPartij(slot: slot, ownPlayer: ownIsHome ? live.p1 : live.p2,
                                opponentPlayer: ownIsHome ? live.p2 : live.p1, games: games, bestOf: bestOf)
        partij.fromLive = true
        return partij
    }
}

public extension TeamMatch {
    /// Takes in the partijen other phones put on the live page: slots that are
    /// empty here, and slots that came from the live page earlier (they follow
    /// the page until someone edits them here). Returns whether anything changed.
    mutating func mergeLive(_ state: TeamLiveState) -> Bool {
        var changed = false
        for index in 0..<partijen.count {
            let current = partijen[index]
            guard !current.hasEntry || current.fromLive == true else { continue }
            guard let live = state.partijen[String(current.slot)],
                  var incoming = TeamPartij.fromLive(live, slot: current.slot, ownIsHome: ownSide == TeamSide.home) else { continue }
            incoming.playOrder = current.playOrder
            if incoming != current {
                partijen[index] = incoming
                changed = true
            }
        }
        if changed { updatedAt = Date() }
        return changed
    }

    /// A local copy of a live team match someone invited us to
    static func joining(_ state: TeamLiveState, invite: TeamInvite, ownSide: TeamSide) -> TeamMatch {
        var match = TeamMatch(date: Date(timeIntervalSince1970: Double(state.team.date) / 1000.0), home: state.team.home,
                              away: state.team.away, ownSide: ownSide, liveId: invite.id, liveKey: invite.key)
        _ = match.mergeLive(state)
        return match
    }
}

// MARK: - De service

public enum TeamLiveError: Error, Equatable {
    case noTransport
    case noConnection
    case refused(status: Int)
    /// The live team match is gone (two hours after the last update, or stopped)
    case gone
    /// The server does not know this key: a mistyped invitation, or one for another evening
    case keyRejected
}

/// The live side of Competitie on this phone. It uses the transport and the
/// server address of `LiveShare` (the app sets them once at start).
@MainActor
@Observable
public final class TeamLive {
    public static let shared = TeamLive()

    private struct Binding {
        let teamId: String
        let key: String
        let slot: Int
        let homeIsPlayer1: Bool
        let homeLabel: String
        let awayLabel: String
    }

    /// Set by tests; otherwise the transport of `LiveShare`
    public var transport: (any LiveTransport)? = nil
    private var customBaseURL: String? = nil
    public var baseURL: String {
        get { customBaseURL ?? LiveShare.shared.baseURL }
        set { customBaseURL = newValue }
    }

    /// A send failed (no network); the next point tries again
    public private(set) var offline = false
    /// Live team matches whose key the server refused (401) at the last send:
    /// the partij does not reach the page, the invitation is wrong or old
    public private(set) var rejectedTeamIds: [String] = []

    public func isRejected(_ teamId: String) -> Bool { rejectedTeamIds.contains(teamId) }

    private var bindings: [UUID: Binding] = [:]
    private var pending: [String: TeamLivePartij] = [:]
    private var sending: [String: Bool] = [:]

    public init(transport: (any LiveTransport)? = nil) {
        self.transport = transport
    }

    private var activeTransport: (any LiveTransport)? { transport ?? LiveShare.shared.transport }

    // MARK: Een bijgehouden wedstrijd voor een partij

    /// The tracked match `matchId` is played for slot `slot` of a live team
    /// match: every change of its state also goes to that partij
    public func bind(matchId: UUID, teamId: String, writeKey: String, slot: Int,
                     homeIsPlayer1: Bool, homeLabel: String, awayLabel: String) {
        bindings[matchId] = Binding(teamId: teamId, key: writeKey, slot: slot, homeIsPlayer1: homeIsPlayer1,
                                    homeLabel: homeLabel, awayLabel: awayLabel)
    }

    public func unbind(matchId: UUID) {
        bindings[matchId] = nil
    }

    public func isBound(_ matchId: UUID) -> Bool { bindings[matchId] != nil }

    /// Called with every new state of a tracked match (nothing when it is not bound)
    public func forward(matchId: UUID, snapshot: LiveSnapshot) {
        guard let binding = bindings[matchId] else { return }
        let partij = TeamLivePartij(snapshot: snapshot, homeIsPlayer1: binding.homeIsPlayer1,
                                    homeLabel: binding.homeLabel, awayLabel: binding.awayLabel)
        let key = binding.teamId + "/" + String(binding.slot)
        pending[key] = partij
        if sending[key] == true { return }
        Task { await self.flush(binding, key: key) }
    }

    /// Sends the newest state; pile-ups are merged, a failed send is kept for the next point
    private func flush(_ binding: Binding, key: String) async {
        if sending[key] == true { return }
        sending[key] = true
        while let next = pending[key] {
            pending[key] = nil
            let result = await put(next, teamId: binding.teamId, slot: binding.slot, writeKey: binding.key)
            if !result {
                if pending[key] == nil { pending[key] = next }
                break
            }
        }
        sending[key] = false
    }

    // MARK: De teamwedstrijd

    /// Starts the live page for this team match
    public func create(_ match: TeamMatch) async throws -> TeamLiveCreated {
        guard let transport = activeTransport else { throw TeamLiveError.noTransport }
        guard let url = URL(string: "\(baseURL)/api/team") else { throw TeamLiveError.noConnection }
        let header = TeamLiveHeader(home: match.home, away: match.away, date: Int64(match.date.timeIntervalSince1970 * 1000.0))
        let body = try JSONEncoder().encode(header)
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "POST", url: url, headers: ["Content-Type": "application/json"], body: body)
        } catch {
            throw TeamLiveError.noConnection
        }
        guard response.status == 201, let created = try? JSONDecoder().decode(TeamLiveCreated.self, from: response.body) else {
            throw TeamLiveError.refused(status: response.status)
        }
        return created
    }

    /// Puts one partij of this phone on the live page (a hand-filled result or
    /// the final result of a tracked match). False when not live or not sent.
    public func push(_ partij: TeamPartij, in match: TeamMatch) async -> Bool {
        guard let id = match.liveId, let key = match.liveKey else { return false }
        if let payload = partij.livePayload(in: match) {
            return await put(payload, teamId: id, slot: partij.slot, writeKey: key)
        }
        return true
    }

    /// Every partij with games, e.g. right after "Live delen"
    public func pushAll(_ match: TeamMatch) async {
        for partij in match.partijen where partij.hasEntry && partij.fromLive != true {
            _ = await push(partij, in: match)
        }
    }

    /// The live page as it is now; throws `.gone` when it no longer exists
    public func fetch(id: String) async throws -> TeamLiveState {
        guard let transport = activeTransport else { throw TeamLiveError.noTransport }
        guard let url = URL(string: "\(baseURL)/api/team/\(id)") else { throw TeamLiveError.noConnection }
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "GET", url: url, headers: [:], body: nil)
        } catch {
            throw TeamLiveError.noConnection
        }
        if response.status == 404 { throw TeamLiveError.gone }
        guard response.status == 200, let state = try? JSONDecoder().decode(TeamLiveState.self, from: response.body) else {
            throw TeamLiveError.refused(status: response.status)
        }
        return state
    }

    /// Whether this key works for the live page, and what it may do. Throws
    /// `.gone` (unknown or ended), `.keyRejected` (wrong key) or a connection error.
    public func verify(id: String, key: String) async throws -> TeamLiveRole {
        guard let transport = activeTransport else { throw TeamLiveError.noTransport }
        guard let url = URL(string: "\(baseURL)/api/team/\(id)/verify") else { throw TeamLiveError.noConnection }
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "GET", url: url, headers: ["Authorization": "Bearer \(key)"], body: nil)
        } catch {
            throw TeamLiveError.noConnection
        }
        if response.status == 404 { throw TeamLiveError.gone }
        if response.status == 401 { throw TeamLiveError.keyRejected }
        guard response.status == 200, let answer = try? JSONDecoder().decode(TeamLiveRoleAnswer.self, from: response.body) else {
            throw TeamLiveError.refused(status: response.status)
        }
        return answer.role
    }

    /// Takes a partij off the live page (it was emptied or unlinked here)
    public func clear(slot: Int, in match: TeamMatch) async -> Bool {
        guard let id = match.liveId, let key = match.liveKey, let transport = activeTransport,
              let url = URL(string: "\(baseURL)/api/team/\(id)/partij/\(slot)"),
              let body = try? JSONEncoder().encode(TeamLiveEmpty(empty: true)) else { return false }
        do {
            let response = try await transport.send(method: "PUT", url: url,
                                                    headers: ["Content-Type": "application/json", "Authorization": "Bearer \(key)"],
                                                    body: body)
            noteResult(response.status, teamId: id)
            return response.status >= 200 && response.status < 300
        } catch {
            offline = true
            return false
        }
    }

    /// Back in the app (or the network is back): what could not be sent is sent now
    public func retryPending() {
        for (key, _) in pending where sending[key] != true {
            // key is "<teamId>/<slot>"; the binding that wrote it holds the rest
            for (_, binding) in bindings where binding.teamId + "/" + String(binding.slot) == key {
                Task { await self.flush(binding, key: key) }
                break
            }
        }
    }

    /// Stops the live page: gone at once. Only the phone that started it (the
    /// owner key) can; a phone that joined just leaves it locally.
    public func stop(_ match: TeamMatch) async {
        guard let id = match.liveId, let key = match.liveOwnerKey ?? match.liveKey, let transport = activeTransport,
              let url = URL(string: "\(baseURL)/api/team/\(id)") else { return }
        _ = try? await transport.send(method: "DELETE", url: url, headers: ["Authorization": "Bearer \(key)"], body: nil)
    }

    private func put(_ partij: TeamLivePartij, teamId: String, slot: Int, writeKey: String) async -> Bool {
        guard let transport = activeTransport, let url = URL(string: "\(baseURL)/api/team/\(teamId)/partij/\(slot)"),
              let body = try? JSONEncoder().encode(partij) else { return false }
        do {
            let response = try await transport.send(method: "PUT", url: url,
                                                    headers: ["Content-Type": "application/json", "Authorization": "Bearer \(writeKey)"],
                                                    body: body)
            noteResult(response.status, teamId: teamId)
            return response.status >= 200 && response.status < 300
        } catch {
            offline = true
            return false
        }
    }

    /// What the server answered to a send: offline for a failure that may pass,
    /// a refused key (401) shown separately, a page that is gone not a connection problem
    private func noteResult(_ status: Int, teamId: String) {
        let ok = status >= 200 && status < 300
        offline = !ok && status != 404 && status != 401
        if status == 401 {
            if !rejectedTeamIds.contains(teamId) { rejectedTeamIds.append(teamId) }
        } else if ok {
            rejectedTeamIds = rejectedTeamIds.filter { id in id != teamId }
        }
    }
}
