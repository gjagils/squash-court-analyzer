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
    /// "Onderdeel van een teamwedstrijd": which team match, which partij and
    /// whether our player is Speler 1 (nil team match = an ordinary match)
    public let teamMatch: TeamMatch?
    public let teamSlot: Int
    public let teamOwnIsPlayer1: Bool
}

public extension MatchSetupChoice {
    /// Where the finished match goes, when it belongs to a team match. A name
    /// left empty is the default ("Squash Delft 8 E1") instead of "Speler 1".
    var teamTarget: TeamTarget? {
        guard let teamMatch else { return nil }
        let own = teamOwnIsPlayer1 ? player1Name : player2Name
        let opponent = teamOwnIsPlayer1 ? player2Name : player1Name
        let ownPlaceholder = own == "Speler 1" || own == "Speler 2"
        let opponentPlaceholder = opponent == "Speler 1" || opponent == "Speler 2"
        return TeamTarget.make(team: teamMatch, slot: teamSlot, ownIsPlayer1: teamOwnIsPlayer1,
                               ownName: ownPlaceholder ? nil : own, opponentName: opponentPlaceholder ? nil : opponent)
    }
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
    /// Competitie: when given and there is a team match to play for, the setup offers
    /// "Onderdeel van een teamwedstrijd"
    let teamMatchStore: (any TeamMatchStore)?
    @State private var teamCandidates: [TeamMatch] = []
    @State private var inTeam = false
    @State private var pickedTeam: UUID? = nil
    @State private var teamSlot = 1
    @State private var teamOwnIsPlayer1 = true
    @AppStorage(TeamRoster.storageKey) private var rosterRaw = ""

    @State private var players: [PlayerProfile] = []
    @State private var player1Name: String
    @State private var player2Name: String
    /// Names to start with (a match for a partij of a team match); a player of
    /// the list with exactly that name is picked, so badges and focus work
    private let prefilled: Bool
    @State private var player1Pick: PlayerProfile? = nil
    @State private var player2Pick: PlayerProfile? = nil
    @State private var pickingSlot: Int? = nil
    @State private var server = Player.player1
    @State private var lateStart = false
    @State private var gamesBefore1 = 0
    @State private var gamesBefore2 = 0

