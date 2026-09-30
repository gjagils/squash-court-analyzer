import Foundation
import SwiftUI
import SquashAnalyzerCore

/// Also embedded by iOS's editor, which retains its photo picker and save flow.
public struct PlayerProfileFields: View {
    @Binding private var name: String
    @Binding private var focus: [String]
    @Binding private var notes: String

    public init(name: Binding<String>, focus: Binding<[String]>, notes: Binding<String>) {
        _name = name
        _focus = focus
        _notes = notes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                caption("NAAM")
                TextField("Naam speler", text: $name)
                    .accessibilityLabel("Naam speler")
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 12) {
                caption("COACHING FOCUS")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(CoachingFocusTag.allCases, id: \.rawValue) { tag in
                        let selected = focus.contains(tag.rawValue)
                        Button {
                            if selected { focus.removeAll { $0 == tag.rawValue } }
                            else { focus.append(tag.rawValue) }
                        } label: {
                            Text(tag.rawValue)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(selected ? Color.black : PlayerStyle.text)
                                .background(selected ? PlayerStyle.gold : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tag.rawValue)
                        .accessibilityValue(selected ? "Geselecteerd" : "Niet geselecteerd")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                caption("NOTITIES")
                TextField("Extra coaching aandachtspunten...", text: $notes, axis: .vertical)
                    .accessibilityLabel("Coachingnotities")
                    .textFieldStyle(.plain)
                    .lineLimit(6)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .font(.system(size: 16, design: .rounded))
        .foregroundColor(PlayerStyle.text)
    }

    private func caption(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1).foregroundColor(PlayerStyle.gold)
    }
}

private enum PlayerStyle {
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let muted = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let background = Color(red: 0.06, green: 0.05, blue: 0.04)
}

public struct PlayerDirectoryView: View {
    private let store: any PlayerProfileStore
    private let badgeStore: any PlayerBadgeSummaryStore
    @State private var players: [PlayerProfile] = []
    @State private var badgeCounts: [String: Int] = [:]
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var isDeleting = false
    @State private var editing: PlayerProfile? = nil
    @State private var deleting: PlayerProfile? = nil
    @State private var confirmDelete = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var badgesForPlayer: PlayerProfile? = nil

    public init(store: any PlayerProfileStore, badgeStore: any PlayerBadgeSummaryStore) {
        self.store = store
        self.badgeStore = badgeStore
    }

