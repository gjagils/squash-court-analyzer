import SwiftUI
import SquashAnalyzerCore

/// Shown when a card link is opened: what it would change, then link it to a
/// local player (or a new one) and merge its badges. Android's counterpart of
/// iOS' `CardImportSheet` (named `Shared...` so the two never collide), with
/// the same wording.
public struct SharedCardImportView: View {
    let snapshot: CardSnapshot
    let store: any CardImportStore
    let onClose: () -> Void

    @State private var preview: CardImportPreview?
    @State private var isImporting = false
    @State private var failed = false

    public init(snapshot: CardSnapshot, store: any CardImportStore, onClose: @escaping () -> Void) {
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
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(BadgePalette.textPrimary)
                        Text(preview?.summary ?? "Kaart lezen…")
                            .font(.system(size: 13))
                            .foregroundColor(BadgePalette.textSecondary)
                    }
                    .listRowBackground(Color.clear)
                }

                if let preview {
                    if let linked = preview.linkedPlayer {
                        Section {
                            Button("Bijwerken bij \(linked.name)") { importCard(to: linked.id) }
                                .foregroundColor(BadgePalette.gold)
                                .disabled(isImporting)
                        }
                    } else {
                        Section("Koppel aan") {
                            Button("Nieuwe speler \(snapshot.name)") { importCard(to: nil) }
                                .foregroundColor(BadgePalette.gold)
                                .disabled(isImporting)
                            ForEach(preview.players) { player in
                                Button { importCard(to: player.id) } label: {
                                    HStack {
                                        Text(player.name)
                                            .foregroundColor(BadgePalette.textPrimary)
                                        Spacer()
                                        if player.name.lowercased() == snapshot.name.lowercased() {
                                            Text("zelfde naam")
                                                .font(.system(size: 11))
                                                .foregroundColor(BadgePalette.textMuted)
                                        }
                                    }
                                }
                                .disabled(isImporting)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spelerskaart")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { onClose() }
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
                onClose()
            } catch {
                isImporting = false
                failed = true
            }
        }
    }
}
