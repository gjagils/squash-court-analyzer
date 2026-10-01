import SwiftUI
import Foundation
import SquashAnalyzerCore

/// Serializes UI edits with durable writes. A failed save keeps the live match
/// on screen and blocks further edits until retry succeeds.
public struct CoachSessionView: View {
    let store: any CoachMatchStore
    let playerStore: any PlayerProfileStore
    /// Player photos for the scoreboard; nil shows the plain avatar
    let photoStore: (any PlayerPhotoStore)?
    /// Picking a photo when adding a player from "Kies speler"
    let filePicker: (any PlayerFilePicker)?
    @State private var photos: [String: Data] = [:]
    let onExit: @MainActor () -> Void
    /// AI Coach in the game analysis; nil hides the AI part
    let aiCoach: AICoachContext?
    /// The platform share sheet, for "Deel score" and the game summary
    let shareText: ((String) -> Void)?
    /// Afgeronde wedstrijden from the coach header; nil hides the button
    let historyStore: (any MatchHistoryStore)?
    /// Instellingen from the coach header (nil hides the button)
    let settings: SettingsContext?
    @State private var showingHistory = false
    @State private var showingSettings = false
    @Environment(\.dismiss) private var dismiss
    @State private var match: Match? = nil
    @State private var pending: Match? = nil
    @State private var showingSetup = false
    @State private var busy = true
    @State private var failed = false
    @State private var exitAfterSave = false
    /// A change came in while saving; save once more when done
    @State private var saveAgain = false
    /// Saving a point in the background: the screen stays usable, no overlay
    /// (changes meanwhile go through `saveAgain`); only leaving waits for it
    @State private var saving = false

