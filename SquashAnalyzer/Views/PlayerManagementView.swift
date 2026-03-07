import SwiftUI
import SwiftData

/// View for managing saved player profiles
struct PlayerManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedPlayer.name) private var players: [SavedPlayer]

    /// When set, the view acts as a picker and calls this on selection
    var onSelectPlayer: ((SavedPlayer) -> Void)? = nil

    @State private var showingAddPlayer = false
    @State private var playerToEdit: SavedPlayer? = nil

    var isPickerMode: Bool { onSelectPlayer != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        if isPickerMode {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark")
                                    Text("Annuleren")
                                }
                                .font(AppFonts.body(14))
                                .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        Text(isPickerMode ? "KIES SPELER" : "SPELERS")
                            .font(AppFonts.title(18))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(3)

                        Spacer()

                        Button(action: { showingAddPlayer = true }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.accentGold)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                    if players.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.textMuted)
                            Text("Nog geen spelers opgeslagen")
                                .font(AppFonts.body(16))
                                .foregroundColor(AppColors.textSecondary)
                            Text("Tik op + om een speler toe te voegen")
                                .font(AppFonts.caption(13))
                                .foregroundColor(AppColors.textMuted)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(players) { player in
                                    PlayerRowView(
                                        player: player,
                                        isPickerMode: isPickerMode,
                                        onSelect: {
                                            onSelectPlayer?(player)
                                            dismiss()
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
                PlayerEditSheet(player: nil) { name, focus, notes in
                    let newPlayer = SavedPlayer(name: name, coachingFocusAreas: focus, coachingNotes: notes)
                    modelContext.insert(newPlayer)
                    try? modelContext.save()
                }
            }
            .navigationDestination(item: $playerToEdit) { player in
                PlayerEditSheet(player: player) { name, focus, notes in
                    player.name = name
                    player.coachingFocusAreas = focus
                    player.coachingNotes = notes
                    try? modelContext.save()
                }
            }
        }
    }
}

// MARK: - Player Row

struct PlayerRowView: View {
    let player: SavedPlayer
    let isPickerMode: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Avatar circle
            Circle()
                .fill(AppColors.accentGold.opacity(0.2))
                .frame(width: 42, height: 42)
                .overlay(
                    Text(String(player.name.prefix(1)).uppercased())
                        .font(AppFonts.title(18))
                        .foregroundColor(AppColors.accentGold)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(AppFonts.label(15))
                    .foregroundColor(AppColors.textPrimary)

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
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.accentGold)
                }
            } else {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                }
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Verwijderen", systemImage: "trash")
            }
            if !isPickerMode {
                Button(action: onEdit) {
                    Label("Bewerken", systemImage: "pencil")
                }
                .tint(AppColors.accentGold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isPickerMode { onSelect() }
        }
    }
}

// MARK: - Player Edit Sheet

struct PlayerEditSheet: View {
    let player: SavedPlayer?
    let onSave: (String, [String], String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedFocusAreas: Set<String>
    @State private var notes: String

    init(player: SavedPlayer?, onSave: @escaping (String, [String], String) -> Void) {
        self.player = player
        self.onSave = onSave
        _name = State(initialValue: player?.name ?? "")
        _selectedFocusAreas = State(initialValue: Set(player?.coachingFocusAreas ?? []))
        _notes = State(initialValue: player?.coachingNotes ?? "")
    }

    private let allTags = CoachingFocusTag.allCases.map { $0.rawValue }

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

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAAM")
                            .font(AppFonts.caption(11))
                            .foregroundColor(AppColors.accentGold)
                            .tracking(1)

                        TextField("Naam speler", text: $name)
                            .font(AppFonts.body(16))
                            .foregroundColor(AppColors.textPrimary)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.accentGold.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.horizontal, 24)

                    // Focus tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COACHING FOCUS")
                            .font(AppFonts.caption(11))
                            .foregroundColor(AppColors.accentGold)
                            .tracking(1)

                        FlowLayout(spacing: 8) {
                            ForEach(allTags, id: \.self) { tag in
                                let isSelected = selectedFocusAreas.contains(tag)
                                Button(action: {
                                    if isSelected {
                                        selectedFocusAreas.remove(tag)
                                    } else {
                                        selectedFocusAreas.insert(tag)
                                    }
                                }) {
                                    Text(tag)
                                        .font(AppFonts.caption(12))
                                        .foregroundColor(isSelected ? AppColors.backgroundDark : AppColors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? AppColors.accentGold : Color.white.opacity(0.08))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? AppColors.accentGold : Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Notes field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTITIES")
                            .font(AppFonts.caption(11))
                            .foregroundColor(AppColors.accentGold)
                            .tracking(1)

                        TextField("Extra coaching aandachtspunten...", text: $notes, axis: .vertical)
                            .font(AppFonts.body(14))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(3...6)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
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
                            onSave(name.trimmingCharacters(in: .whitespaces), Array(selectedFocusAreas), notes)
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height = y + rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
