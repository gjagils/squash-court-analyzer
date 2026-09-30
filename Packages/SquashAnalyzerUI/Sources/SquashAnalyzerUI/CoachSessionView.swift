import SwiftUI
import SquashAnalyzerCore

/// Serializes UI edits with durable writes. A failed save keeps the live match
/// on screen and blocks further edits until retry succeeds.
public struct CoachSessionView: View {
    let store: any CoachMatchStore
    let playerStore: any PlayerProfileStore
    let onExit: @MainActor () -> Void
    /// AI Coach in the game analysis; nil hides the AI part
    let aiCoach: AICoachContext?
    @Environment(\.dismiss) private var dismiss
    @State private var match: Match? = nil
    @State private var pending: Match? = nil
    @State private var showingSetup = false
    @State private var busy = true
    @State private var failed = false
    @State private var confirmingNew = false
    @State private var exitAfterSave = false

    public init(store: any CoachMatchStore, playerStore: any PlayerProfileStore, aiCoach: AICoachContext? = nil,
                onExit: @escaping @MainActor () -> Void) {
        self.store = store
        self.aiCoach = aiCoach
        self.playerStore = playerStore
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            CoachPalette.backgroundDark.ignoresSafeArea()
            if let match {
                CoachScoringView(match: match, aiCoach: aiCoach, onMatchChanged: { changed in
                    persist(changed, exit: false)
                }, onExit: { persist(match, exit: true) })
                .disabled(busy || failed)
            } else if let pending {
                VStack(spacing: 24) {
                    Text("Wedstrijd hervatten").font(.title2.bold())
                    Text("\(pending.player1Name) – \(pending.player2Name)")
                    Text("Game \(pending.currentGameNumber) · \(pending.currentGame.player1Score) – \(pending.currentGame.player2Score)")
                    Button("Hervatten") { match = pending; self.pending = nil }
                        .buttonStyle(.borderedProminent)
                    Button("Nieuwe wedstrijd") { confirmingNew = true }
                    Button("Terug") { close() }
                }
                .foregroundColor(CoachPalette.textPrimary)
                .padding(24)
                .disabled(busy || failed)
            } else if showingSetup {
                MatchSetupView(playerStore: playerStore, title: "Nieuwe coachwedstrijd", onCancel: { close() }) { player1, player2, player1Id, player2Id in
                    startNewMatch(player1: player1, player2: player2, player1Id: player1Id, player2Id: player2Id)
                }
                .disabled(busy || failed)
            }
            if busy {
                ProgressView("Even opslaan…")
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
        .task { if match == nil && pending == nil && !showingSetup { await load() } }
        .alert("Nieuwe wedstrijd starten?", isPresented: $confirmingNew) {
            Button("Annuleren", role: .cancel) {}
            Button("Nieuwe wedstrijd", role: .destructive) {
                busy = true
                Task { @MainActor in
                    do {
                        if let pending { try await store.abandon(pending) }
                        pending = nil
                        showingSetup = true
                    } catch { failed = true }
                    busy = false
                }
            }
        } message: {
            Text("De huidige wedstrijd wordt als afgebroken bewaard.")
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

    private func startNewMatch(player1: String, player2: String, player1Id: String?, player2Id: String?) {
        showingSetup = false
        busy = true
        failed = false
        Task { @MainActor in
            let fresh = Match()
            fresh.setupMatch(
                player1: player1, player2: player2, startingServer: .player1,
                player1Id: player1Id.flatMap { UUID(uuidString: $0) },
                player2Id: player2Id.flatMap { UUID(uuidString: $0) }
            )
            match = fresh
            do { try await store.save(fresh) } catch { failed = true }
            busy = false
        }
    }

    private func persist(_ value: Match, exit: Bool) {
        guard !busy else { return }
        busy = true
        failed = false
        exitAfterSave = exit
        Task { @MainActor in
            do {
                try await store.save(value)
                busy = false
                if exit { close() }
            } catch {
                busy = false
                failed = true
            }
        }
    }

    @MainActor private func close() {
        onExit()
        dismiss()
    }
}