    public init(store: any CoachMatchStore, playerStore: any PlayerProfileStore, photoStore: (any PlayerPhotoStore)? = nil, filePicker: (any PlayerFilePicker)? = nil, aiCoach: AICoachContext? = nil,
                shareText: ((String) -> Void)? = nil, historyStore: (any MatchHistoryStore)? = nil, settings: SettingsContext? = nil,
                onExit: @escaping @MainActor () -> Void) {
        self.store = store
        self.historyStore = historyStore
        self.settings = settings
        self.shareText = shareText
        self.aiCoach = aiCoach
        self.playerStore = playerStore
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            CoachPalette.backgroundDark.ignoresSafeArea()
            if let match {
                CoachScoringView(match: match, aiCoach: aiCoach, shareText: shareText, photos: photos, onMatchChanged: { changed in
                    persist(changed, exit: false)
                }, onAbandon: { finish(match, discard: false) }, onDiscard: { finish(match, discard: true) },
                onHistory: historyStore == nil ? nil : { showingHistory = true },
                onSettings: settings == nil ? nil : { showingSettings = true },
                onNewMatch: { startOver(match) },
                onExit: { persist(match, exit: true) })
                .disabled(busy || failed)
            } else if let pending {
                ResumePromptCard(message: pending.resumeMessage,
                                 onResume: { match = pending; self.pending = nil },
                                 onNew: { startFresh(abandoning: pending) },
                                 onCancel: { close() })
                .disabled(busy || failed)
            } else if showingSetup {
                MatchSetupView(playerStore: playerStore, mode: .coach, photoStore: photoStore, filePicker: filePicker, onCancel: { close() }) { choice in
                    startNewMatch(choice)
                }
                .disabled(busy || failed)
            }
            if busy || (saving && exitAfterSave) {
                ProgressView(match == nil && pending == nil && !showingSetup ? "Laden…" : "Even opslaan…")
                    .padding(24).background(CoachPalette.backgroundMedium)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if failed {
                VStack(spacing: 16) {
                    Text(match == nil ? "Wedstrijd kon niet worden geladen" : "Opslaan is niet gelukt")
                        .font(.headline)
                    Text("Probeer het opnieuw. Je huidige invoer blijft in dit scherm staan.")
                        .multilineTextAlignment(.center)
                    Button("Opnieuw proberen") {
                        if let match { persist(match, exit: exitAfterSave) }
                        else { Task { await load() } }
                    }
                }
                .foregroundColor(CoachPalette.textPrimary)
                .padding(24).background(CoachPalette.backgroundMedium)
                .clipShape(RoundedRectangle(cornerRadius: 16)).padding(20)
            }
        }
        .task {
            photos = await PlayerPhotos.load(photoStore: photoStore, playerStore: playerStore)
            if match == nil && pending == nil && !showingSetup { await load() }
        }
        .sheet(isPresented: $showingHistory) {
            if let historyStore {
                NavigationStack {
                    SharedMatchHistoryView(store: historyStore, aiCoach: aiCoach, shareText: shareText)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Sluiten") { showingHistory = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            if let settings {
                NavigationStack {
                    SharedSettingsView(aiCoach: settings.aiCoach, backup: settings.backup)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Sluiten") { showingSettings = false }
                            }
                        }
                }
            }
        }
    }

    /// "Nieuwe wedstrijd" on the resume question: the old one goes into
    /// Afgeronde wedstrijden as incomplete (an empty one is dropped), then setup
    private func startFresh(abandoning old: Match) {
        busy = true
        Task { @MainActor in
            do {
                if old.stopAction == .discard { try await store.discard(old) } else { try await store.abandon(old) }
                pending = nil
                showingSetup = true
            } catch { failed = true }
            busy = false
        }
    }

    private func load() async {
        busy = true
        failed = false
        do {
            if let saved = try await store.loadInProgress() { pending = saved }
            else { showingSetup = true }
        } catch { failed = true }
        busy = false
    }

    private func startNewMatch(_ choice: MatchSetupChoice) {
        showingSetup = false
        busy = true
        failed = false
        Task { @MainActor in
            let fresh = Match()
            fresh.setupMatch(
                player1: choice.player1Name, player2: choice.player2Name, startingServer: choice.startingServer,
                player1CoachingFocus: choice.player1Focus, player2CoachingFocus: choice.player2Focus,
                player1GamesBefore: choice.player1GamesBefore, player2GamesBefore: choice.player2GamesBefore,
                player1Id: choice.player1Id.flatMap { UUID(uuidString: $0) },
                player2Id: choice.player2Id.flatMap { UUID(uuidString: $0) }
            )
            match = fresh
            do { try await store.save(fresh) } catch { failed = true }
            busy = false
        }
    }

    /// "Nieuwe wedstrijd" on the match-over card: the finished match is
    /// saved, then the setup screen opens, as on iOS
    private func startOver(_ value: Match) {
        busy = true
        failed = false
        Task { @MainActor in
            do {
                try await store.save(value)
                match = nil
                showingSetup = true
            } catch {
                failed = true
            }
            busy = false
        }
    }

    /// "Opslaan als incompleet" or "Niet opslaan", then back home
    private func finish(_ value: Match, discard: Bool) {
        busy = true
        failed = false
        Task { @MainActor in
            do {
                if discard { try await store.discard(value) } else { try await store.abandon(value) }
                busy = false
                close()
            } catch {
                busy = false
                failed = true
            }
        }
    }

    /// Saves `value`. A change while a save is running is saved right after
    /// it (with the latest state), never dropped.
    private func persist(_ value: Match, exit: Bool) {
        if exit { exitAfterSave = true }
        if saving || busy {
            saveAgain = true
            return
        }
        saving = true
        failed = false
        Task { @MainActor in
            do {
                try await store.save(value)
                if saveAgain, let latest = match {
                    saveAgain = false
                    saving = false
                    persist(latest, exit: false)
                    return
                }
                saving = false
                if exitAfterSave { close() }
            } catch {
                saving = false
                failed = true
            }
        }
    }

    @MainActor private func close() {
        onExit()
        dismiss()
    }
}
