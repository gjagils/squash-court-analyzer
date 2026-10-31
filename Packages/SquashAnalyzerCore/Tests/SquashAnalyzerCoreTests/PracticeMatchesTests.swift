import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Oefenpartij (backlog C8): a practice match earns no badges, is left out of
// the career history and the profile trend, and travels in the full backup.
final class PracticeMatchesTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("practice-\(UUID().uuidString)")
        PracticeMatches.shared.configure(directory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        PracticeMatches.shared.configure(directory: FileManager.default.temporaryDirectory.appendingPathComponent("practice-none-\(UUID().uuidString)"))
        super.tearDown()
    }

    /// Player 1 wins every rally of a best of 3: plenty of badges for an ordinary match
    private func oneSidedInput(practice: Bool) -> BadgeMatchInput {
        let game = BadgeGame(rallies: Array(repeating: BadgeRally(winner: .player1), count: 11), winner: .player1)
        return BadgeMatchInput(games: [game, game], player1GamesWon: 2, matchWinner: .player1, gamesToWin: 2, isPractice: practice)
    }

    func testAPracticeMatchEarnsNoBadges() {
        XCTAssertFalse(BadgeEngine().badges(for: oneSidedInput(practice: false)).isEmpty)
        XCTAssertTrue(BadgeEngine().badges(for: oneSidedInput(practice: true)).isEmpty)
    }

    func testTheMarkIsSavedAndReadBack() {
        let id = UUID()
        XCTAssertFalse(PracticeMatches.shared.contains(id))
        PracticeMatches.shared.set(true, for: id)
        XCTAssertTrue(PracticeMatches.shared.contains(id))
        XCTAssertTrue(PracticeMatches.shared.contains(id: id.uuidString.lowercased()))
        let other = PracticeMatches()
        other.configure(directory: directory)
        XCTAssertTrue(other.contains(id))
        PracticeMatches.shared.set(false, for: id)
        XCTAssertFalse(PracticeMatches.shared.contains(id))
    }

    func testAMatchBadgeInputCarriesTheMark() {
        let match = Match()
        XCTAssertFalse(match.badgeInput.isPractice)
        PracticeMatches.shared.set(true, for: match.id)
        XCTAssertTrue(match.badgeInput.isPractice)
        let referee = RefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, startingServer: .player1)
        PracticeMatches.shared.set(true, for: referee.id)
        XCTAssertTrue(referee.badgeInput.isPractice)
    }

    func testPracticeIsLeftOutOfTheCareerHistory() {
        // Three wins in a row would be a hat trick; the middle one is practice
        let start = BadgeSeason.start ?? Date(timeIntervalSince1970: 0)
        let ids = [UUID(), UUID(), UUID()]
        var history: [BadgeEngine.CareerMatch] = []
        for (index, id) in ids.enumerated() {
            history.append(BadgeEngine.CareerMatch(matchId: id, date: start.addingTimeInterval(Double(index + 1) * 86_400.0), won: true,
                                                   pointsWon: 33, opponentKey: "x\(index)"))
        }
        let withAll = BadgeEngine().careerBadges(in: ids[2], history: history, earnedElsewhere: [])
        PracticeMatches.shared.set(true, for: ids[1])
        let withoutPractice = BadgeEngine().careerBadges(in: ids[2], history: history, earnedElsewhere: [])
        XCTAssertNotEqual(withAll, withoutPractice)
        XCTAssertTrue(BadgeEngine().careerBadges(in: ids[1], history: history, earnedElsewhere: []).isEmpty)
    }

    func testTheBackupCarriesAndRestoresTheMarks() throws {
        let id = UUID()
        PracticeMatches.shared.set(true, for: id)
        let backup = TeamBackup.attach(FullBackup(version: 4, backupDate: Date(), players: [], matches: [], standaloneGames: []), directory: directory)
        XCTAssertEqual(backup.practiceMatchIds, [id.uuidString.uppercased()])
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(FullBackup.self, from: data)

        PracticeMatches.shared.set(false, for: id)
        try TeamBackup.restore(decoded, directory: directory, replacing: false)
        XCTAssertTrue(PracticeMatches.shared.contains(id))
    }
}
