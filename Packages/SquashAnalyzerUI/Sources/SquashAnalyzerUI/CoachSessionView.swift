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
    /// Competitie: after a finished match on a match day, ask which partij it is
    let teamMatchStore: (any TeamMatchStore)?
    /// A match started for a partij of a team match: names to start with, and
    /// the finished match goes into that partij without asking
    @State private var activeTarget: TeamTarget?
    @State private var linkCandidate: TeamMatch? = nil
    @State private var linkAsked = false
    @Environment(\.dismiss) private var dismiss
    @State private var match: Match? = nil
    @State private var pending: Match? = nil
    @State private var showingSetup = false
    /// The session's writes, one at a time (SessionSaver, T19): points save in
    /// the background, finishing waits for a save that is still running
    @State private var saver = SessionSaver(busy: true)

    public init(store: any CoachMatchStore, playerStore: any PlayerProfileStore, photoStore: (any PlayerPhotoStore)? = nil, filePicker: (any PlayerFilePicker)? = nil, aiCoach: AICoachContext? = nil,
                shareText: ((String) -> Void)? = nil, historyStore: (any MatchHistoryStore)? = nil, settings: SettingsContext? = nil,
                teamMatchStore: (any TeamMatchStore)? = nil, teamTarget: TeamTarget? = nil,
                onExit: @escaping @MainActor () -> Void) {
        self.store = store
        self.teamMatchStore = teamMatchStore
        _activeTarget = State(initialValue: teamTarget)
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
            SharedColors.background.ignoresSafeArea()
            if let match {
                CoachScoringView(match: match, aiCoach: aiCoach, shareText: shareText, photos: photos, onMatchChanged: { changed in
                    persist(changed, exit: false)
                }, onAbandon: { finish(match, discard: false) }, onDiscard: { finish(match, discard: true) },
                onHistory: historyStore == nil ? nil : { showingHistory = true },
                onSettings: settings == nil ? nil : { showingSettings = true },
                onNewMatch: { startOver(match) },
                onExit: { requestExit(match) })
                .disabled(saver.busy || saver.failed)
            } else if let pending {
                ResumePromptCard(message: pending.resumeMessage,
                                 onResume: { resume(pending) },
                                 onNew: { startFresh(abandoning: pending) },
                                 onCancel: { close() })
                .disabled(saver.busy || saver.failed)
            } else if showingSetup {
                MatchSetupView(playerStore: playerStore, mode: .coach, photoStore: photoStore, filePicker: filePicker,
                               initialPlayer1Name: activeTarget?.player1Name ?? "", initialPlayer2Name: activeTarget?.player2Name ?? "",
                               teamMatchStore: activeTarget == nil ? teamMatchStore : nil,
                               onCancel: { close() }) { choice in
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
            ScreenAwake.set(true)
            photos = await PlayerPhotos.load(photoStore: photoStore, playerStore: playerStore)
            if match == nil && pending == nil && !showingSetup { await load() }
        }
        // The closure holds this view (and so the saver itself): let go once it is gone
        .onDisappear {
            saver.onExit = {}
            ScreenAwake.set(false)
        }
        .sheet(isPresented: $showingHistory) {
            if let historyStore {
                NavigationStack {
                    SharedMatchHistoryView(store: historyStore, aiCoach: aiCoach, shareText: shareText)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                CloseButton { showingHistory = false }
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
                                CloseButton { showingSettings = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: Binding(get: { linkCandidate != nil }, set: { if !$0 { linkCandidate = nil } })) {
            if let candidate = linkCandidate, let match {
                TeamMatchLinkPrompt(team: candidate, player1Name: match.player1Name, player2Name: match.player2Name) { slot, ownIsPlayer1 in
                    linkCandidate = nil
                    Task { @MainActor in
                        if let teamMatchStore {
                            await TeamMatchSupport.linkOnMatchDay(coach: match, team: candidate, slot: slot,
                                                                  ownIsPlayer1: ownIsPlayer1, store: teamMatchStore)
                        }
                        persist(match, exit: true)
                    }
                } onSkip: {
                    linkCandidate = nil
                    persist(match, exit: true)
                }
            }
        }
    }

    /// "Klaar" after the match: on a match day of Mijn team first ask whether
    /// it belongs to the team match (once); then save and go home
    private func requestExit(_ value: Match) {
        // Started for a partij: a finished match goes straight into it
        if let teamTarget = activeTarget, let teamMatchStore, value.isMatchOver {
            Task { @MainActor in
                await TeamMatchSupport.link(coach: value, target: teamTarget, store: teamMatchStore)
                persist(value, exit: true)
            }
            return
        }
        guard value.isMatchOver, !linkAsked, activeTarget == nil, let teamMatchStore else {
            persist(value, exit: true)
            return
        }
        linkAsked = true
        Task { @MainActor in
            if let candidate = await TeamMatchSupport.candidate(store: teamMatchStore),
               candidate.partijLinked(to: value.id.uuidString) == nil {
                persist(value, exit: false)
                linkCandidate = candidate
            } else {
                persist(value, exit: true)
            }
        }
    }

    /// "Nieuwe wedstrijd" on the resume question: the old one goes into
    /// Afgeronde wedstrijden as incomplete (an empty one is dropped), then setup
    private func startFresh(abandoning old: Match) {
        saver.start {
            if old.stopAction == .discard { try await store.discard(old) } else { try await store.abandon(old) }
            if let teamMatchStore { await TeamMatchSupport.untrack(matchId: old.id, store: teamMatchStore) }
            pending = nil
            showingSetup = true
        }
    }

    /// "Hervat": the match goes on, and when it was started for a partij of a
    /// team match that coupling comes back (result, live page)
    private func resume(_ saved: Match) {
        match = saved
        pending = nil
        guard activeTarget == nil, let teamMatchStore else { return }
        Task { @MainActor in
            if let target = await TeamMatchSupport.target(forMatchId: saved.id, store: teamMatchStore) {
                activeTarget = target
                target.bind(matchId: saved.id)
            }
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
        let fresh = Match()
        fresh.setupMatch(
            player1: choice.player1Name, player2: choice.player2Name, startingServer: choice.startingServer,
            player1CoachingFocus: choice.player1Focus, player2CoachingFocus: choice.player2Focus,
            player1GamesBefore: choice.player1GamesBefore, player2GamesBefore: choice.player2GamesBefore,
            player1Id: choice.player1Id.flatMap { UUID(uuidString: $0) },
            player2Id: choice.player2Id.flatMap { UUID(uuidString: $0) }
        )
        match = fresh
        // "Onderdeel van een teamwedstrijd" chosen in the setup: the team match
        // must exist for the result to be linked, and a live one gets the state
        if let target = choice.teamTarget {
            activeTarget = target
        }
        activeTarget?.bind(matchId: fresh.id)
        if let target = activeTarget, let teamMatchStore {
            let teamMatch = choice.teamMatch
            let matchId = fresh.id
            Task { @MainActor in
                if let teamMatch { try? await teamMatchStore.save(teamMatch) }
                await TeamMatchSupport.track(target, matchId: matchId, store: teamMatchStore)
            }
        }
        saver.start { try await store.save(fresh) }
    }

    /// "Nieuwe wedstrijd" on the match-over card: the finished match is
    /// saved, then the setup screen opens, as on iOS
    private func startOver(_ value: Match) {
        // Waits for a point that is still being saved, then saves the final state
        saver.start {
            try await store.save(value)
            match = nil
            showingSetup = true
        }
    }

    /// "Opslaan als incompleet" or "Niet opslaan", then back home
    private func finish(_ value: Match, discard: Bool) {
        // Waits for a running save first: it must not bring the match back afterwards
        Task { @MainActor in
            let done = await saver.perform {
                if discard { try await store.discard(value) } else { try await store.abandon(value) }
            }
            if done {
                if let teamMatchStore { await TeamMatchSupport.untrack(matchId: value.id, store: teamMatchStore) }
                close()
            }
        }
    }

    /// Saves `value`. A change while a save is running is saved right after
    /// it (with the latest state), never dropped.
    /// Saves `value` in the background; a change during a save is saved right
    /// after it with the latest state (SessionSaver)
    private func persist(_ value: Match, exit: Bool) {
        saver.save(exit: exit) { try await store.save(value) }
    }

    /// Both on purpose and idempotent: the parent closes the screen, dismiss closes the presentation (docs/bewuste-keuzes.md)
    @MainActor private func close() {
        onExit()
        dismiss()
    }
}
