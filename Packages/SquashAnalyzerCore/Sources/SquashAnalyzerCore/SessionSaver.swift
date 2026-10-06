import Foundation
import Observation

/// The writes of one coach or referee session, one at a time (T19). Shared by
/// `CoachSessionView` and `RefereeSessionView` on Android (and iOS once it uses
/// the shared screens).
///
/// - `save`: a point or other change, in the background; the screen stays
///   usable. A change that comes in during a save is written right after it,
///   and only the newest one (it holds the latest state).
/// - `perform`: loading, starting, finishing or abandoning a match. It first
///   waits for a running save, so a finished match can never be overwritten
///   by a save that was still on its way, and blocks the screen meanwhile.
///
/// A failure keeps everything on screen and sets `failed`; the screen offers
/// to try again.
@MainActor
@Observable
public final class SessionSaver {
    /// A blocking operation (`perform`) is running: show "Even opslaan…"
    public private(set) var busy: Bool
    /// A background save is running
    public private(set) var saving = false
    /// The last save or operation failed
    public private(set) var failed = false
    /// The screen closes as soon as the running save is done
    public private(set) var exitAfterSave = false
    /// Called once the save that was asked to exit is done
    public var onExit: () -> Void = {}

    private var queued: (() async throws -> Void)? = nil
    private var current: Task<Void, Never>? = nil

    public init(busy: Bool = false) {
        self.busy = busy
    }

    /// Saves in the background. With `exit`, the screen closes once this
    /// (and anything queued) is saved. Ignored while a blocking operation runs:
    /// the screen is disabled then, and the operation has the final word.
    public func save(exit: Bool = false, _ write: @escaping () async throws -> Void) {
        // Ignored means ignored: also the wish to exit, or the next plain save
        // would close the screen in the middle of the match
        if busy { return }
        if exit { exitAfterSave = true }
        if saving {
            queued = write
            return
        }
        failed = false
        saving = true
        current = Task { await self.runSaves(first: write) }
    }

    /// Waits until the running save (and anything queued behind it) is done
    public func waitUntilSaved() async {
        if let current {
            await current.value
        }
    }

    /// Waits for a running save, then runs `operation` with the screen
    /// blocked. Returns whether it worked; on failure `failed` is set.
    @discardableResult
    public func perform(_ operation: @escaping () async throws -> Void) async -> Bool {
        // Blocked from the start, also while waiting for a running save: a
        // change that arrives in between would otherwise slip in after it
        busy = true
        failed = false
        await waitUntilSaved()
        do {
            try await operation()
            busy = false
            return true
        } catch {
            busy = false
            failed = true
            return false
        }
    }

    /// Starts a blocking operation without waiting for it (button actions)
    public func start(_ operation: @escaping () async throws -> Void) {
        busy = true
        Task { await self.perform(operation) }
    }

    private func runSaves(first: @escaping () async throws -> Void) async {
        var next: (() async throws -> Void)? = first
        while let write = next {
            do {
                try await write()
            } catch {
                queued = nil
                saving = false
                failed = true
                return
            }
            next = queued
            queued = nil
        }
        saving = false
        if exitAfterSave {
            exitAfterSave = false
            onExit()
        }
    }
}
