import Foundation
import SwiftUI
import SquashAnalyzerCore

/// Also embedded by iOS's editor, which retains its photo picker and save flow.
public struct PlayerProfileFields: View {
    @Binding private var name: String
    @Binding private var focus: [String]
    @Binding private var notes: String
    /// The player's id once it exists: shows the switch "In mijn team"
    private let playerId: String?
    @AppStorage(TeamRoster.storageKey) private var rosterRaw = ""

    public init(name: Binding<String>, focus: Binding<[String]>, notes: Binding<String>, playerId: String? = nil) {
        _name = name
        _focus = focus
        _notes = notes
        self.playerId = playerId
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                caption(loc("NAAM"))
                TextField(loc("Naam speler"), text: $name)
                    .accessibilityLabel(loc("Naam speler"))
                    .textFieldStyle(.plain)
                    .padding()
                    .background(SharedColors.tint(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if let playerId {
                VStack(alignment: .leading, spacing: 8) {
                    caption("TEAM")
                    Toggle(isOn: Binding(get: { TeamRoster.contains(playerId, in: rosterRaw) },
                                         set: { rosterRaw = TeamRoster.setting(playerId, inTeam: $0, in: rosterRaw) })) {
                        Text("In mijn team", bundle: textBundle)
                    }
                    .tint(SharedColors.accent)
                    Text("Spelers in je team staan bovenaan als je een partij van een teamwedstrijd invult.", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textMuted)
                }
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
                            Text(tag.title)
                                .font(SharedFonts.system(12, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundColor(selected ? SharedColors.onAccent : SharedColors.textPrimary)
                                .background(selected ? SharedColors.accent : SharedColors.tint(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tag.title)
                        .accessibilityValue(selected ? loc("Geselecteerd") : loc("Niet geselecteerd"))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                caption(loc("NOTITIES"))
                TextField(loc("Extra coaching aandachtspunten..."), text: $notes, axis: .vertical)
                    .accessibilityLabel(loc("Coachingnotities"))
                    .textFieldStyle(.plain)
                    .lineLimit(6)
                    .padding()
                    .background(SharedColors.tint(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .font(SharedFonts.system(16, design: .rounded))
        .foregroundColor(SharedColors.textPrimary)
    }

    private func caption(_ title: String) -> some View {
        Text(title).font(SharedFonts.system(11, weight: .semibold, design: .rounded))
            .tracking(1).foregroundColor(SharedColors.accent)
    }
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
    @State private var showingCatalog = false
    @State private var showingTeamImport = false
    @State private var photos: [String: Data] = [:]
    @AppStorage(TeamRoster.storageKey) private var rosterRaw = ""

    private let shareText: (String) -> Void
    /// Reloads after a card link was imported while this screen was open
    private let cardInbox: CardInbox
    /// Spelers → Team: import a team from a squashanalyzer.com/teams link or a zip
    private let teamImporter: (any TeamLinkImporter)?
    /// Player photos (Android: Room); nil shows initials only
    private let photoStore: (any PlayerPhotoStore)?
    /// The system photo and file pickers
    private let filePicker: (any PlayerFilePicker)?
    /// "Deel kaart" with a picture
    private let shareCard: ((CardSnapshot, String) -> Void)?
    /// The matches for a player's profile; nil leaves the profile out
    private let historyStore: (any MatchHistoryStore)?

    public init(store: any PlayerProfileStore, badgeStore: any PlayerBadgeSummaryStore,
                shareText: @escaping (String) -> Void, cardInbox: CardInbox, teamImporter: (any TeamLinkImporter)? = nil,
                photoStore: (any PlayerPhotoStore)? = nil, filePicker: (any PlayerFilePicker)? = nil,
                shareCard: ((CardSnapshot, String) -> Void)? = nil, historyStore: (any MatchHistoryStore)? = nil) {
        self.historyStore = historyStore
        self.teamImporter = teamImporter
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.store = store
        self.badgeStore = badgeStore
        self.shareText = shareText
        self.shareCard = shareCard
        self.cardInbox = cardInbox
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    // The page title is in the top bar (pageTitle); only the actions here
                    Spacer(minLength: 8)
                    // All badges, as iOS' medal button in Spelers
                    Button { showingCatalog = true } label: {
                        AppSymbol("medal", size: 20, color: SharedColors.gold)
                            .frame(width: 36, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(loc("Alle badges"))
                    if teamImporter != nil {
                        Button { showingTeamImport = true } label: {
                            // AppSymbol: Skip's Label(systemImage:) draws a warning triangle for this symbol
                            HStack(spacing: 6) {
                                AppSymbol("square.and.arrow.down", size: 18, color: SharedColors.accent)
                                Text("Team").lineLimit(1)
                            }
                        }
                        .accessibilityLabel(loc("Team importeren"))
                        .disabled(isLoading || isDeleting || loadFailed)
                    }
                    Button { editing = PlayerProfile() } label: {
                        Label(loc("Toevoegen"), systemImage: "plus")
                            .lineLimit(1)
                    }
                    .accessibilityLabel(loc("Speler toevoegen"))
                    .disabled(isLoading || isDeleting || loadFailed)
                }
                .foregroundColor(SharedColors.accent)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                if isLoading {
                    Spacer()
                    ProgressView(loc("Spelers laden…"))
                    Spacer()
                } else if loadFailed {
                    Spacer()
                    Text("Spelers konden niet worden geladen.", bundle: textBundle)
                        .foregroundColor(SharedColors.textSecondary)
                    Button(loc("Opnieuw laden")) { Task { await reload() } }
                        .tint(SharedColors.accent)
                    Spacer()
                } else if players.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        AppSymbol("person.crop.circle", size: 48, color: SharedColors.textSecondary)
                        Text("Nog geen spelers opgeslagen", bundle: textBundle).font(.headline)
                        Text("Tik op + om een speler toe te voegen,\nof importeer een team (zip met team.json en foto's)", bundle: textBundle)
                    }
                    .foregroundColor(SharedColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(players) { player in
                                HStack(spacing: 12) {
                                    // Tap the player for their badges, as on iOS
                                    Button { badgesForPlayer = player } label: {
                                        HStack(spacing: 12) {
                                            PlayerPhotoView(photo: photos[player.id], name: player.name, size: 44, color: SharedColors.gold)
                                            VStack(alignment: .leading, spacing: 5) {
                                                HStack(spacing: 8) {
                                                    Text(player.name).font(.headline)
                                                    if TeamRoster.contains(player.id, in: rosterRaw) {
                                                        Text("TEAM")
                                                            .font(SharedFonts.system(9, weight: .bold, design: .rounded))
                                                            .tracking(1)
                                                            .foregroundColor(SharedColors.accent)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(SharedColors.accent.opacity(0.14))
                                                            .clipShape(Capsule())
                                                    }
                                                    // Badge count right after the name, as on iOS
                                                    if let count = badgeCounts[player.id], count > 0 {
                                                        HStack(spacing: 3) {
                                                            AppSymbol("medal.fill", size: 11, color: SharedColors.gold)
                                                            Text("\(count)")
                                                                .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                                                                .foregroundColor(SharedColors.gold)
                                                        }
                                                    }
                                                }
                                                if !player.coachingFocusAreas.isEmpty {
                                                    HStack(spacing: 6) {
                                                        ForEach(player.coachingFocusAreas, id: \.self) { tag in
                                                            TagChip(tag, color: SharedColors.gold, size: 10, fillOpacity: 0.15)
                                                        }
                                                    }
                                                } else if !player.coachingNotes.isEmpty {
                                                    Text(player.coachingNotes)
                                                        .font(SharedFonts.system(11)).foregroundColor(SharedColors.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(badgeCounts[player.id].map { $0 > 0 ? loc("\($0) badges van \(player.name)") : loc("Badges van \(player.name)") } ?? loc("Badges van \(player.name)"))
                                    Spacer()
                                    Button { editing = player } label: {
                                        AppSymbol("pencil", size: 18, color: SharedColors.textPrimary).frame(width: 44, height: 44)
                                    }.accessibilityLabel(loc("Bewerk \(player.name)"))
                                    Button {
                                        deleting = player
                                        confirmDelete = true
                                    } label: {
                                        AppSymbol("trash", size: 18, color: SharedColors.textPrimary).frame(width: 44, height: 44)
                                    }.accessibilityLabel(loc("Verwijder \(player.name)"))
                                }
                                .foregroundColor(SharedColors.textPrimary)
                                .padding(12)
                                .background(SharedColors.tint(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                // Long press, as on iOS
                                .contextMenu {
                                    Button("Badges") { badgesForPlayer = player }
                                    Button(loc("Bewerken")) { editing = player }
                                    Button(loc("Verwijderen"), role: .destructive) {
                                        deleting = player
                                        confirmDelete = true
                                    }
                                }
                                .disabled(isDeleting)
                            }
                        }.padding(.horizontal, 16).padding(.bottom, 24)
                    }
                }
            }
        }
        .pageTitle(loc("Spelers"))
        .navigationDestination(isPresented: $showingCatalog) {
            SharedBadgeCatalogView()
        }
        .task(id: cardInbox.importCount) { await reload() }
        .sheet(isPresented: $showingTeamImport) {
            if let teamImporter {
                SharedTeamImportView(importer: teamImporter, filePicker: filePicker, onImported: { await reload() }) { showingTeamImport = false }
            }
        }
        .sheet(item: $editing) { player in
            PlayerProfileEditor(player: player, store: store, photo: photos[player.id], photoStore: photoStore,
                                filePicker: filePicker) { await reload() }
        }
        .navigationDestination(isPresented: Binding(get: { badgesForPlayer != nil }, set: { if !$0 { badgesForPlayer = nil } })) {
            if let player = badgesForPlayer {
                SharedPlayerBadgesView(playerId: player.id, playerName: player.name, photo: photos[player.id], badgeStore: badgeStore, shareText: shareText,
                                       shareCard: shareCard, cardInbox: cardInbox, historyStore: historyStore)
            }
        }
        .alert(loc("Speler verwijderen?"), isPresented: $confirmDelete) {
            Button(loc("Annuleren"), role: .cancel) { deleting = nil }
            Button(loc("Verwijderen"), role: .destructive) {
                guard let player = deleting else { return }
                isDeleting = true
                Task {
                    do {
                        try await store.deletePlayer(player.id)
                        await reload()
                    } catch { showError(loc("Verwijderen is niet gelukt. Probeer het opnieuw.")) }
                    isDeleting = false
                    deleting = nil
                }
            }
        } message: {
            Text("\(deleting?.name ?? loc("Deze speler")) wordt verwijderd. Gespeelde wedstrijden blijven bewaard.", bundle: textBundle)
        }
        .alert(loc("Spelers konden niet worden bijgewerkt"), isPresented: $showingError) {
            Button(loc("Opnieuw proberen")) { Task { await reload() } }
            Button(loc("Sluiten"), role: .cancel) {}
        } message: { Text(errorMessage) }
    }

    private func reload() async {
        isLoading = true
        do {
            players = try await store.loadPlayers()
            loadFailed = false
            badgeCounts = (try? await badgeStore.badgeCounts(forPlayers: players.map { player in player.id })) ?? [:]
            if let photoStore {
                photos = (try? await photoStore.photos()) ?? [:]
            }
        } catch {
            loadFailed = true
            showError(loc("De opgeslagen spelers konden niet worden geladen. Probeer het opnieuw."))
        }
        isLoading = false
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

struct PlayerProfileEditor: View {
    let store: any PlayerProfileStore
    let photoStore: (any PlayerPhotoStore)?
    let filePicker: (any PlayerFilePicker)?
    let onSaved: () async -> Void
    /// The photo shown; `photoChanged` says whether to store it on save
    @State private var photo: Data?
    @State private var photoChanged = false
    @Environment(\.dismiss) private var dismiss
    @State private var player: PlayerProfile
    @State private var isSaving = false
    @State private var showingError = false
    @State private var photoFailed = false
    private let isNew: Bool

    private var photoSection: some View {
        VStack(spacing: 10) {
            // Tap the avatar to pick a photo, as on iOS (camera badge bottom right)
            Button { pickPhoto() } label: {
                ZStack(alignment: .bottomTrailing) {
                    PlayerPhotoView(photo: photo, name: player.name.isEmpty ? "?" : player.name, size: 96, color: SharedColors.gold)
                    AppSymbol("camera.fill", size: 13, color: SharedColors.background)
                        .frame(width: 28, height: 28)
                        .background(SharedColors.gold)
                        .clipShape(Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(photo == nil ? loc("Kies foto") : loc("Andere foto"))
            HStack(spacing: 20) {
                if photo != nil {
                    Button(loc("Foto verwijderen")) {
                        photo = nil
                        photoChanged = true
                    }
                    .foregroundColor(SharedColors.textSecondary)
                }
            }
        }
    }

    private func pickPhoto() {
        Task {
            do {
                if let picked = try await filePicker?.pickPhoto() {
                    photo = picked
                    photoChanged = true
                }
            } catch {
                photoFailed = true
            }
        }
    }

    init(player: PlayerProfile, store: any PlayerProfileStore, photo: Data?, photoStore: (any PlayerPhotoStore)?,
         filePicker: (any PlayerFilePicker)?, onSaved: @escaping () async -> Void) {
        self.store = store
        self.photoStore = photoStore
        self.filePicker = filePicker
        _photo = State(initialValue: photo)
        self.onSaved = onSaved
        self.isNew = player.name.isEmpty
        _player = State(initialValue: player)
    }

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text(isNew ? loc("SPELER TOEVOEGEN") : loc("SPELER BEWERKEN"))
                        .font(SharedFonts.system(18, weight: .bold, design: .rounded)).tracking(2)
                    if photoStore != nil && filePicker != nil {
                        photoSection
                    }
                    PlayerProfileFields(name: $player.name, focus: $player.coachingFocusAreas, notes: $player.coachingNotes, playerId: player.id)
                    HStack(spacing: 16) {
                        Button(loc("Annuleren")) { dismiss() }.disabled(isSaving)
                        Spacer()
                        Button(isSaving ? loc("Opslaan…") : loc("Opslaan")) {
                            isSaving = true
                            Task {
                                do {
                                    var normalized = player
                                    normalized.name = player.trimmedName
                                    try await store.savePlayer(normalized)
                                    if photoChanged, let photoStore {
                                        try await photoStore.setPhoto(photo, for: normalized.id)
                                    }
                                    await onSaved()
                                    dismiss()
                                } catch {
                                    isSaving = false
                                    showingError = true
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SharedColors.accent)
                        .disabled(!player.isValid || isSaving)
                    }
                }
                .foregroundColor(SharedColors.textPrimary)
                .padding(24)
                .disabled(isSaving)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .alert(loc("Deze foto kon niet worden gebruikt"), isPresented: $photoFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert(loc("Opslaan is niet gelukt"), isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Je invoer is bewaard in dit scherm. Probeer opnieuw op te slaan.", bundle: textBundle) }
    }
}
