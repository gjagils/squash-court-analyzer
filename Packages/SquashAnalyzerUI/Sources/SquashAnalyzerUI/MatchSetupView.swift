import SwiftUI
import SquashAnalyzerCore

/// What the setup step hands to a new coach or referee match
public struct MatchSetupChoice: Equatable {
    public let player1Name: String
    public let player2Name: String
    public let player1Id: String?
    public let player2Id: String?
    public let startingServer: Player
    /// Games each player already won before the app was used ("Later instappen")
    public let player1GamesBefore: Int
    public let player2GamesBefore: Int
    /// Coaching focus of a picked player (empty otherwise)
    public let player1Focus: [String]
    public let player2Focus: [String]
}

/// Which match the setup screen starts
public enum MatchSetupMode {
    case coach, referee
}

/// The step before a new coach/referee match, like iOS' MatchStartView: two
/// names (each optionally picked from the player list, with that player's
/// focus shown), who serves first, and "Later instappen" with the games
/// already played. Picking a player and then editing the name away drops the
/// id again, same rule as iOS' `PickedPlayer`.
public struct MatchSetupView: View {
    let playerStore: any PlayerProfileStore
    let mode: MatchSetupMode
    /// Photos in the player list and the editor; nil shows initials
    let photoStore: (any PlayerPhotoStore)?
    let filePicker: (any PlayerFilePicker)?
    @State private var photos: [String: Data] = [:]
    /// A player being added or edited from the list (as iOS' player management)
    @State private var editing: PlayerProfile? = nil
    let onCancel: (() -> Void)?
    let onStart: (MatchSetupChoice) -> Void

    @State private var players: [PlayerProfile] = []
    @State private var player1Name = ""
    @State private var player2Name = ""
    @State private var player1Pick: PlayerProfile? = nil
    @State private var player2Pick: PlayerProfile? = nil
    @State private var pickingSlot: Int? = nil
    @State private var server = Player.player1
    @State private var lateStart = false
    @State private var gamesBefore1 = 0
    @State private var gamesBefore2 = 0

    public init(playerStore: any PlayerProfileStore, mode: MatchSetupMode, photoStore: (any PlayerPhotoStore)? = nil,
                filePicker: (any PlayerFilePicker)? = nil, onCancel: (() -> Void)? = nil,
                onStart: @escaping (MatchSetupChoice) -> Void) {
        self.playerStore = playerStore
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.mode = mode
        self.onCancel = onCancel
        self.onStart = onStart
    }

    private var name1: String { resolvedName(player1Name, fallback: "Speler 1") }
    private var name2: String { resolvedName(player2Name, fallback: "Speler 2") }
    private var headStartIsValid: Bool { Match.isValidHeadStart(player1: gamesBefore1, player2: gamesBefore2) }
    /// Games already played count also with "Later instappen" folded, as on iOS
    private var hasHeadStart: Bool { gamesBefore1 + gamesBefore2 > 0 }
    private var isCoach: Bool { mode == .coach }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                playerRow(label: "Speler 1", name: $player1Name, slot: 1, color: SharedColors.accent, focus: focus(player1Pick, currentName: player1Name))
                playerRow(label: "Speler 2", name: $player2Name, slot: 2, color: SharedColors.steelBlue, focus: focus(player2Pick, currentName: player2Name))

                serverPicker
                lateStartSection