    public init(playerStore: any PlayerProfileStore, mode: MatchSetupMode, photoStore: (any PlayerPhotoStore)? = nil,
                filePicker: (any PlayerFilePicker)? = nil, initialPlayer1Name: String = "", initialPlayer2Name: String = "",
                teamMatchStore: (any TeamMatchStore)? = nil,
                onCancel: (() -> Void)? = nil,
                onStart: @escaping (MatchSetupChoice) -> Void) {
        self.teamMatchStore = teamMatchStore
        _player1Name = State(initialValue: initialPlayer1Name)
        _player2Name = State(initialValue: initialPlayer2Name)
        self.prefilled = !initialPlayer1Name.isEmpty || !initialPlayer2Name.isEmpty
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
                teamSection
                lateStartSection

                ActionButton(isCoach ? "START WEDSTRIJD" : "START SCHEIDSRECHTER", style: .filled,
                             disabled: !headStartIsValid, action: start)
            }
            .padding(24)
        }
        .task {
            await reloadPlayers()
            if let teamMatchStore { teamCandidates = await TeamMatchSupport.candidates(store: teamMatchStore) }
        }
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
                        CloseButton { pickingSlot = nil }
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
                                .font(SharedFonts.system(14, weight: .medium, design: .rounded))
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
                .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
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
                        TagChip(tag, color: color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var serverPicker: some View {
        VStack(spacing: 10) {
            Text("Wie serveert eerst?")
                .font(SharedFonts.system(14, weight: .medium, design: .rounded))
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
                    .font(SharedFonts.system(14, weight: .semibold, design: .rounded))
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
                        .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                        .foregroundColor(hasHeadStart ? SharedColors.gold : SharedColors.textSecondary)
                    AppSymbol(lateStart ? "chevron.up" : "chevron.down", size: 12,
                              color: hasHeadStart ? SharedColors.gold : SharedColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            if lateStart {
                Text("GAMES GEWONNEN")
                    .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(SharedColors.gold)
                gamesRow(name1, color: SharedColors.accent, value: gamesBefore1, onMinus: { gamesBefore1 = max(0, gamesBefore1 - 1) }, onPlus: { gamesBefore1 = min(2, gamesBefore1 + 1) })
                gamesRow(name2, color: SharedColors.steelBlue, value: gamesBefore2, onMinus: { gamesBefore2 = max(0, gamesBefore2 - 1) }, onPlus: { gamesBefore2 = min(2, gamesBefore2 + 1) })
                if !headStartIsValid {
                    Text("Met deze stand is de wedstrijd al beslist")
                        .font(SharedFonts.system(12))
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
            Button(action: onMinus) { Text("−").font(SharedFonts.system(22, weight: .bold)).frame(width: 44, height: 36) }
                .buttonStyle(.plain)
                .foregroundColor(color)
                .accessibilityLabel("Minder games voor \(name)")
            Text("\(value)")
                .font(SharedFonts.system(18, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
                .frame(width: 28)
            Button(action: onPlus) { Text("+").font(SharedFonts.system(22, weight: .bold)).frame(width: 44, height: 36) }
                .buttonStyle(.plain)
                .foregroundColor(color)
                .accessibilityLabel("Meer games voor \(name)")
        }
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// The team match picked in the setup, when "Onderdeel van een teamwedstrijd" is on
    private var chosenTeam: TeamMatch? {
        guard inTeam else { return nil }
        for candidate in teamCandidates where candidate.id == pickedTeam { return candidate }
        return teamCandidates.first
    }

    /// "Onderdeel van een teamwedstrijd": pick the team match, the partij and which player is ours
    @ViewBuilder
    private var teamSection: some View {
        if !teamCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(get: { inTeam }, set: { turnTeamOn($0) })) {
                    Text("Onderdeel van een teamwedstrijd")
                        .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                }
                .tint(SharedColors.accent)
                if inTeam, let team = chosenTeam {
                    if teamCandidates.count > 1 {
                        ForEach(teamCandidates) { candidate in
                            Button { pickedTeam = candidate.id; teamSlot = freeSlot(candidate) } label: {
                                HStack(spacing: 8) {
                                    Text("\(TeamMatchReport.dayText(candidate.date)) · \(candidate.title)")
                                        .font(SharedFonts.system(12))
                                        .foregroundColor(candidate.id == team.id ? SharedColors.accent : SharedColors.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    TeamShareBadge(isLive: candidate.isLive)
                                }
                                .padding(10)
                                .background(candidate.id == team.id ? SharedColors.accent.opacity(0.12) : Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("\(TeamMatchReport.dayText(team.date)) · \(team.title)")
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.textSecondary)
                            Spacer()
                            TeamShareBadge(isLive: team.isLive)
                        }
                    }
                    Text("PARTIJ")
                        .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(SharedColors.textMuted)
                    HStack(spacing: 8) {
                        ForEach(1..<5, id: \.self) { slot in
                            Button { teamSlot = slot } label: {
                                Text("E\(slot)")
                                    .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                                    .foregroundColor(teamSlot == slot ? SharedColors.background : (team.partij(slot).hasEntry ? SharedColors.textMuted : SharedColors.accent))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(teamSlot == slot ? SharedColors.accent : Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("WIE IS ONZE SPELER?")
                        .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(SharedColors.textMuted)
                    HStack(spacing: 8) {
                        ownChoice(name1, isPlayer1: true, color: SharedColors.accent)
                        ownChoice(name2, isPlayer1: false, color: SharedColors.steelBlue)
                    }
                    Text("Het resultaat komt na afloop vanzelf in de partij en, als de teamwedstrijd live is, gaat de stand mee naar de teampagina.")
                        .font(SharedFonts.system(11))
                        .foregroundColor(SharedColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func ownChoice(_ name: String, isPlayer1: Bool, color: Color) -> some View {
        let selected = teamOwnIsPlayer1 == isPlayer1
        return Button { teamOwnIsPlayer1 = isPlayer1 } label: {
            Text(name)
                .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? SharedColors.background : color)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? color : color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// The first partij without games (E1 when all are filled)
    private func freeSlot(_ team: TeamMatch) -> Int {
        for slot in 1..<5 where !team.partij(slot).hasEntry { return slot }
        return 1
    }

    /// Turning it on picks the nearest team match and a free partij; our player is the one in "In mijn team"
    private func turnTeamOn(_ on: Bool) {
        inTeam = on
        guard on, let first = teamCandidates.first else { return }
        let team = chosenTeam ?? first
        pickedTeam = team.id
        teamSlot = freeSlot(team)
        var ours1 = false
        var ours2 = false
        if let pick = player1Pick { ours1 = TeamRoster.contains(pick.id, in: rosterRaw) }
        if let pick = player2Pick { ours2 = TeamRoster.contains(pick.id, in: rosterRaw) }
        teamOwnIsPlayer1 = !(ours2 && !ours1)
    }

    private func start() {
        let late = headStartIsValid
        let team = chosenTeam
        onStart(MatchSetupChoice(
            player1Name: name1, player2Name: name2,
            player1Id: pickedId(player1Pick, currentName: player1Name), player2Id: pickedId(player2Pick, currentName: player2Name),
            startingServer: server,
            player1GamesBefore: late ? gamesBefore1 : 0, player2GamesBefore: late ? gamesBefore2 : 0,
            player1Focus: focus(player1Pick, currentName: player1Name), player2Focus: focus(player2Pick, currentName: player2Name),
            teamMatch: team, teamSlot: teamSlot, teamOwnIsPlayer1: teamOwnIsPlayer1
        ))
    }

    private func reloadPlayers() async {
        players = (try? await playerStore.loadPlayers()) ?? []
        if let photoStore { photos = (try? await photoStore.photos()) ?? [:] }
        if prefilled { pickPrefilledPlayers() }
    }

    /// A prefilled name that is a player of the list is picked, once
    private func pickPrefilledPlayers() {
        if player1Pick == nil, let found = player(named: player1Name) {
            player1Pick = found
            player1Name = found.name
        }
        if player2Pick == nil, let found = player(named: player2Name) {
            player2Pick = found
            player2Name = found.name
        }
    }

    private func player(named name: String) -> PlayerProfile? {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        if wanted.isEmpty { return nil }
        for candidate in players where candidate.name.trimmingCharacters(in: .whitespaces).lowercased() == wanted { return candidate }
        return nil
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

