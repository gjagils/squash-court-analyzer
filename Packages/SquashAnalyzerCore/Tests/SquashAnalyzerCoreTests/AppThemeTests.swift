import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Licht of donker: the choice and what it means
final class AppThemeTests: XCTestCase {
    func testEveryoneStartsDark() {
        XCTAssertEqual(AppAppearance.from(stored: nil), AppAppearance.dark)
        XCTAssertEqual(AppAppearance.from(stored: ""), AppAppearance.dark)
        XCTAssertEqual(AppAppearance.from(stored: "sepia"), AppAppearance.dark)
        XCTAssertEqual(AppAppearance.from(stored: "light"), AppAppearance.light)
        XCTAssertEqual(AppAppearance.from(stored: "system"), AppAppearance.system)
    }

    func testSystemFollowsThePhone() {
        XCTAssertTrue(AppAppearance.system.isLight(systemIsDark: false))
        XCTAssertFalse(AppAppearance.system.isLight(systemIsDark: true))
        XCTAssertTrue(AppAppearance.light.isLight(systemIsDark: true))
        XCTAssertFalse(AppAppearance.dark.isLight(systemIsDark: false))
        XCTAssertEqual(AppAppearance.allCases.map { appearance in appearance.title }, ["Systeem", "Licht", "Donker"])
    }
}
