import SwiftUI
import Foundation
import SquashAnalyzerCore

/// Serializes UI edits with durable writes, mirroring `CoachSessionView`. A
/// failed save keeps the live match on screen and blocks further edits until
/// retry succeeds.
public struct RefereeSessionView: View {
    let store: any RefereeMatchStore
    let playerStore: any PlayerProfileStore
    /// Player photos for the scoreboard; nil shows the plain avatar
    let photoStore: (any PlayerPhotoStore)?
    /// Picking a photo when adding a player from "Kies speler"
    let filePicker: (any PlayerFilePicker)?
    @State private var photos: [String: Data] = [:]
    let onExit: @MainActor () -> Void
    /// The platform share sheet, for "Deel score"
    let shareText: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var match: RefereeMatch? = nil
    @State private var pending: RefereeMatch? = nil
    @State private var showingSetup = false
    /// The session's writes, one at a time (SessionSaver, T19): points save in
    /// the background, finishing waits for a save that is still running
    @State private var saver = SessionSaver(busy: true)

    public init(store: any RefereeMatchStore, playerStore: any PlayerProfileStore, photoStore: (any PlayerPhotoStore)? = nil, filePicker: (any PlayerFilePicker)? = nil, shareText: ((String) -> Void)? = nil,
                onExit: @escaping @MainActor () -> Void) {
        self.shareText = shareText
        self.store = store
        self.playerStore = playerStore
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            if let match {
                RefereeScoringView(match: match, shareText: shareText, photos: photos, onMatchChanged: { changed in
                    persist(changed, exit: false)
                }, onExit: { persist(match, exit: true) })
                .disabled(saver.busy || saver.failed)
            } else if let pending {
                ResumePromptCard(message: pending.resumeMessage,
                                 onResume: { match = pending; self.pending = nil },
                                 onNew: { startFresh(abandoning: pending) },
                                 onCancel: { close() })
                .disabled(saver.busy || saver.failed)
            } else if showingSetup {
                MatchSetupView(playerStore: playerStore, mode: .referee, photoStore: photoStore, filePicker: filePicker, onCancel: { close() }) { choice in
                    startNewMatch(choice)
                }
                .disabled(saver.busy || saver.failed)
            }
            if saver.busy || (saver.saving && saver.exitAfterSave) {
                ProgressView(match == nil && pending == nil && !showingSetup ? "Laden…" : "Even opslaan…")
                    .padding(24).background(SharedColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if saver.failed {
                VStack(spacing: 16) {
                    Text(match == nil ? "Wedstrijd kon niet worden geladen" : "Opslaan is niet gelukt")
                        .font(.headline)
                    Text("Probeer het opnieuw. Je huidige invoer blijft in dit scherm staan.")
                        .multilineTextAlignment(.center)
                    Button("Opnieuw proberen") {
                        if let match { persist(match, exit: saver.exitAfterSave) }
                        else { Task { await load() } }
                    }
                    // Every screen has a way out, also when saving or loading fails
                    Button(match == nil ? "Terug naar home" : "Sluiten zonder opslaan") { close() }
                        .foregroundColor(SharedColors.textSecondary)
                }
                .foregroundColor(SharedColors.textPrimary)
                .padding(24).background(SharedColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16)).padding(20)
            }
        }
        .task {
            saver.onExit = { close() }
            photos = await PlayerPhotos.load(photoStore: photoStore, playerStore: playerStore)
            if match == nil && pending == nil && !showingSetup { await load() }
        }
    }

    /// "Nieuwe wedstrijd" on the resume question: the old one goes into
    /// Afgeronde wedstrijden as incomplete (an empty one is dropped), then setup
    private func startFresh(abandoning old: RefereeMatch) {
        saver.start {
            try await store.abandon(old)
            pending = nil
            showingSetup = true
        }
    }

    private func load() async {
        await saver.perform {
            if let saved = try await store.loadInProgress() { pending = saved }
            else { showingSetup = true }
        }
    }

    private func startNewMatch(_ choice: MatchSetupChoice) {
        showingSetup = false
        let fresh = RefereeMatch(player1Name: choice.player1Name, player2Name: choice.player2Name, bestOf: 5,
                                 startingServer: choice.startingServer,
                                 player1GamesBefore: choice.player1GamesBefore, player2GamesBefore: choice.player2GamesBefore)
        fresh.player1Id = choice.player1Id.flatMap { UUID(uuidString: $0) }
        fresh.player2Id = choice.player2Id.flatMap { UUID(uuidString: $0) }
        match = fresh
        saver.start { try await store.save(fresh) }
    }

    /// Saves `value`. A change while a save is running is saved right after
    /// it (with the latest state), never dropped.
    /// Saves `value` in the background; a change during a save is saved right
    /// after it with the latest state (SessionSaver)
    private func persist(_ value: RefereeMatch, exit: Bool) {
        saver.save(exit: exit) { try await store.save(value) }
    }

    @MainActor private func close() {
        onExit()
        dismiss()
    }
}