                ActionButton(isCoach ? "START WEDSTRIJD" : "START SCHEIDSRECHTER", style: .filled,
                             disabled: !headStartIsValid, action: start)
            }
            .padding(24)
        }
        .task { await reloadPlayers() }
        .sheet(isPresented: pickerIsPresented) {
            NavigationStack {
                List {
                    Button { editing = PlayerProfile() } label: {
                        HStack(spacing: 10) {
                            AppSymbol("plus", size: 16, color: SharedColors.gold)
                            Text("Nieuwe speler").foregroundColor(SharedColors.gold)
                        }
                    }
                    ForEach(players) { player in
                        Button { choose(player) } label: {
                            HStack(spacing: 12) {
                                PlayerPhotoView(photo: photos[player.id], name: player.name, size: 36, color: SharedColors.gold)
                                Text(player.name).foregroundColor(SharedColors.textPrimary)
                                Spacer()
                            }
                        }
                    }
                }
                .pageTitle(pickingSlot == 0 ? "Spelers" : "Kies speler")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Sluiten") { pickingSlot = nil }
                    }
                }
                .sheet(item: $editing) { player in
                    PlayerProfileEditor(player: player, store: playerStore, photo: photos[player.id], photoStore: photoStore,
                                        filePicker: filePicker) { await reloadPlayers() }
                }
            }
        }
    }

    /// "‹ Home", the mode in capitals, as on iOS
    private var header: some View {
        ZStack {
            Text(isCoach ? "Coach" : "Scheidsrechter")
                .font(PageTitleStyle.font)
                .foregroundColor(SharedColors.textPrimary)
            HStack {
                Spacer()
                Button { pickingSlot = 0 } label: {
                    AppSymbol("person.2.circle", size: 22, color: SharedColors.gold)
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Spelers beheren")
            }
            if let onCancel {
                HStack {
                    Button(action: onCancel) {
                        HStack(spacing: 4) {
                            AppSymbol("chevron.left", size: 14, color: SharedColors.textSecondary)
                            Text("Home")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
        .padding(.top, 8)
    }

    private func playerRow(label: String, name: Binding<String>, slot: Int, color: Color, focus: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundColor(color)
            HStack(spacing: 8) {
                TextField("Naam \(label.lowercased())", text: name)
                    .accessibilityLabel(label)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
                    .foregroundColor(SharedColors.textPrimary)
                Button("Kies speler") { pickingSlot = slot }
                    .foregroundColor(color)
            }
            // Coaching focus only matters when coaching, as on iOS
            if isCoach && !focus.isEmpty {
                HStack(spacing: 6) {
                    ForEach(focus, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var serverPicker: some View {
        VStack(spacing: 10) {
            Text("Wie serveert eerst?")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 10) {
                serverButton(Player.player1, name1, SharedColors.accent)
                serverButton(Player.player2, name2, SharedColors.steelBlue)
            }
        }
    }

    private func serverButton(_ player: Player, _ name: String, _ color: Color) -> some View {
        let selected = server == player
        return Button { server = player } label: {
            HStack(spacing: 8) {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().fill(selected ? color : Color.clear).frame(width: 10, height: 10))
                Text(name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(selected ? color : SharedColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(selected ? 0.15 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(selected ? 0.6 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) serveert eerst")
    }

    private var lateStartSection: some View {
        VStack(spacing: 12) {
            Button { lateStart.toggle() } label: {
                // Folded with games filled in, the line itself says where the match starts (as on iOS)
                HStack(spacing: 4) {
                    Text(hasHeadStart && headStartIsValid
                         ? "Start bij game \(1 + gamesBefore1 + gamesBefore2) · stand \(gamesBefore1) – \(gamesBefore2)"
                         : (lateStart ? "Later instappen" : "Later instappen?"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(hasHeadStart ? SharedColors.gold : SharedColors.textSecondary)
                    AppSymbol(lateStart ? "chevron.up" : "chevron.down", size: 12,
                              color: hasHeadStart ? SharedColors.gold : SharedColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            if lateStart {
                Text("GAMES GEWONNEN")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(SharedColors.gold)
                gamesRow(name1, color: SharedColors.accent, value: gamesBefore1, onMinus: { gamesBefore1 = max(0, gamesBefore1 - 1) }, onPlus: { gamesBefore1 = min(2, gamesBefore1 + 1) })
                gamesRow(name2, color: SharedColors.steelBlue, value: gamesBefore2, onMinus: { gamesBefore2 = max(0, gamesBefore2 - 1) }, onPlus: { gamesBefore2 = min(2, gamesBefore2 + 1) })
                if !headStartIsValid {
                    Text("Met deze stand is de wedstrijd al beslist")
                        .font(.system(size: 12))
                        .foregroundColor(SharedColors.textSecondary)
                }
            }
        }
    }

    private func gamesRow(_ name: String, color: Color, value: Int, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack {
            Text(name)
                .foregroundColor(color)
                .lineLimit(1)
            Spacer()
            Button(action: onMinus) { Text("−").font(.system(size: 22, weight: .bold)).frame(width: 44, height: 36) }
                .buttonStyle(.plain)
                .foregroundColor(color)
                .accessibilityLabel("Minder games voor \(name)")
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
                .frame(width: 28)
            Button(action: onPlus) { Text("+").font(.system(size: 22, weight: .bold)).frame(width: 44, height: 36) }
                .buttonStyle(.plain)
                .foregroundColor(color)
                .accessibilityLabel("Meer games voor \(name)")
        }
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func start() {
        let late = headStartIsValid
        onStart(MatchSetupChoice(
            player1Name: name1, player2Name: name2,
            player1Id: pickedId(player1Pick, currentName: player1Name), player2Id: pickedId(player2Pick, currentName: player2Name),
            startingServer: server,
            player1GamesBefore: late ? gamesBefore1 : 0, player2GamesBefore: late ? gamesBefore2 : 0,
            player1Focus: focus(player1Pick, currentName: player1Name), player2Focus: focus(player2Pick, currentName: player2Name)
        ))
    }

    private func reloadPlayers() async {
        players = (try? await playerStore.loadPlayers()) ?? []
        if let photoStore { photos = (try? await photoStore.photos()) ?? [:] }
    }

    /// From "Kies speler" the tapped player goes into the slot; from the players
    /// button in the header (slot 0) it opens the player to edit
    private func choose(_ player: PlayerProfile) {
        if pickingSlot == 0 { editing = player } else { pick(player) }
    }

    private var pickerIsPresented: Binding<Bool> {
        Binding(get: { pickingSlot != nil }, set: { if !$0 { pickingSlot = nil } })
    }

    private func pick(_ player: PlayerProfile) {
        if pickingSlot == 1 { player1Pick = player; player1Name = player.name }
        else if pickingSlot == 2 { player2Pick = player; player2Name = player.name }
        pickingSlot = nil
    }

    private func resolvedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// Only counts while the current text still matches the picked name.
    private func pickedId(_ pick: PlayerProfile?, currentName: String) -> String? {
        guard let pick, pick.name.trimmingCharacters(in: .whitespaces) == currentName.trimmingCharacters(in: .whitespaces) else { return nil }
        return pick.id
    }

    private func focus(_ pick: PlayerProfile?, currentName: String) -> [String] {
        guard let pick, pickedId(pick, currentName: currentName) != nil else { return [] }
        return pick.coachingFocusAreas
    }
}

