import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// A store that records what was written, and can be told to fail
@MainActor
final class RecordingWrites {
    var written: [String] = []
    var failNext = false

    func write(_ value: String) async throws {
        // Give the next save a chance to arrive while this one runs
        try await Task.sleep(nanoseconds: 20_000_000)
        if failNext {
            failNext = false
            throw SessionSaverTestError.failed
        }
        written.append(value)
    }
}

enum SessionSaverTestError: Error {
    case failed
}

// The writes of a coach or referee session (T19): one at a time, the newest
// change wins, and finishing waits for a save that is still on its way.
final class SessionSaverTests: XCTestCase {

    @MainActor
    func testAChangeDuringASaveIsSavedRightAfterWithTheNewestState() async throws {
        let store = RecordingWrites()
        let saver = SessionSaver()
        saver.save { try await store.write("1-0") }
        saver.save { try await store.write("2-0") }
        saver.save { try await store.write("3-0") }
        XCTAssertTrue(saver.saving)
        await saver.waitUntilSaved()
        // The middle one was overtaken by the newest state
        XCTAssertEqual(store.written, ["1-0", "3-0"])
        XCTAssertFalse(saver.saving)
        XCTAssertFalse(saver.failed)
    }

    @MainActor
    func testFinishingWaitsForASaveThatIsStillRunning() async throws {
        let store = RecordingWrites()
        let saver = SessionSaver()
        saver.save { try await store.write("point") }
        let worked = await saver.perform { try await store.write("finish") }
        XCTAssertTrue(worked)
        // The save never lands after the match was finished
        XCTAssertEqual(store.written, ["point", "finish"])
        XCTAssertFalse(saver.busy)
    }

    @MainActor
    func testExitWaitsForTheSaveAndThenCloses() async throws {
        let store = RecordingWrites()
        let saver = SessionSaver()
        var closed = 0
        saver.onExit = { closed += 1 }
        saver.save { try await store.write("point") }
        saver.save(exit: true) { try await store.write("last") }
        XCTAssertTrue(saver.exitAfterSave)
        XCTAssertEqual(closed, 0)
        await saver.waitUntilSaved()
        XCTAssertEqual(store.written, ["point", "last"])
        XCTAssertEqual(closed, 1)
        XCTAssertFalse(saver.exitAfterSave)
    }

    @MainActor
    func testAFailedSaveKeepsTheScreenAndCanBeTriedAgain() async throws {
        let store = RecordingWrites()
        let saver = SessionSaver()
        var closed = 0
        saver.onExit = { closed += 1 }
        store.failNext = true
        saver.save(exit: true) { try await store.write("point") }
        await saver.waitUntilSaved()
        XCTAssertTrue(saver.failed)
        XCTAssertEqual(closed, 0, "a failed save never closes the screen")
        XCTAssertTrue(saver.exitAfterSave, "trying again still closes afterwards")

        saver.save(exit: saver.exitAfterSave) { try await store.write("point") }
        await saver.waitUntilSaved()
        XCTAssertFalse(saver.failed)
        XCTAssertEqual(store.written, ["point"])
        XCTAssertEqual(closed, 1)
    }

    @MainActor
    func testAFailedOperationIsReported() async throws {
        let store = RecordingWrites()
        let saver = SessionSaver(busy: true)
        store.failNext = true
        let worked = await saver.perform { try await store.write("load") }
        XCTAssertFalse(worked)
        XCTAssertTrue(saver.failed)
        XCTAssertFalse(saver.busy)
    }
}
