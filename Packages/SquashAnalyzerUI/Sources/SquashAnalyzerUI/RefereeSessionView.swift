import SwiftUI
import SquashAnalyzerCore

/// Serializes UI edits with durable writes, mirroring `CoachSessionView`. A
/// failed save keeps the live match on screen and blocks further edits until
/// retry succeeds.
public struct RefereeSessionView: View {
    let store: any RefereeMatchStore
    let onExit: @MainActor () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var match: RefereeMatch? = nil
    @State private var pending: RefereeMatch? = nil
    @State private var busy = true
    @State private var failed = false
    @State private var confirmingNew = false
    @State private var exitAfterSave = false

    public init(store: any RefereeMatchStore, onExit: @escaping @MainActor () -> Void) {
        self.store = store
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            CoachPalette.backgroundDark.ignoresSafeArea()
            if let match {
                RefereeScoringView(match: match, onMatchChanged: { changed in
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
        .task { if match == nil && pending == nil { await load() } }
        .alert("Nieuwe wedstrijd starten?", isPresented: $confirmingNew) {
            Button("Annuleren", role: .cancel) {}
            Button("Nieuwe wedstrijd", role: .destructive) {
                busy = true
                Task { @MainActor in
                    do {
                        if let pending { try await store.abandon(pending) }
                        pending = nil
                        let fresh = RefereeSessionView.freshMatch()
                        match = fresh
                        try await store.save(fresh)
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
            else {
                let fresh = RefereeSessionView.freshMatch()
                match = fresh
                try await store.save(fresh)
            }
        } catch { failed = true }
        busy = false
    }

    private func persist(_ value: RefereeMatch, exit: Bool) {
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

    private static func freshMatch() -> RefereeMatch {
        RefereeMatch(player1Name: "Speler 1", player2Name: "Speler 2", bestOf: 5, startingServer: .player1)
    }
}
