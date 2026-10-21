import XCTest
@testable import SquashAnalyzerCore

final class UserManualTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }
    func testEachPlatformHasItsOwnManualPage() {
        XCTAssertEqual(UserManual.iPhone.absoluteString, "https://www.squashanalyzer.com/handleiding/iphone.html")
        XCTAssertEqual(UserManual.android.absoluteString, "https://www.squashanalyzer.com/handleiding/android.html")
    }
}
