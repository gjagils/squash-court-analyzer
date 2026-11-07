import XCTest
import Foundation
@testable import SquashAnalyzerCore

final class SamplePlayerCleanupTests: XCTestCase {
    private func names(_ players: [PlayerProfile]) -> [String] {
        var result: [String] = []
        for player in players { result.append(player.name) }
        return result
    }

    func testOnlyTheExamplePlayersAreOffered() {
        let players = [PlayerProfile(name: "Bob"), PlayerProfile(name: " wim "), PlayerProfile(name: "Bombardino"),
                       PlayerProfile(name: "WHISKEY"), PlayerProfile(name: "Bob de Vries"), PlayerProfile(name: "Anna")]
        XCTAssertEqual(names(SamplePlayerCleanup.found(in: players, team: [])), ["Bob", " wim ", "Bombardino", "WHISKEY"])
    }

    func testAPlayerInMyTeamIsAPersonNotAnExample() {
        let wim = PlayerProfile(name: "Wim")
        let bob = PlayerProfile(name: "Bob")
        XCTAssertEqual(names(SamplePlayerCleanup.found(in: [wim, bob], team: [wim.id.uppercased()])), ["Bob"])
        XCTAssertTrue(SamplePlayerCleanup.found(in: [], team: []).isEmpty)
    }
}
