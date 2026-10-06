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
    func testAnExitDuringABlockingOperationIsIgnoredAndLeavesNoFlagBehind() async throws {
        let store = RecordingWrites()
        let saver = SessionSaver(busy: true)
        var closed = false
        saver.onExit = { closed = true }
        saver.save(exit: true) { try await store.write("ignored") }
        XCTAssertFalse(saver.exitAfterSave, "an ignored exit must not stay armed")
        XCTAssertFalse(saver.saving)
        XCTAssertTrue(store.written.isEmpty)

        // The operation ends; the next ordinary point does not close the screen
        let worked = await saver.perform { try await store.write("operation") }
        XCTAssertTrue(worked)
        saver.save { try await store.write("point") }
        await saver.waitUntilSaved()
        XCTAssertEqual(store.written, ["operation", "point"])
        XCTAssertFalse(closed)
    }

    @MainActor
    func testTheScreenIsBlockedWhileAnOperationWaitsForARunningSave() async throws {
        let store = RecordingWrites()
        let saver = SessionSaver()
        saver.save { try await store.write("point") }
        let waiting = Task { await saver.perform { try await store.write("finish") } }
        // Wait (briefly, polling) until the operation has started; the running save takes 20 ms
        var tries = 0
        while !saver.busy && tries < 200 {
            tries += 1
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(saver.busy, "blocked while it waits, not only after")
        saver.save { try await store.write("slipped in") }
        _ = await waiting.value
        XCTAssertEqual(store.written, ["point", "finish"], "nothing slips in between")
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
