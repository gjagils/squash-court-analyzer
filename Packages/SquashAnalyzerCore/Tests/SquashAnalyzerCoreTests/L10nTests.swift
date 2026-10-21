import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// The English variant (docs/i18n.md): Dutch stays as it was, English comes
/// from Resources/en.lproj, and the live server hears the language.
final class L10nTests: XCTestCase {
    override func tearDown() {
        AppLanguageOverride.shared.language = nil
        super.tearDown()
    }

    func testLanguageFollowsThePhone() {
        XCTAssertEqual(AppLanguage.from(preferredLanguages: ["nl-NL", "en-GB"]), AppLanguage.dutch)
        XCTAssertEqual(AppLanguage.from(preferredLanguages: ["nl-BE"]), AppLanguage.dutch)
        XCTAssertEqual(AppLanguage.from(preferredLanguages: ["nl"]), AppLanguage.dutch)
        XCTAssertEqual(AppLanguage.from(preferredLanguages: ["en-GB", "nl-NL"]), AppLanguage.english)
        XCTAssertEqual(AppLanguage.from(preferredLanguages: ["de-DE"]), AppLanguage.english)
        XCTAssertEqual(AppLanguage.from(preferredLanguages: []), AppLanguage.dutch)
        XCTAssertEqual(AppLanguage.english.code, "en")
        XCTAssertEqual(AppLanguage.dutch.code, "nl")
    }

    func testFillKeepsOrderAndPositions() {
        XCTAssertEqual(L10n.fill("%@ wint game %@", ["Jan", "2"]), "Jan wint game 2")
        XCTAssertEqual(L10n.fill("%2$@ before %1$@", ["a", "b"]), "b before a")
        XCTAssertEqual(L10n.fill("%@ van %@ gewonnen (%@%)", ["7", "10", "70"]), "7 van 10 gewonnen (70%)")
        // An argument that itself looks like a placeholder stays as it is
        XCTAssertEqual(L10n.fill("%@ – %@", ["%@", "Piet"]), "%@ – Piet")
        XCTAssertEqual(L10n.fill("Geen rally's", []), "Geen rally's")
    }

    func testDutchNeverLooksAnythingUp() {
        AppLanguageOverride.shared.language = AppLanguage.dutch
        XCTAssertEqual(BadgeTier.gold.title, "Goud")
        XCTAssertEqual(BadgeKind.pioneer.title, "Pionier")
        XCTAssertEqual(WhatsNew.title, "Nieuw in 3.0")
        XCTAssertEqual(L10n.text("%@ wint game %@", "Jan", "2"), "Jan wint game 2")
    }

    func testEnglishTextsExist() {
        XCTAssertNotNil(L10n.englishBundle, "Resources/en.lproj/Localizable.strings is missing from the bundle")
        for key in ["Brons", "Pionier", "Nieuw in 3.0", "Competitie", "Live meekijken", "WEDSTRIJD KLAAR",
                    "%@ wint game %@", "Nog niet begonnen", "Gelijkspel", "Competitiepunten: %@"] {
            XCTAssertTrue(L10n.hasEnglish(key), "no English for \(key)")
        }
        XCTAssertFalse(L10n.hasEnglish("Dit staat nergens"))
    }

    func testEnglishBadgesAndTour() {
        AppLanguageOverride.shared.language = AppLanguage.english
        XCTAssertEqual(BadgeTier.gold.title, "Gold")
        XCTAssertEqual(BadgeKind.pioneer.title, "Pioneer")
        XCTAssertEqual(BadgeKind.dropItGold.tieredTitle, "Drop it like it's hot · Gold")
        XCTAssertEqual(BadgeKind.fiveInARowSilver.detail, "7 points in a row")
        XCTAssertEqual(BadgeKind.Category.career.title, "Across all your matches")
        XCTAssertEqual(WhatsNew.title, "What's new in 3.0")
        XCTAssertEqual(Onboarding.pages[4].title, "League")
        XCTAssertEqual(TestDataGroup.competition.title, "League matches")
        XCTAssertEqual(CourtZone.backLeft.title, "Back left")
        // The stored value stays Dutch
        XCTAssertEqual(CourtZone.backLeft.rawValue, "Achter Links")
        XCTAssertEqual(ServiceReturnStats.line(7, of: 10), "7 of 10 won (70%)")
    }

    func testEnglishErrors() {
        AppLanguageOverride.shared.language = AppLanguage.english
        XCTAssertEqual(LiveFollowError.notFound.message, "This match is over or the link is wrong.")
        XCTAssertEqual(AICoachError.apiError(statusCode: 500).message, "API error (code: 500)")
        XCTAssertTrue(AICoachPrompt.system.contains("in English"))
        XCTAssertTrue(AICoachPrompt.system.contains("\"focusVolgendeGame\""))
        AppLanguageOverride.shared.language = AppLanguage.dutch
        XCTAssertTrue(AICoachPrompt.system.contains("in het Nederlands"))
    }

    func testLangOnlyWhenStartingOrFollowing() throws {
        var snapshot = LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 5, games: [], score: [0, 0], gamesWon: [0, 0],
                                    server: 1, side: "R", status: LiveStatus.warmup)
        let update = String(data: try JSONEncoder().encode(snapshot), encoding: String.Encoding.utf8) ?? ""
        XCTAssertFalse(update.contains("lang"))
        snapshot.lang = "en"
        let start = String(data: try JSONEncoder().encode(snapshot), encoding: String.Encoding.utf8) ?? ""
        XCTAssertTrue(start.contains("\"lang\":\"en\""))

        let follow = LiveFollowerRegistration(platform: "ios", token: "t", lang: "nl")
        let followText = String(data: try JSONEncoder().encode(follow), encoding: String.Encoding.utf8) ?? ""
        XCTAssertTrue(followText.contains("\"lang\":\"nl\""))
        let forget = LiveFollowerRegistration(platform: "ios", token: "t")
        let forgetText = String(data: try JSONEncoder().encode(forget), encoding: String.Encoding.utf8) ?? ""
        XCTAssertFalse(forgetText.contains("lang"))

        let header = TeamLiveHeader(home: "A", away: "B", date: 0, lang: "en")
        let headerText = String(data: try JSONEncoder().encode(header), encoding: String.Encoding.utf8) ?? ""
        XCTAssertTrue(headerText.contains("\"lang\":\"en\""))
    }
}