    public var body: some View {
        ZStack {
            PlayerStyle.background.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    // Shrink the title rather than wrap it on narrow screens or large text
                    Text("SPELERS").font(.system(size: 22, weight: .bold, design: .rounded)).tracking(2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 8)
                    Button { editing = PlayerProfile() } label: {
                        Label("Toevoegen", systemImage: "plus")
                            .lineLimit(1)
                    }
                    .accessibilityLabel("Speler toevoegen")
                    .disabled(isLoading || isDeleting || loadFailed)
                }
                .foregroundColor(PlayerStyle.gold)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                if isLoading {
                    Spacer()
                    ProgressView("Spelers laden…")
                    Spacer()
                } else if loadFailed {
                    Spacer()
                    Text("Spelers konden niet worden geladen.")
                        .foregroundColor(PlayerStyle.muted)
                    Button("Opnieuw laden") { Task { await reload() } }
                        .tint(PlayerStyle.gold)
                    Spacer()
                } else if players.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle").font(.system(size: 48))
                        Text("Nog geen spelers opgeslagen").font(.headline)
                        Text("Voeg je eerste speler toe met +.")
                    }
                    .foregroundColor(PlayerStyle.muted)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(players) { player in
                                HStack(spacing: 12) {
                                    Text(String(player.name.prefix(1)).uppercased())
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(PlayerStyle.gold)
                                        .frame(width: 44, height: 44)
                                        .background(PlayerStyle.gold.opacity(0.15))
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(player.name).font(.headline)
                                        if !player.coachingFocusAreas.isEmpty {
                                            Text(player.coachingFocusAreas.joined(separator: " · "))
                                                .font(.caption).foregroundColor(PlayerStyle.muted)
                                        }
                                    }
                                    Spacer()
                                    if let count = badgeCounts[player.id], count > 0 {
                                        Button { badgesForPlayer = player } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "medal.fill")
                                                Text("\(count)")
                                            }
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(PlayerStyle.gold)
                                            .padding(.horizontal, 10).padding(.vertical, 8)
                                            .background(Capsule().fill(PlayerStyle.gold.opacity(0.12)))
                                        }
                                        .accessibilityLabel("\(count) badges van \(player.name)")
                                    }
                                    Button { editing = player } label: {
                                        Image(systemName: "pencil").frame(width: 44, height: 44)
                                    }.accessibilityLabel("Bewerk \(player.name)")
                                    Button {
                                        deleting = player
                                        confirmDelete = true
                                    } label: {
                                        Image(systemName: "trash").frame(width: 44, height: 44)
                                    }.accessibilityLabel("Verwijder \(player.name)")
                                }
                                .foregroundColor(PlayerStyle.text)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .disabled(isDeleting)
                            }
                        }.padding(.horizontal, 16).padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("Spelers")
        .task { await reload() }
        .sheet(item: $editing) { player in
            PlayerProfileEditor(player: player, store: store) { await reload() }
        }
        .navigationDestination(isPresented: Binding(get: { badgesForPlayer != nil }, set: { if !$0 { badgesForPlayer = nil } })) {
            if let player = badgesForPlayer {
                SharedPlayerBadgesView(playerId: player.id, playerName: player.name, badgeStore: badgeStore)
            }
        }
        .alert("Speler verwijderen?", isPresented: $confirmDelete) {
            Button("Annuleren", role: .cancel) { deleting = nil }
            Button("Verwijderen", role: .destructive) {
                guard let player = deleting else { return }
                isDeleting = true
                Task {
                    do {
                        try await store.deletePlayer(player.id)
                        await reload()
                    } catch { showError("Verwijderen is niet gelukt. Probeer het opnieuw.") }
                    isDeleting = false
                    deleting = nil
                }
            }
        } message: {
            Text("\(deleting?.name ?? "Deze speler") wordt verwijderd. Gespeelde wedstrijden blijven bewaard.")
        }
        .alert("Spelers konden niet worden bijgewerkt", isPresented: $showingError) {
            Button("Opnieuw proberen") { Task { await reload() } }
            Button("Sluiten", role: .cancel) {}
        } message: { Text(errorMessage) }
    }

    private func reload() async {
        isLoading = true
        do {
            players = try await store.loadPlayers()
            loadFailed = false
            var counts: [String: Int] = [:]
            for player in players {
                counts[player.id] = (try? await badgeStore.badges(forPlayer: player.id))?.count ?? 0
            }
            badgeCounts = counts
        } catch {
            loadFailed = true
            showError("De opgeslagen spelers konden niet worden geladen. Probeer het opnieuw.")
        }
        isLoading = false
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

private struct PlayerProfileEditor: View {
    let store: any PlayerProfileStore
    let onSaved: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var player: PlayerProfile
    @State private var isSaving = false
    @State private var showingError = false
    private let isNew: Bool

    init(player: PlayerProfile, store: any PlayerProfileStore, onSaved: @escaping () async -> Void) {
        self.store = store
        self.onSaved = onSaved
        self.isNew = player.name.isEmpty
        _player = State(initialValue: player)
    }

    var body: some View {
        ZStack {
            PlayerStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text(isNew ? "SPELER TOEVOEGEN" : "SPELER BEWERKEN")
                        .font(.system(size: 18, weight: .bold, design: .rounded)).tracking(2)
                    PlayerProfileFields(name: $player.name, focus: $player.coachingFocusAreas, notes: $player.coachingNotes)
                    HStack(spacing: 16) {
                        Button("Annuleren") { dismiss() }.disabled(isSaving)
                        Spacer()
                        Button(isSaving ? "Opslaan…" : "Opslaan") {
                            isSaving = true
                            Task {
                                do {
                                    var normalized = player
                                    normalized.name = player.trimmedName
                                    try await store.savePlayer(normalized)
                                    await onSaved()
                                    dismiss()
                                } catch {
                                    isSaving = false
                                    showingError = true
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PlayerStyle.gold)
                        .disabled(!player.isValid || isSaving)
                    }
                }
                .foregroundColor(PlayerStyle.text)
                .padding(24)
                .disabled(isSaving)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .alert("Opslaan is niet gelukt", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Je invoer is bewaard in dit scherm. Probeer opnieuw op te slaan.") }
    }
}
