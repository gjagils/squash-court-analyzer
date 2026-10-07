import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import SquashAnalyzerCore
import SquashAnalyzerUI

/// View for managing saved player profiles
struct PlayerManagementView: View {
    /// Card imports are handled app-wide (ContentView); the badge screen only needs one to refresh on
    @State private var badgeInbox = CardInbox()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedPlayer.name) private var players: [SavedPlayer]
    @Query(filter: #Predicate<SavedBadgeAward> { $0.deletedAt == nil }) private var activeAwards: [SavedBadgeAward]

    /// Badges with tiers count once, like Android's `badgeCounts` and the
    /// "x van 37" on the player screen
    private func badgeFamilyCount(for player: SavedPlayer) -> Int {
        Set(activeAwards.filter { $0.cardId == player.badgeCardId }
            .compactMap { BadgeKind(rawValue: $0.badge)?.family }).count
    }

    /// When set, the view acts as a picker and calls this on selection
    var onSelectPlayer: ((SavedPlayer) -> Void)? = nil

    @State private var showingAddPlayer = false
    @State private var playerToEdit: SavedPlayer? = nil
    @State private var playerForBadges: SavedPlayer? = nil
    @State private var showingBadgeCatalog = false
    @State private var showingTeamImporter = false
    @State private var teamImportMessage: String? = nil
    @State private var showingTeamLink = false
    @State private var teamLink = ""
    @State private var importingTeam = false
    @State private var showingTeamImportResult = false

    var isPickerMode: Bool { onSelectPlayer != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text(isPickerMode ? "Annuleren" : "Sluiten")
                            }
                            .font(AppFonts.body(14))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                        }

                        Spacer(minLength: 8)

                        // Five controls share one row: shrink the title rather than wrap it
                        Text(isPickerMode ? "Kies speler" : "Spelers")
                            .font(PageTitleStyle.font)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Spacer(minLength: 8)

                        HStack(spacing: 14) {
                            Button(action: { showingBadgeCatalog = true }) {
                                Image(systemName: "medal")
                                    .font(SharedFonts.system(20))
                                    .foregroundColor(AppColors.accentGold)
                            }
                            .accessibilityLabel("Alle badges")

                            Menu {
                                Button { showingTeamImporter = true } label: {
                                    Label("Uit bestand (zip)", systemImage: "doc.zipper")
                                }
                                Button { teamLink = ""; showingTeamLink = true } label: {
                                    Label("Via link", systemImage: "link")
                                }
                            } label: {
                                if importingTeam {
                                    ProgressView()
                                        .tint(AppColors.accentGold)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(SharedFonts.system(20))
                                        .foregroundColor(AppColors.accentGold)
                                }
                            }
                            .disabled(importingTeam)
                            .accessibilityLabel("Importeer team")

                            Button(action: { showingAddPlayer = true }) {
                                Image(systemName: "plus.circle")
                                    .font(SharedFonts.system(22))
                                    .foregroundColor(AppColors.accentGold)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                    if players.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(SharedFonts.system(40))
                                .foregroundColor(AppColors.textMuted)
                            Text("Nog geen spelers opgeslagen")
                                .font(AppFonts.body(16))
                                .foregroundColor(AppColors.textSecondary)
                            Text("Tik op + om een speler toe te voegen,\nof importeer een team (zip met team.json en foto's)")
                                .font(AppFonts.caption(13))
                                .foregroundColor(AppColors.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(players) { player in
                                    PlayerRowView(
                                        player: player,
                                        isPickerMode: isPickerMode,
                                        badgeCount: badgeFamilyCount(for: player),
                                        onSelect: {
                                            onSelectPlayer?(player)
                                            dismiss()
                                        },
                                        onShowBadges: {
                                            playerForBadges = player
                                        },
                                        onEdit: {
                                            playerToEdit = player
                                        },
                                        onDelete: {
                                            modelContext.delete(player)
                                            try? modelContext.save()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showingAddPlayer) {
                PlayerEditSheet(player: nil) { name, focus, notes, photo in
                    let newPlayer = SavedPlayer(name: name, coachingFocusAreas: focus, coachingNotes: notes, photoData: photo)
                    modelContext.insert(newPlayer)
                    try? modelContext.save()
                }
            }
            .navigationDestination(isPresented: $showingBadgeCatalog) {
                SharedBadgeCatalogView()
            }
            .navigationDestination(item: $playerForBadges) { player in
                // The shared badge screen (as on Android): badges, earning moments and "Deel kaart"
                SharedPlayerBadgesView(playerId: player.id.uuidString, playerName: player.name, photo: player.photoData,
                                       badgeStore: SwiftDataBadgeSummaryStore(context: modelContext),
                                       shareText: { IOSShare.text($0) },
                                       shareCard: { snapshot, text in IOSShare.card(snapshot, text: text) },
                                       cardInbox: badgeInbox)
            }
            .navigationDestination(item: $playerToEdit) { player in
                PlayerEditSheet(player: player) { name, focus, notes, photo in
                    player.name = name
                    player.coachingFocusAreas = focus
                    player.coachingNotes = notes
                    player.photoData = photo
                    try? modelContext.save()
                }
            }
            .fileImporter(isPresented: $showingTeamImporter, allowedContentTypes: [.zip]) { result in
                importTeam(result)
            }
            .alert("Team via link", isPresented: $showingTeamLink) {
                TextField("https://squashanalyzer.com/teams/…", text: $teamLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button("Annuleren", role: .cancel) { }
                Button("Importeren") { importTeam(link: teamLink) }
            } message: {
                Text("Plak de teamlink die je hebt gekregen.")
            }
            .alert("Team importeren", isPresented: $showingTeamImportResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(teamImportMessage ?? "")
            }
        }
    }

    // MARK: - Team import (zip with team.json + photos, see TeamImportService)

    private func importTeam(link: String) {
        importingTeam = true
        Task {
            do {
                let imported = try await TeamImportService.importTeam(link: link, context: modelContext)
                teamImportMessage = "Geïmporteerd: \(imported.summary)"
            } catch {
                teamImportMessage = error.localizedDescription
            }
            importingTeam = false
            showingTeamImportResult = true
        }
    }

    private func importTeam(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileReadNoPermission)
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let imported = try TeamImportService.importTeam(zipData: data, context: modelContext)
            teamImportMessage = "Geïmporteerd: \(imported.summary)"
        } catch {
            teamImportMessage = error.localizedDescription
        }
        showingTeamImportResult = true
    }
}

// MARK: - Player Row

struct PlayerRowView: View {
    let player: SavedPlayer
    let isPickerMode: Bool
    var badgeCount = 0
    let onSelect: () -> Void
    var onShowBadges: () -> Void = {}
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false
    @AppStorage(TeamRoster.storageKey) private var rosterRaw = ""

    var body: some View {
        HStack(spacing: 14) {
            // Avatar: photo when set, otherwise the initial
            if let data = player.photoData, let image = UIImage(data: data) {
                PlayerAvatarImage(photo: image, color: AppColors.accentGold, size: 42)
            } else {
                Circle()
                    .fill(AppColors.accentGold.opacity(0.2))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(player.name.prefix(1)).uppercased())
                            .font(AppFonts.title(18))
                            .foregroundColor(AppColors.accentGold)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(player.name)
                        .font(AppFonts.label(15))
                        .foregroundColor(AppColors.textPrimary)
                    if TeamRoster.contains(player.id.uuidString, in: rosterRaw) {
                        Text("TEAM")
                            .font(AppFonts.caption(9))
                            .tracking(1)
                            .foregroundColor(AppColors.warmOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.warmOrange.opacity(0.14)))
                    }
                    if badgeCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "medal.fill")
                                .font(SharedFonts.system(10))
                            Text("\(badgeCount)")
                                .font(AppFonts.caption(11))
                        }
                        .foregroundColor(AppColors.accentGold)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(badgeCount) badges")
                    }
                }

                if !player.coachingFocusAreas.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(player.coachingFocusAreas, id: \.self) { tag in
                                Text(tag)
                                    .font(AppFonts.caption(10))
                                    .foregroundColor(AppColors.accentGold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(AppColors.accentGold.opacity(0.15))
                                    )
                            }
                        }
                    }
                } else if !player.coachingNotes.isEmpty {
                    Text(player.coachingNotes)
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isPickerMode {
                Button(action: onSelect) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(SharedFonts.system(24))
                        .foregroundColor(AppColors.accentGold)
                }
            } else {
                HStack(spacing: 18) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(SharedFonts.system(16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Button(action: { showingDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(SharedFonts.system(15))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .accessibilityLabel("Verwijder \(player.name)")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        // swipeActions only work inside a List, so offer the actions on long press too
        .contextMenu {
            if !isPickerMode {
                Button(action: onShowBadges) {
                    Label("Badges", systemImage: "medal")
                }
                Button(action: onEdit) {
                    Label("Bewerken", systemImage: "pencil")
                }
            }
            Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                Label("Verwijderen", systemImage: "trash")
            }
        }
        .alert("\(player.name) verwijderen?", isPresented: $showingDeleteConfirm) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive, action: onDelete)
        } message: {
            Text("Gespeelde wedstrijden blijven bewaard.")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isPickerMode { onSelect() } else { onShowBadges() }
        }
    }
}

