import XCTest
import Foundation
@testable import SquashAnalyzerCore

// 4.0 work sits behind a switch on main (docs/releaseplan-3x-4.0.md): a 3.x
// store build must never turn it on by accident.
final class FeaturesTests: XCTestCase {

    func testThePlayerAccountIsOffByDefault() {
        XCTAssertFalse(Features().playerAccount)
    }

    func testOnlyAnExplicitYesTurnsASwitchOn() {
        XCTAssertTrue(Features.isOn("YES"))
        XCTAssertTrue(Features.isOn("true"))
        XCTAssertTrue(Features.isOn(" 1 "))
        XCTAssertFalse(Features.isOn(nil))
        XCTAssertFalse(Features.isOn(""))
        XCTAssertFalse(Features.isOn("NO"))
        XCTAssertFalse(Features.isOn("false"))
        XCTAssertFalse(Features.isOn("$(SQUASH_PLAYER_ACCOUNT)"))
    }
}
