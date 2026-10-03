import Foundation

/// Pure squash scoring rules. Keeping these rules out of SwiftUI and SwiftData
/// makes them deterministic and easy to unit test.
public struct SquashScore: Equatable {
    public var player1: Int
    public var player2: Int

    public init(player1: Int = 0, player2: Int = 0) {
        self.player1 = player1
        self.player2 = player2
    }
}

public struct ScoringEngine {
    public init() {}

    public func score(afterPointFor player: Player, from score: SquashScore) -> SquashScore {
        var result = score
        if player == .player1 {
            result.player1 += 1
        } else {
            result.player2 += 1
        }
        return result
    }

    public func isGameOver(_ score: SquashScore) -> Bool {
        let high = max(score.player1, score.player2)
        let low = min(score.player1, score.player2)
        return high >= 11 && high - low >= 2
    }

    public func winner(for score: SquashScore) -> Player? {
        guard isGameOver(score) else { return nil }
        return score.player1 > score.player2 ? .player1 : .player2
    }
}

/// Who serves and from which box
public struct ServiceState: Equatable {
    public var server: Player
    public var side: ServerSide

    public init(server: Player, side: ServerSide) {
        self.server = server
        self.side = side
    }
}

/// The service rule, once for coach (`Game`) and referee (`RefereeMatch`)
extension ScoringEngine {
    /// The server who wins a rally keeps serving from the other box; on a
    /// hand-out the new server starts from `handOutSide` (their preferred box,
    /// right unless Links/Rechts was tapped for them earlier)
    public func service(afterRallyWonBy scorer: Player, from state: ServiceState, handOutSide: ServerSide) -> ServiceState {
        if scorer == state.server {
            return ServiceState(server: state.server, side: state.side.opposite)
        }
        return ServiceState(server: scorer, side: handOutSide)
    }

    /// The service state after these rallies, played from `opening`: how a game
    /// restored from the store gets its server and box back
    public func service(replaying scorers: [Player], from opening: ServiceState,
                        handOutSide: (Player) -> ServerSide) -> ServiceState {
        var state = opening
        for scorer in scorers {
            state = service(afterRallyWonBy: scorer, from: state, handOutSide: handOutSide(scorer))
        }
        return state
    }
}

/// Games needed, end of the match and the winner, once for coach, referee and history
public struct MatchStand: Equatable {
    public let bestOf: Int
    public let player1Games: Int
    public let player2Games: Int

    public init(bestOf: Int, player1Games: Int, player2Games: Int) {
        self.bestOf = bestOf
        self.player1Games = player1Games
        self.player2Games = player2Games
    }

    public static func gamesToWin(bestOf: Int) -> Int { bestOf / 2 + 1 }

    public var gamesToWin: Int { MatchStand.gamesToWin(bestOf: bestOf) }
    public var isOver: Bool { player1Games >= gamesToWin || player2Games >= gamesToWin }

    public var winner: Player? {
        guard isOver else { return nil }
        return player1Games > player2Games ? Player.player1 : Player.player2
    }
}