// MARK: - Player Edit Sheet

struct PlayerEditSheet: View {
    let player: SavedPlayer?
    /// name, focus areas, notes, normalised photo
    let onSave: (String, [String], String, Data?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedFocusAreas: Set<String>
    @State private var notes: String
    @State private var photoData: Data?
    @State private var pickedPhoto: PhotosPickerItem? = nil

    init(player: SavedPlayer?, onSave: @escaping (String, [String], String, Data?) -> Void) {
        self.player = player
        self.onSave = onSave
        _name = State(initialValue: player?.name ?? "")
        _selectedFocusAreas = State(initialValue: Set(player?.coachingFocusAreas ?? []))
        _notes = State(initialValue: player?.coachingNotes ?? "")
        _photoData = State(initialValue: player?.photoData)
    }

    private var photoImage: UIImage? {
        photoData.flatMap(UIImage.init(data:))
    }

    // Photo picker with the avatar as preview
    private var photoSection: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    PlayerAvatarImage(photo: photoImage, color: AppColors.accentGold, size: 96)
                    Image(systemName: "camera.fill")
                        .font(SharedFonts.system(12, weight: .semibold))
                        .foregroundColor(AppColors.backgroundDark)
                        .padding(7)
                        .background(Circle().fill(AppColors.accentGold))
                }
            }
            .buttonStyle(.plain)

            if photoData != nil {
                Button(action: { photoData = nil; pickedPhoto = nil }) {
                    Text("Foto verwijderen")
                        .font(AppFonts.caption(12))
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoData = PlayerPhoto.normalized(data)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    Text(player == nil ? "SPELER TOEVOEGEN" : "SPELER BEWERKEN")
                        .font(AppFonts.title(18))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(3)
                        .padding(.top, 32)

                    photoSection

                    PlayerProfileFields(
                        name: $name,
                        focus: Binding(
                            get: { Array(selectedFocusAreas).sorted() },
                            set: { selectedFocusAreas = Set($0) }
                        ),
                        notes: $notes,
                        playerId: player?.id.uuidString
                    )
                    .padding(.horizontal, 24)

                    // Save / Cancel
                    HStack(spacing: 16) {
                        Button(action: { dismiss() }) {
                            Text("Annuleren")
                                .font(AppFonts.label(14))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.07)))
                        }

                        Button(action: {
                            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            onSave(name.trimmingCharacters(in: .whitespaces), Array(selectedFocusAreas), notes, photoData)
                            dismiss()
                        }) {
                            Text("Opslaan")
                                .font(AppFonts.label(14))
                                .foregroundColor(AppColors.backgroundDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accentGold))
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Flow Layout (wrapping tag grid)

