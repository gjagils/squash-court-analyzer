import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// The player names of a team match on the live page and the lock screen
final class LiveNamesTests: XCTestCase {
    let team = ["Paul Steenks", "Paul van Rijn", "Niels de Groot", "Niels Sevenhoven",
                "Gerd-Jan van Gils", "Gerd-Jan Pieterse", "Bas Jansen"]

    func testASharedFirstNameGetsTheSurnameLetter() {
        XCTAssertEqual(LiveNames.label("Paul Steenks", among: team), "Paul S")
        XCTAssertEqual(LiveNames.label("Paul van Rijn", among: team), "Paul R")
        XCTAssertEqual(LiveNames.label("Niels de Groot", among: team), "Niels G")
        XCTAssertEqual(LiveNames.label("Niels Sevenhoven", among: team), "Niels S")
        XCTAssertEqual(LiveNames.label("Gerd-Jan van Gils", among: team), "Gerd-Jan G")
        XCTAssertEqual(LiveNames.label("Gerd-Jan Pieterse", among: team), "Gerd-Jan P")
    }

    func testAUniqueFirstNameStaysAlone() {
        XCTAssertEqual(LiveNames.label("Bas Jansen", among: team), "Bas")
        XCTAssertEqual(LiveNames.label("Tim de Vries", among: team), "Tim")
        // Only a first name known: nothing to add
        XCTAssertEqual(LiveNames.label("Paul", among: team), "Paul")
        XCTAssertEqual(LiveNames.label("", among: team), "")
    }

    func testEqualFirstLettersTakeTwo() {
        let known = ["Paul Visser", "Paul Vos"]
        XCTAssertEqual(LiveNames.label("Paul Visser", among: known), "Paul Vi")
        XCTAssertEqual(LiveNames.label("Paul Vos", among: known), "Paul Vo")
    }

    func testTheTeamMatchAndMijnTeamCount() {
        var match = TeamMatch(date: Date(), home: "All Inn Squash 8", away: "Squash Delft 8", ownSide: TeamSide.home)
        var partij = match.partij(1)
        partij.ownPlayer = "Niels de Groot"
        match.update(partij)
        // Niels S is not playing, but he is in Mijn team: still "Niels G"
        let roster = LeagueTeamSnapshot(source: URL(string: "https://sbn.toernooi.nl/")!, name: "All Inn Squash 8",
                                        competition: "SBN", division: "1e klasse", rank: nil, played: nil, points: nil,
                                        fixtures: [LeagueFixture](), players: [
                                            LeaguePlayer(id: "1", name: "Niels de Groot", record: ""),
                                            LeaguePlayer(id: "2", name: "Niels Sevenhoven", record: ""),
                                        ])
        XCTAssertEqual(LiveNames.label("Niels de Groot", among: LiveNames.known(in: match, team: roster)), "Niels G")
        XCTAssertEqual(LiveNames.label("Niels de Groot", among: LiveNames.known(in: match, team: nil)), "Niels")
    }
}
