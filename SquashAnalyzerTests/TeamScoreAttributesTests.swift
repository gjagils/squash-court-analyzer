import XCTest
@testable import SquashAnalyzer
import SquashAnalyzerCore

/// Live score op het vergrendelscherm for a team match: what the Live
/// Activity shows, worked out from the server's team push
final class TeamScoreAttributesTests: XCTestCase {
    private typealias State = TeamScoreAttributes.ContentState

    private func decode(_ json: String) throws -> State {
        try JSONDecoder().decode(State.self, from: Data(json.utf8))
    }

    func testDecodesTheServerTeamPush() throws {
        let state = try decode("""
        {"home":"All Inn 8","away":"Delft 8","partijen":[
          {"slot":1,"p1":"Gerd-Jan","p2":"","bestOf":5,"gamesWon":[3,0],"score":[11,9],"status":"finished","winner":1},
          {"slot":2,"p1":"Paul","p2":"Mark","bestOf":5,"gamesWon":[1,1],"score":[7,5],"status":"playing"},
          {"slot":4,"p1":"","p2":"Kees","bestOf":5,"gamesWon":[0,0],"score":[0,0],"status":"warmup"}]}
        """)
        XCTAssertEqual(state.games(1), 4)
        XCTAssertEqual(state.games(2), 1)
        XCTAssertEqual(state.progressText, "1 van 4 klaar")
        XCTAssertFalse(state.isFinished)
        XCTAssertEqual(state.middle(1), .decided)
        XCTAssertEqual(state.middle(2), .live("7–5"))
        XCTAssertEqual(state.middle(3), .none, "no partij yet")
        XCTAssertEqual(state.middle(4), .none, "warming up")
        XCTAssertEqual(state.name(slot: 1, side: 2), "Delft 8 E1")
        XCTAssertEqual(state.name(slot: 3, side: 1), "All Inn 8 E3")
        XCTAssertEqual(state.initial(slot: 2, side: 2), "M")
        XCTAssertEqual(state.initial(slot: 3, side: 1), "")
        XCTAssertEqual(state.minimalText, "4·1")
    }

    func testTheCoreStandEncodesToTheSameContentState() throws {
        let stand = TeamFollowStand(home: "A", away: "B", partijen: [
            TeamFollowPartij(slot: 2, p1: "Jan", p2: "Piet", bestOf: 5, gamesWon: [3, 1], score: [11, 4], status: "finished",
                             winner: 1, end: nil)
        ])
        let data = try JSONEncoder().encode(stand)
        let state = try JSONDecoder().decode(State.self, from: data)
        XCTAssertEqual(state, ActivityKitLiveFollowPresenter.teamContentState(stand))
        XCTAssertEqual(state.partij(2)?.winnerSide, 1)
    }

    func testTheResultFollowsPartijenFirstThenGames() throws {
        func partij(_ slot: Int, _ won: [Int], end: String? = nil) -> TeamScorePartij {
            TeamScorePartij(slot: slot, p1: "", p2: "", bestOf: 5, gamesWon: won, score: [0, 0], status: "finished",
                            winner: won[0] > won[1] ? 1 : 2, end: end)
        }
        // 2–2 in partijen, home more games
        var state = State(home: "All Inn 8", away: "Delft 8",
                          partijen: [partij(1, [3, 0]), partij(2, [3, 1]), partij(3, [2, 3]), partij(4, [1, 3])])
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.teamWinner, 1)
        XCTAssertEqual(state.resultTitle, "Uitslag: All Inn 8 wint 9–7")
        // 3–1 in partijen wins even with fewer games
        state = State(home: "All Inn 8", away: "Delft 8",
                      partijen: [partij(1, [3, 2]), partij(2, [3, 2]), partij(3, [3, 2]), partij(4, [0, 3])])
        XCTAssertEqual(state.resultTitle, "Uitslag: All Inn 8 wint 9–9")
        state = State(home: "All Inn 8", away: "Delft 8",
                      partijen: [partij(1, [0, 3]), partij(2, [0, 3]), partij(3, [3, 0]), partij(4, [0, 3])])
        XCTAssertEqual(state.resultTitle, "Uitslag: Delft 8 wint 9–3")
        // Equal partijen, the away team lost a walkover: home wins
        state = State(home: "A", away: "B",
                      partijen: [partij(1, [3, 0], end: "walkover"), partij(2, [0, 3]), partij(3, [0, 3]), partij(4, [3, 0])])
        XCTAssertEqual(state.teamWinner, 1)
    }

    func testAPartijGivenUpCountsAsDecided() throws {
        let state = try decode("""
        {"home":"A","away":"B","partijen":[
          {"slot":1,"p1":"Jan","p2":"Piet","bestOf":5,"gamesWon":[1,0],"score":[3,2],"status":"playing","end":"retired"}]}
        """)
        XCTAssertEqual(state.middle(1), .decided)
        XCTAssertEqual(state.decidedCount, 1)
        XCTAssertEqual(state.partij(1)?.winnerSide, 1)
    }
}
