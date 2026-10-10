import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// The tour and the links of "Over de app"
final class OnboardingTests: XCTestCase {
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
