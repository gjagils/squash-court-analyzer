import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// The tour and the links of "Over de app"
final class OnboardingTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }
    func testTheTourShowsOnceUntilItIsRaised() {
        XCTAssertTrue(Onboarding.shouldShow(seenVersion: 0), "a new install, and the testers who had the app")
        XCTAssertFalse(Onboarding.shouldShow(seenVersion: Onboarding.currentVersion))
        XCTAssertFalse(Onboarding.shouldShow(seenVersion: Onboarding.currentVersion + 1))
    }

    func testTheTourHasSixPagesWithCompetitionFifth() {
        XCTAssertEqual(Onboarding.pages.count, 6)
        XCTAssertEqual(Onboarding.pages[Onboarding.competitionPage].title, "Competitie")
        for page in Onboarding.pages {
            XCTAssertFalse(page.title.isEmpty)
            XCTAssertFalse(page.text.isEmpty)
        }
    }

    func testWhatsNewShowsOnceForEveryone() {
        XCTAssertTrue(WhatsNew.shouldShow(seenVersion: 0), "a new install, a 2.0 user and a tester alike")
        XCTAssertFalse(WhatsNew.shouldShow(seenVersion: WhatsNew.currentVersion))
        XCTAssertEqual(WhatsNew.items.count, 3)
        for item in WhatsNew.items {
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.text.isEmpty)
        }
    }

    func testWhatsNewAsksForAnAccountAndTheTeam() {
        XCTAssertEqual(WhatsNew.action(onPage: 0), WhatsNew.Action.none)
        XCTAssertEqual(WhatsNew.action(onPage: WhatsNew.accountPage), WhatsNew.Action.account)
        XCTAssertEqual(WhatsNew.action(onPage: WhatsNew.sharePage), WhatsNew.Action.shareWithTeam)
        XCTAssertEqual(WhatsNew.action(onPage: 3), WhatsNew.Action.none)
        XCTAssertTrue(WhatsNew.shouldShow(seenVersion: 3), "a 3.2 user sees it once")
    }

    func testWhatsNewComesBackWithEveryTestBuild() {
        let now = WhatsNew.currentVersion
        XCTAssertTrue(WhatsNew.shouldShow(seenVersion: 3, seenBuild: "", build: "4.0 (2)"))
        XCTAssertFalse(WhatsNew.shouldShow(seenVersion: now, seenBuild: "4.0 (2)", build: "4.0 (2)"), "seen in this build")
        XCTAssertEqual(WhatsNew.shouldShow(seenVersion: now, seenBuild: "4.0 (2)", build: "4.0 (3)"), WhatsNew.perBuild)
        XCTAssertFalse(WhatsNew.shouldShow(seenVersion: now, seenBuild: "4.0 (2)", build: ""), "no build known: once per version")
    }

    func testTeamShareTextHasBothStores() {
        XCTAssertTrue(AppLinks.teamShareText.contains("play.google.com/store/apps/details?id=com.squashanalyzer.android"))
        XCTAssertTrue(AppLinks.teamShareText.contains("apps.apple.com/app/squash-analyzer/id6758676921"))
        XCTAssertTrue(AppLinks.teamShareText.contains("account"))
    }

    func testShareTextHasBothStores() {
        XCTAssertTrue(AppLinks.shareText.contains("play.google.com/store/apps/details?id=com.squashanalyzer.android"))
        XCTAssertTrue(AppLinks.shareText.contains("apps.apple.com/app/squash-analyzer/id6758676921"))
    }

    func testFeedbackMailCarriesTheVersion() {
        let mail = AppLinks.feedbackMail(appVersion: "Android 3.0 (2.3)")
        XCTAssertEqual(mail.absoluteString, "mailto:info@squashanalyzer.com?subject=Feedback%20Squash%20Analyzer%20Android%203.0%20(2.3)")
        XCTAssertEqual(AppLinks.mailEncoded("a&b=c d"), "abc%20d", "nothing that could break the link")
    }
}
