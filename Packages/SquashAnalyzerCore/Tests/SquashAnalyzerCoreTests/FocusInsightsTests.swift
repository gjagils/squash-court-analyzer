import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The coaching focus against the numbers (C7): one line per focus tag
final class FocusInsightsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    /// Hugo wins 5 winners (drive, front left) in 3 s on his own serve; Jaïr
    /// wins 3 points on Hugo's unforced errors (2 down, 1 service fault) in 20 s
    private func game() -> Game {
        let game = Game()
        game.player1Name = "Hugo"
        game.player2Name = "Jaïr"
        var points: [Point] = []
        for index in 0..<5 {
            points.append(Point(scorer: Player.player1, pointType: PointType.winner, zone: CourtZone.frontLeft, shotType: ShotType.drive,
                                server: Player.player1, player1Score: index + 1, player2Score: 0, duration: 3))
        }
        let kinds = [ErrorKind.down, ErrorKind.down, ErrorKind.service]
        for index in 0..<3 {
            points.append(Point(scorer: Player.player2, pointType: PointType.unforcedError, zone: nil, shotType: nil,
                                server: Player.player1, player1Score: 5, player2Score: index + 1, duration: 20, errorKind: kinds[index]))
        }
        game.points = points
        game.player1Score = 5
        game.player2Score = 3
        return game
    }

    func testOneLinePerKnownTagInFocusOrder() {
        let insights = FocusInsights.make(in: game(), for: Player.player1, focus: ["Mentaal", "Onbekend", "Backhand", "Voorhand"])
        var tags: [CoachingFocusTag] = []
        var texts: [String] = []
        for insight in insights {
            tags.append(insight.tag)
            texts.append(insight.text)
        }
        XCTAssertEqual(tags, [CoachingFocusTag.mentaal, CoachingFocusTag.backhand, CoachingFocusTag.voorhand])
        XCTAssertEqual(texts, [
            "3 eigen fouten, 0 vanaf een stand van 8. Langste reeks verloren punten: 3.",
            "Linkerkant: 5 gewonnen, 0 verloren. Beste slag daar: drive (5).",
            "Rechterkant: nog geen punten.",
        ])
        XCTAssertEqual(insights[0].id, "Mentaal")
    }

    func testServeVolleyDropBoastAndBack() {
        let game = game()
        // One volley drop at the back right, so the volley and the back line have something
        game.points.append(Point(scorer: Player.player1, pointType: PointType.winner, zone: CourtZone.backRight, shotType: ShotType.drop,
                                 server: Player.player1, player1Score: 6, player2Score: 3, duration: 4, isVolley: true))
        let insights = FocusInsights.make(in: game, for: Player.player1, focus: ["Serve", "Volley", "Drop", "Boast", "Achterwand"])
        XCTAssertEqual(insights[0].text, "Op eigen service 6 van 9 punten gewonnen. Servicepunten 0, servicefouten 1.")
        XCTAssertEqual(insights[1].text, "1 punt uit de lucht (1 drop). Jaïr: 0.")
        XCTAssertEqual(insights[2].text, "1 punt met een drop. Voorin 5 gewonnen, 0 verloren.")
        XCTAssertEqual(insights[3].text, "Nog geen punt met een boast. Jaïr: 0.")
        // One point at the back is below the two needed to name a shot there
        XCTAssertEqual(insights[4].text, "Achterin 1 gewonnen, 0 verloren.")
    }

    func testTheOpponentSeesTheOtherSide() {
        let insights = FocusInsights.make(in: game(), for: Player.player2, focus: ["Backhand", "Serve", "Tactiek", "Beweging"])
        XCTAssertEqual(insights[0].text, "Linkerkant: 0 gewonnen, 5 verloren.")
        XCTAssertEqual(insights[1].text, "Nog niet geserveerd.")
        XCTAssertEqual(insights[2].text, "Nog geen punten met een vak.")
        XCTAssertEqual(insights[3].text, "Lets mee 0, lets tegen 0, strokes tegen 0.")
    }

    func testStaminaAndSpeedNeedTimedRallies() {
        // 2, 4, 6 and 8 s: the median is 6, so short = 2 and 4, long = 6 and 8
        let game = Game()
        game.player1Name = "Hugo"
        game.player2Name = "Jaïr"
        game.points = [
            Point(scorer: Player.player1, pointType: PointType.winner, zone: CourtZone.backLeft, shotType: ShotType.drive, server: Player.player1, player1Score: 1, player2Score: 0, duration: 2),
            Point(scorer: Player.player2, pointType: PointType.forcedError, zone: CourtZone.frontRight, shotType: ShotType.drop, server: Player.player1, player1Score: 1, player2Score: 1, duration: 4),
            Point(scorer: Player.player2, pointType: PointType.winner, zone: CourtZone.frontLeft, shotType: ShotType.kill, server: Player.player2, player1Score: 1, player2Score: 2, duration: 6),
            Point(scorer: Player.player1, pointType: PointType.winner, zone: CourtZone.backLeft, shotType: ShotType.lob, server: Player.player2, player1Score: 2, player2Score: 2, duration: 8),
        ]
        let insights = FocusInsights.make(in: game, for: Player.player1, focus: ["Conditie", "Snelheid", "Tactiek"])
        XCTAssertEqual(insights[0].text, "Lange rally's 50% gewonnen, korte 50%. Langste rally 8s.")
        XCTAssertEqual(insights[1].text, "1 punt verloren onder druk (forced error). Korte rally's 50% gewonnen.")
        XCTAssertEqual(insights[2].text, "Beste zone Achter Links, beste slag drive, 2 verschillende slagen.")

        let empty = FocusInsights.make(in: Game(), for: Player.player1, focus: ["Conditie", "Snelheid", "Mentaal"])
        XCTAssertEqual(empty[0].text, "Nog te weinig getimede rally's.")
        XCTAssertEqual(empty[1].text, "0 punten verloren onder druk (forced error).")
        XCTAssertEqual(empty[2].text, "Nog geen punten.")
    }

    func testOneOwnErrorIsSingular() {
        let game = Game()
        game.player1Name = "Hugo"
        game.player2Name = "Jaïr"
        game.points = [
            Point(scorer: Player.player2, pointType: PointType.unforcedError, server: Player.player1, player1Score: 0, player2Score: 1, errorKind: ErrorKind.down),
        ]
        let insights = FocusInsights.make(in: game, for: Player.player1, focus: ["Mentaal"])
        XCTAssertEqual(insights[0].text, "1 eigen fout, 0 vanaf een stand van 8. Langste reeks verloren punten: 1.")
    }

    func testSimpleCoachingLeavesOutWhatItDoesNotRecord() {
        let insights = FocusInsights.make(in: game(), for: Player.player1,
                                          focus: ["Volley", "Backhand", "Serve", "Beweging", "Mentaal", "Tactiek"], simpleInput: true)
        XCTAssertEqual(insights[0].text, "Niet vastgelegd bij Eenvoudig coachen.")
        XCTAssertEqual(insights[1].text, "Linkerkant: 5 gewonnen, 0 verloren.")
        XCTAssertEqual(insights[2].text, "Op eigen service 5 van 8 punten gewonnen.")
        XCTAssertEqual(insights[3].text, "Lets mee 0, lets tegen 0.")
        XCTAssertEqual(insights[4].text, "Langste reeks verloren punten: 3.")
        XCTAssertEqual(insights[5].text, "Beste zone Voor Links.")
    }

    func testEnglish() {
        AppLanguageOverride.shared.language = AppLanguage.english
        defer { AppLanguageOverride.shared.language = AppLanguage.dutch }
        let insights = FocusInsights.make(in: game(), for: Player.player1, focus: ["Backhand", "Volley"])
        XCTAssertEqual(insights[0].text, "Left side: 5 won, 0 lost. Best shot there: drive (5).")
        XCTAssertEqual(insights[1].text, "No points out of the air yet.")
        XCTAssertEqual(insights[0].tag.title, "Backhand")
    }
}
