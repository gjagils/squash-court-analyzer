import XCTest
@testable import SquashAnalyzer
import SquashAnalyzerCore

/// Live score op het vergrendelscherm: what the Live Activity shows, worked
/// out from the server's snapshot JSON
final class LiveScoreAttributesTests: XCTestCase {
    private typealias State = LiveScoreAttributes.ContentState

    private func state(games: [[Int]] = [], score: [Int], gamesWon: [Int], status: String = "playing",
                       server: Int = 1, side: String = "R", winner: Int? = nil, bestOf: Int = 5) -> State {
        State(p1: "Jan", p2: "Piet", bestOf: bestOf, games: games, score: score, gamesWon: gamesWon,
              server: server, side: side, status: status, lastPoint: nil, winner: winner)
    }

    func testDecodesTheServerSnapshotIncludingUnknownFields() throws {
        let json = """
        {"p1":"Jan","p2":"Piet","bestOf":5,"games":[[11,8]],"score":[3,2],"gamesWon":[1,0],"server":2,"side":"L","status":"playing","lastPoint":null,"extra":1}
        """
        let decoded = try JSONDecoder().decode(State.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.score, [3, 2])
        XCTAssertEqual(decoded.server, 2)
        XCTAssertNil(decoded.winner)
        XCTAssertEqual(decoded.gameNumber, 2)
        XCTAssertEqual(decoded.headerTitle, "Live · Game 2")
        XCTAssertEqual(decoded.footerLeading, "Games 11–8")
        XCTAssertEqual(decoded.footerTrailing, "Opslag links")
    }

    func testTheContentStateMatchesTheSnapshotFieldByField() throws {
        // The app makes the state from Core's LiveSnapshot; the server pushes the snapshot JSON itself
        let snapshot = LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 3, games: [[11, 9]], score: [4, 6], gamesWon: [1, 0],
                                    server: 2, side: "L", status: .playing, lastPoint: "Piet: Winner", winner: nil)
        let fromApp = ActivityKitLiveFollowPresenter.contentState(snapshot)
        let fromServer = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(fromApp, fromServer)
    }

    func testGameBallAndMatchBall() {
        XCTAssertNil(state(score: [9, 7], gamesWon: [0, 0]).badge)
        XCTAssertEqual(state(score: [10, 7], gamesWon: [0, 0]).badge, .gameBall)
        XCTAssertEqual(state(score: [10, 7], gamesWon: [0, 0]).gameBallPlayer, 1)
        // 10–10: nobody can win with the next rally
        XCTAssertNil(state(score: [10, 10], gamesWon: [1, 1]).badge)
        XCTAssertEqual(state(score: [11, 12], gamesWon: [1, 1]).gameBallPlayer, 2)
        // Player 1 has two games in a best of 5
        XCTAssertEqual(state(score: [10, 9], gamesWon: [2, 1]).badge, .matchBall)
        // Player 2's game ball in the same match is only a game ball
        XCTAssertEqual(state(score: [9, 10], gamesWon: [2, 1]).badge, .gameBall)
    }

    func testBreakShowsTheLastGameAndPause() {
        let between = state(games: [[11, 8], [6, 11]], score: [0, 0], gamesWon: [1, 1], status: "between")
        XCTAssertEqual(between.badge, .pause)
        XCTAssertEqual(between.shownScore(1), 6)
        XCTAssertEqual(between.shownScore(2), 11)
        XCTAssertEqual(between.gameNumber, 2)
        XCTAssertEqual(between.footerLeading, "Game 3 begint zo")
        XCTAssertEqual(between.footerTrailing, "")
        XCTAssertFalse(between.isServing(1))
    }

    func testFinishedShowsGamesWonAndTheWinner() {
        let done = state(games: [[11, 8], [6, 11], [11, 9], [11, 5]], score: [11, 5], gamesWon: [3, 1],
                         status: "finished", winner: 1)
        XCTAssertEqual(done.badge, .finished)
        XCTAssertEqual(done.headerTitle, "Uitslag · Jan wint")
        XCTAssertEqual(done.shownScore(1), 3)
        XCTAssertEqual(done.shownScore(2), 1)
        XCTAssertEqual(done.footerLeading, "11–8 · 6–11 · 11–9 · 11–5")
        XCTAssertEqual(done.minimalText, "3·1")
        XCTAssertEqual(done.pips(1), 3)
    }

    func testWarmupAndUnknownStatus() {
        let warmup = state(score: [0, 0], gamesWon: [0, 0], status: "warmup", side: "L")
        XCTAssertEqual(warmup.headerTitle, "Live · Warming-up")
        XCTAssertTrue(warmup.isServing(1))
        XCTAssertEqual(warmup.islandLine, "Warming-up")
        // A status from a newer server reads as playing
        let unknown = state(score: [2, 1], gamesWon: [0, 0], status: "paused")
        XCTAssertTrue(unknown.isPlaying)
        XCTAssertEqual(unknown.headerTitle, "Live · Game 1")
    }

    func testIslandLineAndPipsWithHeadStart() {
        let playing = state(games: [[11, 8], [6, 11]], score: [9, 7], gamesWon: [1, 1])
        XCTAssertEqual(playing.islandLine, "Game 3 · 11–8 · 6–11")
        XCTAssertEqual(playing.minimalText, "9·7")
        // A head start counts as games won without a game in the list
        let headStart = state(games: [], score: [4, 2], gamesWon: [1, 0], bestOf: 3)
        XCTAssertEqual(headStart.gameNumber, 2)
        XCTAssertEqual(headStart.pips(1), 1)
        XCTAssertEqual(headStart.gamesToWin, 2)
    }
}
