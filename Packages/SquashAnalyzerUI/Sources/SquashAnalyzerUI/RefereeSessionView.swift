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
    @State private var photos: [String: Data] = [:]
    let onExit: @MainActor () -> Void
    /// The platform share sheet, for "Deel score"
    let shareText: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var match: RefereeMatch? = nil
    @State private var pending: RefereeMatch? = nil
    @State private var showingSetup = false
    @State private var busy = true
    @State private var failed = false
    @State private var confirmingNew = false
    @State private var exitAfterSave = false
    /// A change came in while saving; save once more when done
    @State private var saveAgain = false

    public init(store: any RefereeMatchStore, playerStore: any PlayerProfileStore, photoStore: (any PlayerPhotoStore)? = nil, shareText: ((String) -> Void)? = nil,
                onExit: @escaping @MainActor () -> Void) {
        self.shareText = shareText
        self.store = store
        self.playerStore = playerStore
        self.photoStore = photoStore
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            CoachPalette.backgroundDark.ignoresSafeArea()
            if let match {
                RefereeScoringView(match: match, shareText: shareText, photos: photos, onMatchChanged: { changed in
                    persist(changed, exit: false)
                }, onExit: { persist(match, exit: true) })
                .disabled(busy || failed)
            } else if let pending {
                VStack(spacing: 24) {
                    Text("Wedstrijd hervatten").font(.title2.bold())
                    Text("\(pending.player1Name) – \(pending.player2Name)")
                    Text("Game \(pending.currentGameNumber) · \(pending.player1Score) – \(pending.player2Score)")
                    Button("Hervatten") { match = pending; self.pending = nil }
                        .buttonStyle(.borderedProminent)
                    Button("Nieuwe wedstrijd") { confirmingNew = true }
                    Button("Terug") { close() }
                }
                .foregroundColor(CoachPalette.textPrimary)
                .padding(24)
                .disabled(busy || failed)
            } else if showingSetup {
                MatchSetupView(playerStore: playerStore, title: "Nieuwe scheidsrechterwedstrijd", onCancel: { close() }) { choice in
                    startNewMatch(choice)
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
        .task {
            if let photoStore { photos = (try? await photoStore.photos()) ?? [:] }
            if match == nil && pending == nil && !showingSetup { await load() }
        }
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

    private func startNewMatch(_ choice: MatchSetupChoice) {
        showingSetup = false
        busy = true
        failed = false
        Task { @MainActor in
            let fresh = RefereeMatch(player1Name: choice.player1Name, player2Name: choice.player2Name, bestOf: 5,
                                     startingServer: choice.startingServer,
                                     player1GamesBefore: choice.player1GamesBefore, player2GamesBefore: choice.player2GamesBefore)
            fresh.player1Id = choice.player1Id.flatMap { UUID(uuidString: $0) }
            fresh.player2Id = choice.player2Id.flatMap { UUID(uuidString: $0) }
            match = fresh
            do { try await store.save(fresh) } catch { failed = true }
            busy = false
        }
    }

    /// Saves `value`. A change while a save is running is saved right after
    /// it (with the latest state), never dropped.
    private func persist(_ value: RefereeMatch, exit: Bool) {
        if exit { exitAfterSave = true }
        if busy {
            saveAgain = true
            return
        }
        busy = true
        failed = false
        Task { @MainActor in
            do {
                try await store.save(value)
                if saveAgain, let latest = match {
                    saveAgain = false
                    busy = false
                    persist(latest, exit: false)
                    return
                }
                busy = false
                if exitAfterSave { close() }
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
