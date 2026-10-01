import XCTest
@testable import SquashAnalyzerCore

final class UserManualTests: XCTestCase {
    func testEachPlatformHasItsOwnManualPage() {
        XCTAssertEqual(UserManual.iPhone.absoluteString, "https://www.squashanalyzer.com/handleiding/iphone.html")
        XCTAssertEqual(UserManual.android.absoluteString, "https://www.squashanalyzer.com/handleiding/android.html")
    }
}
