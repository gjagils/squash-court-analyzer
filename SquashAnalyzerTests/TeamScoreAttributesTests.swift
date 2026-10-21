import XCTest
@testable import SquashAnalyzer
import SquashAnalyzerCore

/// Live score op het vergrendelscherm for a team match: what the Live
/// Activity shows, worked out from the server's team push
final class TeamScoreAttributesTests: XCTestCase {
    // The assertions are in Dutch; the lock screen follows the phone's language
    override func setUp() {
        super.setUp()
        WidgetLanguage.forced = "nl"
    }

    override func tearDown() {
        WidgetLanguage.forced = nil
        super.tearDown()
    }

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
        XCTAssertEqual(state.middle(1), .decided(nil))
        XCTAssertEqual(state.middle(2), .live("7–5"))
        XCTAssertEqual(state.middle(3), .none, "no partij yet")
        XCTAssertEqual(state.middle(4), .none, "warming up")
        XCTAssertEqual(state.name(slot: 1, side: 2), "Delft 8 E1")
        XCTAssertEqual(state.name(slot: 3, side: 1), "All Inn 8 E3")
        XCTAssertEqual(state.initial(slot: 2, side: 2), "M")
        XCTAssertEqual(state.initial(slot: 3, side: 1), "")
        XCTAssertEqual(state.minimalText, "1·0", "partijen, not games")
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
        XCTAssertEqual(state.middle(1), .decided("opgave"))
        XCTAssertEqual(state.tile(1), .decided(winner: 1, text: "opgave"))
        XCTAssertEqual(state.decidedCount, 1)
        XCTAssertEqual(state.partij(1)?.winnerSide, 1)
    }

    // MARK: design B (20 October 2026)

    private func partij(_ slot: Int, _ won: [Int], _ score: [Int], _ status: String, winner: Int? = nil,
                        end: String? = nil, server: Int? = nil) -> TeamScorePartij {
        TeamScorePartij(slot: slot, p1: "Thuis\(slot)", p2: "Uit\(slot)", bestOf: 5, gamesWon: won, score: score,
                        status: status, winner: winner, end: end, server: server)
    }

    func testOnePartijUnderWayIsTheFocus() throws {
        let state = try decode("""
        {"home":"All Inn 8","away":"Delft 8","partijen":[
          {"slot":1,"p1":"Gerard","p2":"Thé","bestOf":5,"gamesWon":[3,0],"score":[11,4],"status":"finished","winner":1},
          {"slot":2,"p1":"Sanne","p2":"Mila","bestOf":5,"gamesWon":[1,3],"score":[8,11],"status":"finished","winner":2},
          {"slot":3,"p1":"Bas","p2":"Tim","bestOf":5,"gamesWon":[1,1],"score":[7,5],"status":"playing","server":2}]}
        """)
        guard case .live(let live) = state.focus else { return XCTFail("focus \(state.focus)") }
        XCTAssertEqual(live.map(\.slot), [3])
        XCTAssertEqual(state.focusHeading(3), "E3 · bezig")
        XCTAssertEqual(state.gamesText(3), "games 1–1")
        XCTAssertEqual(state.pointsText(live[0]), "7–5")
        XCTAssertEqual(state.partij(3)?.isServing(2), true)
        XCTAssertEqual(state.partij(3)?.isServing(1), false)
        XCTAssertEqual(state.tile(1), .decided(winner: 1, text: "3–0"))
        XCTAssertEqual(state.tile(2), .decided(winner: 2, text: "1–3"))
        XCTAssertEqual(state.tile(3), .live)
        XCTAssertEqual(state.tile(4), .waiting)
        XCTAssertEqual(state.minimalText, "1·1")
        XCTAssertEqual(state.islandStatus, "E3 7–5")
    }

    func testAPauseShowsPauzeAndNoServeDot() {
        let state = State(home: "A", away: "B", partijen: [partij(3, [1, 1], [9, 11], "between", server: 1)])
        XCTAssertEqual(state.focusHeading(3), "E3 · pauze")
        XCTAssertEqual(state.middle(3), .pause)
        XCTAssertEqual(state.partij(3)?.isServing(1), false)
        XCTAssertEqual(state.islandStatus, "E3 pauze")
        XCTAssertEqual(state.tile(3), .live)
    }

    func testTwoCourtsAtOnce() {
        let state = State(home: "A", away: "B", partijen: [
            partij(3, [1, 1], [7, 5], "playing"), partij(1, [3, 0], [11, 4], "finished", winner: 1), partij(2, [1, 0], [4, 6], "playing"),
        ])
        XCTAssertEqual(state.focus, .live([partij(2, [1, 0], [4, 6], "playing"), partij(3, [1, 1], [7, 5], "playing")]))
        XCTAssertEqual(state.islandStatus, "E2 4–6 +1")
    }

    func testBetweenPartijenTheNextOneIsShown() {
        // A partij warming up comes first
        var state = State(home: "A", away: "B", partijen: [
            partij(1, [3, 0], [11, 4], "finished", winner: 1), partij(4, [0, 0], [0, 0], "warmup"),
        ])
        XCTAssertEqual(state.focus, .next(slot: 4))
        XCTAssertEqual(state.focusHeading(4), "E4 · inspelen")
        XCTAssertEqual(state.islandStatus, "1 van 4 klaar")
        // Else the first not decided in the playing order E4, E2, E1, E3
        XCTAssertEqual(State(home: "A", away: "B", partijen: []).focus, .next(slot: 4))
        state = State(home: "A", away: "B", partijen: [partij(4, [3, 0], [11, 4], "finished", winner: 1)])
        XCTAssertEqual(state.focus, .next(slot: 2))
        XCTAssertEqual(state.focusHeading(2), "Volgende partij · E2")
        state = State(home: "A", away: "B", partijen: [
            partij(4, [3, 0], [11, 4], "finished", winner: 1), partij(2, [1, 3], [9, 11], "finished", winner: 2),
        ])
        XCTAssertEqual(state.focus, .next(slot: 1))
        state.partijen.append(partij(1, [3, 1], [11, 7], "finished", winner: 1))
        XCTAssertEqual(state.focus, .next(slot: 3))
    }

    func testAllFourDecidedShowsTheResults() {
        let state = State(home: "A", away: "B", partijen: [
            partij(1, [3, 0], [11, 4], "finished", winner: 1), partij(2, [1, 3], [8, 11], "finished", winner: 2),
            partij(3, [3, 1], [11, 6], "finished", winner: 1), partij(4, [0, 3], [0, 0], "finished", winner: 2, end: "walkover"),
        ])
        XCTAssertEqual(state.focus, .finished)
        XCTAssertEqual(state.middle(1), .decided(nil))
        XCTAssertEqual(state.middle(4), .decided("w.o."))
        XCTAssertEqual(state.tile(4), .decided(winner: 2, text: "w.o."))
        XCTAssertEqual(state.minimalText, "2·2")
        XCTAssertEqual(state.islandStatus, "Uitslag")
    }

    func testThePushWithoutServerStillDecodes() throws {
        let state = try decode("""
        {"home":"A","away":"B","partijen":[{"slot":1,"p1":"Jan","p2":"Piet","bestOf":5,"gamesWon":[0,0],"score":[1,0],"status":"playing"}]}
        """)
        XCTAssertNil(state.partij(1)?.server)
        XCTAssertEqual(state.partij(1)?.isServing(1), false)
    }

    /// Gerd-Jan's pool (21 October 2026): in full up to 16 characters, else short
    func testTeamNamesOnTheLockScreen() {
        XCTAssertEqual(TeamNameShortener.short("All Inn Squash 8"), "All Inn Squash 8")
        XCTAssertEqual(TeamNameShortener.short("All Inn Squash 9"), "All Inn Squash 9")
        XCTAssertEqual(TeamNameShortener.short("Squash Delft 5"), "Squash Delft 5")
        XCTAssertEqual(TeamNameShortener.short("Squash Delft 7"), "Squash Delft 7")
        XCTAssertEqual(TeamNameShortener.short("Squash Delft 8"), "Squash Delft 8")
        XCTAssertEqual(TeamNameShortener.short("Sluipers, RLT & SV De 1"), "Sluipers 1")
        XCTAssertEqual(TeamNameShortener.short("Sportcity Leiden 4"), "Leiden 4")
        XCTAssertEqual(TeamNameShortener.short("Squash Utrecht 11"), "Utrecht 11")
        XCTAssertEqual(TeamNameShortener.short("Sportcity Woerden 1"), "Woerden 1")
        XCTAssertEqual(TeamNameShortener.short("Sportcity Gouda 1"), "Gouda 1")
        // Never only a number: then the full name stays
        XCTAssertEqual(TeamNameShortener.short("Squash Squash Squash 1"), "Squash Squash Squash 1")
        let state = State(home: "Squash Utrecht 11", away: "Sportcity Woerden 1", partijen: [])
        XCTAssertEqual(state.teamName(1), "Utrecht 11")
        XCTAssertEqual(state.name(slot: 2, side: 2), "Woerden 1 E2")
    }
}
