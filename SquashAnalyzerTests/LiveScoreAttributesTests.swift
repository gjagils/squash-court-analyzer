import XCTest
import UIKit
@testable import SquashAnalyzer
import SquashAnalyzerCore

/// Live score op het vergrendelscherm: what the Live Activity shows, worked
/// out from the server's snapshot JSON (the look of the viewer page's ticker)
final class LiveScoreAttributesTests: XCTestCase {
    // The assertions are in Dutch; the lock screen follows the phone's language
    override func setUp() {
        super.setUp()
        WidgetLanguage.forced = "nl"
    }

    override func tearDown() {
        WidgetLanguage.forced = nil
        super.tearDown()
    }

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
        XCTAssertEqual(decoded.statusLine, "Game 2 · best of 5")
        XCTAssertNil(decoded.serveLine(1))
        XCTAssertEqual(decoded.serveLine(2), "serveert links")
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
        XCTAssertEqual(state(score: [10, 7], gamesWon: [0, 0]).ballBadge, .gameBall)
        XCTAssertEqual(state(score: [10, 7], gamesWon: [0, 0]).gameBallPlayer, 1)
        // 10–10: nobody can win with the next rally
        XCTAssertNil(state(score: [10, 10], gamesWon: [1, 1]).badge)
        XCTAssertEqual(state(score: [11, 12], gamesWon: [1, 1]).gameBallPlayer, 2)
        // Player 1 has two games in a best of 5
        XCTAssertEqual(state(score: [10, 9], gamesWon: [2, 1]).badge, .matchBall)
        // Player 2's game ball in the same match is only a game ball
        XCTAssertEqual(state(score: [9, 10], gamesWon: [2, 1]).badge, .gameBall)
    }

    func testBreakShowsPauseAndNoServer() {
        let between = state(games: [[11, 8], [6, 11]], score: [0, 0], gamesWon: [1, 1], status: "between")
        XCTAssertEqual(between.badge, .pause)
        // The pause is in the status line, not as a badge next to it
        XCTAssertNil(between.ballBadge)
        XCTAssertEqual(between.statusLine, "Pauze")
        XCTAssertEqual(between.points(1), 0)
        XCTAssertEqual(between.games(2), 1)
        XCTAssertEqual(between.islandScore(1), 1)
        XCTAssertEqual(between.minimalText, "1·1")
        XCTAssertFalse(between.isServing(1))
        XCTAssertNil(between.serveLine(1))
    }

    func testFinishedShowsTheWinnerAndTheChips() {
        let done = state(games: [[11, 8], [6, 11], [11, 9], [11, 5]], score: [11, 5], gamesWon: [3, 1],
                         status: "finished", winner: 1)
        XCTAssertEqual(done.badge, .finished)
        XCTAssertNil(done.ballBadge)
        XCTAssertEqual(done.statusLine, "Jan wint 3-1")
        XCTAssertEqual(done.points(1), 11)
        XCTAssertEqual(done.games(1), 3)
        XCTAssertEqual(done.minimalText, "3·1")
        XCTAssertEqual(done.gameChips.map { chip in chip.text }, ["11-8", "6-11", "11-9", "11-5"])
        XCTAssertEqual(done.gameChips.map { chip in chip.winner }, [1, 2, 1, 1])
        let shutOut = state(games: [[8, 11], [9, 11]], score: [9, 11], gamesWon: [0, 2], status: "finished", winner: 2, bestOf: 3)
        XCTAssertEqual(shutOut.statusLine, "Piet wint 2-0")
    }

    func testWarmupAndUnknownStatus() {
        let warmup = state(score: [0, 0], gamesWon: [0, 0], status: "warmup", side: "L")
        XCTAssertEqual(warmup.statusLine, "Inspelen")
        XCTAssertTrue(warmup.isServing(1))
        XCTAssertEqual(warmup.serveLine(1), "serveert links")
        // A status from a newer server reads as playing
        let unknown = state(score: [2, 1], gamesWon: [0, 0], status: "paused")
        XCTAssertTrue(unknown.isPlaying)
        XCTAssertEqual(unknown.statusLine, "Game 1 · best of 5")
    }

    func testScoresAndInitialsWithHeadStart() {
        let playing = state(games: [[11, 8], [6, 11]], score: [9, 7], gamesWon: [1, 1])
        XCTAssertEqual(playing.minimalText, "9·7")
        XCTAssertEqual(playing.islandScore(2), 7)
        XCTAssertEqual(playing.serveLine(1), "serveert rechts")
        XCTAssertEqual(playing.initial(1), "J")
        // A head start counts as games won without a game in the list
        let headStart = state(games: [], score: [4, 2], gamesWon: [1, 0], bestOf: 3)
        XCTAssertEqual(headStart.gameNumber, 2)
        XCTAssertEqual(headStart.games(1), 1)
        XCTAssertTrue(headStart.gameChips.isEmpty)
        XCTAssertEqual(headStart.statusLine, "Game 2 · best of 3")
        var nameless = headStart
        nameless.p2 = "  "
        XCTAssertEqual(nameless.initial(2), "?")
    }

    func testPhotoFilesAreNamedByMatchAndCleanedUp() throws {
        guard LiveScorePhotoStore.directory != nil else { throw XCTSkip("No App Group container") }
        let id = "test-" + String(UUID().uuidString.prefix(8))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200))
        let jpeg = renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        }
        XCTAssertTrue(LiveScorePhotoStore.store(jpeg, matchId: id, player: 1))
        XCTAssertFalse(LiveScorePhotoStore.store(nil, matchId: id, player: 2))
        let image = try XCTUnwrap(LiveScorePhotoStore.image(matchId: id, player: 1))
        // A small square for the widget
        XCTAssertEqual(image.size.width * image.scale, 96)
        XCTAssertEqual(image.size.height * image.scale, 96)
        XCTAssertNil(LiveScorePhotoStore.image(matchId: id, player: 2))
        XCTAssertEqual(LiveScorePhotoStore.url(matchId: id, player: 1)?.lastPathComponent, id + "-1.jpg")
        // Kept while its activity is shown, removed afterwards
        LiveScorePhotoStore.removeAll(except: [id])
        XCTAssertNotNil(LiveScorePhotoStore.image(matchId: id, player: 1))
        LiveScorePhotoStore.removeAll(except: [])
        XCTAssertNil(LiveScorePhotoStore.image(matchId: id, player: 1))
    }
}
