import SwiftUI
import SquashAnalyzerCore

/// Shown when a card link is opened: what it would change, then link it to a
/// local player (or a new one) and merge its badges. Android's counterpart of
/// iOS' `CardImportSheet` (named `Shared...` so the two never collide), with
/// the same wording.
public struct SharedCardImportView: View {
    let snapshot: CardSnapshot
    let store: any CardImportStore
    /// Called with true after an import, false after "Annuleren"
    let onClose: (Bool) -> Void

    @State private var preview: CardImportPreview?
    @State private var isImporting = false
    @State private var failed = false

    public init(snapshot: CardSnapshot, store: any CardImportStore, onClose: @escaping (Bool) -> Void) {
        self.snapshot = snapshot
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.name)
                            .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                            .foregroundColor(SharedColors.textPrimary)
                        Text(preview?.summary ?? "Kaart lezen…")
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                    .listRowBackground(Color.clear)
                }

                if let preview {
                    if let linked = preview.linkedPlayer {
                        Section {
                            Button { importCard(to: linked.id) } label: {
                                HStack(spacing: 8) {
                                    AppSymbol("arrow.triangle.2.circlepath", size: 16, color: SharedColors.gold)
                                    Text("Bijwerken bij \(linked.name)").foregroundColor(SharedColors.gold)
                                }
                            }
                            .disabled(isImporting)
                        }
                    } else {
                        Section("Koppel aan") {
                            Button { importCard(to: nil) } label: {
                                HStack(spacing: 8) {
                                    AppSymbol("person.badge.plus", size: 16, color: SharedColors.gold)
                                    Text("Nieuwe speler \(snapshot.name)").foregroundColor(SharedColors.gold)
                                }
                            }
                            .disabled(isImporting)
                            ForEach(preview.players) { player in
                                Button { importCard(to: player.id) } label: {
                                    HStack {
                                        Text(player.name)
                                            .foregroundColor(SharedColors.textPrimary)
                                        Spacer()
                                        if player.name.lowercased() == snapshot.name.lowercased() {
                                            Text("zelfde naam")
                                                .font(SharedFonts.system(11))
                                                .foregroundColor(SharedColors.textMuted)
                                        }
                                    }
                                }
                                .disabled(isImporting)
                            }
                        }
                    }
                }
            }
            .pageTitle("Spelerskaart")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(title: "Annuleren") { onClose(false) }
                }
            }
            .alert("Koppelen mislukt", isPresented: $failed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("De kaart van \(snapshot.name) kon niet worden bewaard.")
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadPreview() }
    }

    private func loadPreview() async {
        do {
            preview = try await store.importPreview(snapshot)
        } catch {
            failed = true
        }
    }

    private func importCard(to playerId: String?) {
        isImporting = true
        Task {
            do {
                try await store.importCard(snapshot, toPlayer: playerId)
                isImporting = false
                onClose(true)
            } catch {
                isImporting = false
                failed = true
            }
        }
    }
}
