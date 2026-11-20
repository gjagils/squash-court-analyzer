import SwiftUI
import SquashAnalyzerCore

/// What the setup step hands to a new coach or referee match
public struct MatchSetupChoice: Equatable {
    public let player1Name: String
    public let player2Name: String
    public let player1Id: String?
    public let player2Id: String?
    public let startingServer: Player
    /// Best of 1, 3 or 5 games (5 in a team match)
    public let bestOf: Int
    /// Games each player already won before the app was used ("Later instappen")
    public let player1GamesBefore: Int
    public let player2GamesBefore: Int
    /// Coaching focus of a picked player (empty otherwise)
    public let player1Focus: [String]
    public let player2Focus: [String]
    /// Teamwedstrijd as the kind of match: which team match, which partij and
    /// whether our player is Speler 1 (nil team match = an ordinary match)
    public let teamMatch: TeamMatch?
    public let teamSlot: Int
    public let teamOwnIsPlayer1: Bool
    /// "Oefenpartij": no badges, not in the profile (backlog C8, `PracticeMatches`)
    public var isPractice: Bool = false
    /// The question at the start ("welke partij tel je?") was answered with
    /// "Nee, gewone wedstrijd": the same question is not asked again after the match
    public var teamDeclined: Bool = false
    /// A partij of a team match from the programme, chosen in the question,
    /// with an account: the team match is shared with the team once the match
    /// has started (`TeamFinding.shareAtStart`)
    public var teamShareAtStart: Bool = false
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
    /// Teamwedstrijd as the kind of match
    let teamMatchStore: (any TeamMatchStore)?
    /// The finished matches, for the head-to-head at Kies speler ("3-1 tegen Bas"); nil shows none
    let historyStore: (any MatchHistoryStore)?
    @State private var history: [MatchHistorySummary] = []
    /// Scouting (3.2): the profile of a picked player, opened from below their name
    @State private var scouting: PlayerProfile? = nil
    @State private var teamCandidates: [TeamMatch] = []
    @State private var inTeam = false
    @State private var pickedTeam: UUID? = nil
    @State private var teamSlot = 1
    @State private var teamOwnIsPlayer1 = true
    /// The question before the setup, while a team match is going on for the
    /// team (Gerd-Jan, 21 November 2026): the team match it asks about
    @State private var question: TeamMatch? = nil
    /// Looking for a teammate's live team match (with an account), two seconds at most
    @State private var searching = false
    /// Answered, or the wait is over: nothing pops up over the setup any more
    @State private var questionClosed = false
    /// A partij was chosen in the question: the short setup
    @State private var fromQuestion = false
    /// "Nee, gewone wedstrijd"
    @State private var declined = false
    /// The team matches stored on this phone: one that is not among them comes
    /// from the programme (or a teammate) and is shared with the team at the start
    @State private var storedTeamIds: [UUID] = []
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
    /// Best of 1, 3 or 5; a partij of a team match is always best of 5
    @State private var bestOf = 5
    @State private var lateStart = false
    /// Oefenpartij (backlog C8); never for a partij of a team match
    @State private var practice = false
    /// "Meer opties": Best of and Later instappen, folded by default
    @State private var showMore = false
    /// The last format and kind chosen, so a weekly training needs no changes
    /// (Gerd-Jan, 31 October 2026); a team match is never remembered
    @AppStorage("setupLastBestOf") private var lastBestOf = 5
    @AppStorage("setupLastPractice") private var lastPractice = false
    @State private var gamesBefore1 = 0
    @State private var gamesBefore2 = 0

    public init(playerStore: any PlayerProfileStore, mode: MatchSetupMode, photoStore: (any PlayerPhotoStore)? = nil,
                filePicker: (any PlayerFilePicker)? = nil, initialPlayer1Name: String = "", initialPlayer2Name: String = "",
                teamMatchStore: (any TeamMatchStore)? = nil, historyStore: (any MatchHistoryStore)? = nil,
                onCancel: (() -> Void)? = nil,
                onStart: @escaping (MatchSetupChoice) -> Void) {
        self.teamMatchStore = teamMatchStore
        self.historyStore = historyStore
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

    /// The names the match is started with: "Speler 1"/"Speler 2" when left
    /// empty, never translated (Player.rawValue, docs/i18n.md)
    private var name1: String { resolvedName(player1Name, fallback: "Speler 1") }
    private var name2: String { resolvedName(player2Name, fallback: "Speler 2") }
    /// The same names as shown on this screen: the empty case in the app's language
    private var shownName1: String { resolvedName(player1Name, fallback: loc("Speler 1")) }
    private var shownName2: String { resolvedName(player2Name, fallback: loc("Speler 2")) }
    /// The format the match starts with: a team match (SBN) is always best of 5
    private var chosenBestOf: Int { inTeam && chosenTeam != nil ? 5 : bestOf }
    /// The most games a player can have won already with "Later instappen"
    private var maxGamesBefore: Int { MatchStand.gamesToWin(bestOf: chosenBestOf) - 1 }
    private var headStartIsValid: Bool { Match.isValidHeadStart(player1: gamesBefore1, player2: gamesBefore2, bestOf: chosenBestOf) }
    /// Games already played count also with "Later instappen" folded, as on iOS
    private var hasHeadStart: Bool { gamesBefore1 + gamesBefore2 > 0 }
    private var isCoach: Bool { mode == .coach }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                if searching {
                    ProgressView(loc("Teamwedstrijd zoeken…"))
                        .padding(.top, 60)
                } else if let asked = question {
                    teamQuestion(asked)
                } else {
                    teamSummary
                    playerRow(label: loc("Speler 1"), name: $player1Name, slot: 1, color: SharedColors.accent, focus: focus(player1Pick, currentName: player1Name))
                    playerRow(label: loc("Speler 2"), name: $player2Name, slot: 2, color: SharedColors.steelBlue, focus: focus(player2Pick, currentName: player2Name))

                    serverPicker
                    if fromQuestion && inTeam {
                        ownPlayerQuestion
                    } else {
                        kindPicker
                    }
                    moreOptions

                    ActionButton(isCoach ? loc("START WEDSTRIJD") : loc("START SCHEIDSRECHTER"), style: .filled,
                                 disabled: !headStartIsValid, action: start)
                }
            }
            .padding(24)
        }
        .task {
            restoreLastChoice()
            await reloadPlayers()
            if let teamMatchStore {
                // First what this phone knows (at once), then the choices behind Meer opties
                var ids: [UUID] = []
                for match in ((try? await teamMatchStore.loadAll()) ?? []) { ids.append(match.id) }
                storedTeamIds = ids
                let local = await TeamMatchSupport.startCandidate(store: teamMatchStore)
                if let local { question = local }
                teamCandidates = await TeamMatchSupport.candidates(store: teamMatchStore)
                await findTeammatesMatch(local: local, store: teamMatchStore)
            }
            if let historyStore { history = (try? await historyStore.loadHistory()) ?? [] }
        }
        .sheet(item: $scouting) { player in
            NavigationStack {
                if let historyStore {
                    SharedPlayerTrendView(playerId: player.id, playerName: player.name, photo: photos[player.id], historyStore: historyStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                CloseButton { scouting = nil }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: pickerIsPresented) {
            NavigationStack {
                List {
                    Button { editing = PlayerProfile() } label: {
                        HStack(spacing: 10) {
                            AppSymbol("plus", size: 16, color: SharedColors.accent)
                            Text("Nieuwe speler", bundle: textBundle).foregroundColor(SharedColors.accent)
                        }
                    }
                    ForEach(players) { player in
                        Button { choose(player) } label: {
                            HStack(spacing: 12) {
                                PlayerPhotoView(photo: photos[player.id], name: player.name, size: 36, color: SharedColors.textSecondary)
                                Text(player.name).foregroundColor(SharedColors.textPrimary)
                                Spacer()
                                if let record = headToHeadText(player) {
                                    Text(record)
                                        .font(SharedFonts.system(12, weight: .medium, design: .rounded))
                                        .foregroundColor(SharedColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .pageTitle(pickingSlot == 0 ? loc("Spelers") : loc("Kies speler"))
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
            Text(isCoach ? loc("Coach") : loc("Scheidsrechter"))
                .font(PageTitleStyle.font)
                .foregroundColor(SharedColors.textPrimary)
            HStack {
                Spacer()
                Button { pickingSlot = 0 } label: {
                    AppSymbol("person.2.circle", size: 22, color: SharedColors.accent)
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loc("Spelers beheren"))
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
                TextField(loc("Naam \(label.lowercased())"), text: name)
                    .accessibilityLabel(label)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(SharedColors.tint(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
                    .foregroundColor(SharedColors.textPrimary)
                Button(loc("Kies speler")) { pickingSlot = slot }
                    .foregroundColor(color)
            }
            // Scouting (3.2): the profile of the picked player before the match
            if historyStore != nil, let picked = slot == 1 ? player1Pick : player2Pick,
               pickedId(picked, currentName: name.wrappedValue) != nil {
                Button { scouting = picked } label: {
                    HStack(spacing: 6) {
                        AppSymbol("chart.bar.xaxis", size: 12, color: color)
                        Text("Profiel bekijken", bundle: textBundle)
                            .font(SharedFonts.system(12, weight: .semibold, design: .rounded))
                            .foregroundColor(color)
                    }
                }
                .buttonStyle(.plain)
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
            Text("Wie serveert eerst?", bundle: textBundle)
                .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 10) {
                serverButton(Player.player1, shownName1, SharedColors.accent)
                serverButton(Player.player2, shownName2, SharedColors.steelBlue)
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
        .accessibilityLabel(loc("\(name) serveert eerst"))
    }

    /// The kind of match in one row instead of separate switches (Gerd-Jan,
    /// 31 October 2026): Wedstrijd or Oefenpartij. A team match is no longer a
    /// kind here (21 November 2026): the question at the start asks about the
    /// one that is going on, and Meer opties links to another. A partij of a
    /// team match always counts, so Oefenpartij drops the link.
    private var kindPicker: some View {
        VStack(spacing: 10) {
            Text("Soort wedstrijd", bundle: textBundle)
                .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 10) {
                kindButton(loc("Wedstrijd"), selected: !practice) { practice = false }
                kindButton(loc("Oefenpartij"), selected: practice) { chooseKind(team: false, isPractice: true) }
            }
            if practice && !inTeam {
                Text("Telt niet mee voor badges en het spelersprofiel. Je vindt hem wel terug bij Afgeronde wedstrijden.", bundle: textBundle)
                    .font(SharedFonts.system(11))
                    .foregroundColor(SharedColors.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func kindButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SharedFonts.system(14, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? SharedColors.accent : SharedColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(SharedColors.accent.opacity(selected ? 0.15 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SharedColors.accent.opacity(selected ? 0.6 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func chooseKind(team: Bool, isPractice: Bool) {
        practice = isPractice
        turnTeamOn(team)
    }

    /// "Meer opties": Best of and Later instappen behind one line that says
    /// what is set ("Best of 3 · start bij game 2"), so the screen stays short
    private var moreOptions: some View {
        VStack(spacing: 16) {
            Button { showMore.toggle() } label: {
                HStack(spacing: 4) {
                    Text(moreSummary)
                        .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                        .foregroundColor(hasHeadStart ? SharedColors.accent : SharedColors.textSecondary)
                    AppSymbol(showMore ? "chevron.up" : "chevron.down", size: 12,
                              color: hasHeadStart ? SharedColors.accent : SharedColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            if showMore {
                bestOfPicker
                // Best of 1 has nothing to join later
                if maxGamesBefore > 0 {
                    lateStartSection
                }
                // A team match that is not the one going on (a catch-up match, one of next week)
                if !fromQuestion && !teamCandidates.isEmpty {
                    Button { toggleTeamLink() } label: {
                        Text(inTeam ? loc("Niet koppelen aan teamwedstrijd") : loc("Koppel aan teamwedstrijd"))
                            .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                            .foregroundColor(inTeam ? SharedColors.accent : SharedColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    teamSection
                }
            }
        }
    }

    private func toggleTeamLink() {
        if inTeam { turnTeamOn(false) } else { chooseKind(team: true, isPractice: false) }
    }

    /// Folded: "Meer opties · Best of 5", with a head start "… · start bij game 3"
    private var moreSummary: String {
        // Open, the choices show right below: the line only folds them again
        if showMore { return loc("Minder opties") }
        var parts: [String] = [loc("Meer opties")]
        if !(inTeam && chosenTeam != nil) { parts.append(loc("Best of \(chosenBestOf)")) }
        if inTeam && !fromQuestion && chosenTeam != nil { parts.append(loc("gekoppeld aan teamwedstrijd")) }
        if hasHeadStart && headStartIsValid { parts.append(loc("start bij game \(1 + gamesBefore1 + gamesBefore2)")) }
        return parts.joined(separator: " · ")
    }

    /// The format and kind of the last match started here (not for a match
    /// that comes from a team match, which is always best of 5 and counts)
    private func restoreLastChoice() {
        guard !prefilled else { return }
        if Match.bestOfOptions.contains(lastBestOf) { bestOf = lastBestOf }
        practice = lastPractice
    }

    /// "Best of 1 · 3 · 5": a training match is often shorter than best of 5
    /// (Gerd-Jan, 22 October 2026). Hidden for a partij of a team match (always 5).
    @ViewBuilder
    private var bestOfPicker: some View {
        if !(inTeam && chosenTeam != nil) {
            VStack(spacing: 10) {
                Text("Best of", bundle: textBundle)
                    .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textSecondary)
                HStack(spacing: 10) {
                    ForEach(Match.bestOfOptions, id: \.self) { option in
                        bestOfButton(option)
                    }
                }
            }
        }
    }

    private func bestOfButton(_ option: Int) -> some View {
        let selected = bestOf == option
        return Button { chooseBestOf(option) } label: {
            Text("\(option)")
                .font(SharedFonts.system(15, weight: .bold, design: .rounded))
                .foregroundColor(selected ? SharedColors.accent : SharedColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(SharedColors.accent.opacity(selected ? 0.15 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(SharedColors.accent.opacity(selected ? 0.6 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc("Best of \(option)"))
    }

    /// A shorter format cannot keep a head start it has no room for
    private func chooseBestOf(_ option: Int) {
        bestOf = option
        let limit = MatchStand.gamesToWin(bestOf: option) - 1
        gamesBefore1 = min(gamesBefore1, limit)
        gamesBefore2 = min(gamesBefore2, limit)
    }

    private var lateStartSection: some View {
        VStack(spacing: 12) {
            Button { lateStart.toggle() } label: {
                // Folded with games filled in, the line itself says where the match starts (as on iOS)
                HStack(spacing: 4) {
                    Text(hasHeadStart && headStartIsValid
                         ? loc("Start bij game \(1 + gamesBefore1 + gamesBefore2) · stand \(gamesBefore1) – \(gamesBefore2)")
                         : (lateStart ? loc("Later instappen") : loc("Later instappen?")))
                        .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                        .foregroundColor(hasHeadStart ? SharedColors.accent : SharedColors.textSecondary)
                    AppSymbol(lateStart ? "chevron.up" : "chevron.down", size: 12,
                              color: hasHeadStart ? SharedColors.accent : SharedColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            if lateStart {
                Text("GAMES GEWONNEN", bundle: textBundle)
                    .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(SharedColors.accent)
                gamesRow(shownName1, color: SharedColors.accent, value: gamesBefore1, onMinus: { gamesBefore1 = max(0, gamesBefore1 - 1) }, onPlus: { gamesBefore1 = min(maxGamesBefore, gamesBefore1 + 1) })
                gamesRow(shownName2, color: SharedColors.steelBlue, value: gamesBefore2, onMinus: { gamesBefore2 = max(0, gamesBefore2 - 1) }, onPlus: { gamesBefore2 = min(maxGamesBefore, gamesBefore2 + 1) })
                if !headStartIsValid {
                    Text("Met deze stand is de wedstrijd al beslist", bundle: textBundle)
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
                .accessibilityLabel(loc("Minder games voor \(name)"))
            Text("\(value)")
                .font(SharedFonts.system(18, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
                .frame(width: 28)
            Button(action: onPlus) { Text("+").font(SharedFonts.system(22, weight: .bold)).frame(width: 44, height: 36) }
                .buttonStyle(.plain)
                .foregroundColor(color)
                .accessibilityLabel(loc("Meer games voor \(name)"))
        }
        .padding(.horizontal, 12)
        .background(SharedColors.tint(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// The team match picked in the setup, when Teamwedstrijd is the kind
    private var chosenTeam: TeamMatch? {
        guard inTeam else { return nil }
        for candidate in teamCandidates where candidate.id == pickedTeam { return candidate }
        return teamCandidates.first
    }

    // MARK: The question at the start

    /// With an account: a teammate's live team match of today that this phone
    /// has not joined (`TeamFinding.matchDayCandidate`). With nothing to ask
    /// yet the setup waits two seconds at most; later it no longer interrupts
    /// (the question after the match is the safety net).
    private func findTeammatesMatch(local: TeamMatch?, store: any TeamMatchStore) async {
        if let local, local.isLive { return }
        guard Features.shared.playerAccount, PlayerAccount.shared.isSignedIn else { return }
        if local == nil {
            searching = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if searching {
                    searching = false
                    questionClosed = true
                }
            }
        }
        let found = await TeamFinding.matchDayCandidate(store: store)
        let waited = searching
        searching = false
        guard let found, found.isLive else { return }
        if questionClosed {
            // Answered with the same team match: the partij goes to the teammate's live page
            if fromQuestion && pickedTeam == found.id { keep(found) }
            return
        }
        if waited || question != nil { question = found }
    }

    /// `team` is the first of the team matches the setup can start for
    private func keep(_ team: TeamMatch) {
        var list: [TeamMatch] = [team]
        for candidate in teamCandidates where candidate.id != team.id { list.append(candidate) }
        teamCandidates = list
    }

    /// "Welke partij tel je?": one tap answers the question and picks the partij
    private func teamQuestion(_ team: TeamMatch) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                SectionHeader(loc("TEAMWEDSTRIJD"))
                Spacer()
                TeamShareBadge(isLive: team.isLive)
            }
            Text(team.title)
                .font(SharedFonts.system(20, weight: .semibold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tel je een partij van deze teamwedstrijd? Tik op de partij.", bundle: textBundle)
                .font(SharedFonts.system(14))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if team.isLive && !team.isLiveOwner {
                Text("Een teamgenoot houdt deze teamwedstrijd bij. De partij die je kiest komt op dezelfde pagina.", bundle: textBundle)
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.support)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                ForEach(team.partijen, id: \.slot) { partij in
                    Button { answer(team, slot: partij.slot) } label: {
                        HStack(spacing: 12) {
                            Text(partij.label)
                                .font(SharedFonts.system(12, weight: .bold, design: .rounded))
                                .foregroundColor(SharedColors.background)
                                .frame(width: 30, height: 30)
                                .background(partij.hasEntry ? SharedColors.textMuted : SharedColors.accent)
                                .clipShape(Circle())
                            Text(partijNames(partij, in: team))
                                .font(SharedFonts.system(14))
                                .foregroundColor(partij.hasEntry ? SharedColors.textMuted : SharedColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(partijState(partij))
                                .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                                .foregroundColor(SharedColors.textMuted)
                                .lineLimit(1)
                        }
                        .padding(12)
                        .background(SharedColors.tint(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(loc("Partij \(partij.label)"))
                }
            }
            ActionButton(loc("Nee, gewone wedstrijd"), color: SharedColors.textSecondary) { decline() }
                .padding(.top, 8)
        }
    }

    /// "Jan – Piet", or "nog leeg" while no name is filled in
    private func partijNames(_ partij: TeamPartij, in team: TeamMatch) -> String {
        if partij.ownPlayer.isEmpty && partij.opponentPlayer.isEmpty { return loc("nog leeg") }
        return "\(team.ownDisplayName(partij)) – \(team.opponentDisplayName(partij))"
    }

    /// The stand of a partij with games, "wordt geteld" for one a match was started for
    private func partijState(_ partij: TeamPartij) -> String {
        if partij.hasEntry { return partij.standText }
        if partij.trackingMatchId != nil { return loc("wordt geteld") }
        return ""
    }

    /// A partij was tapped: the team match and the partij are set, the names
    /// come from the partij (the home player as Speler 1, as SBN prints it)
    private func answer(_ team: TeamMatch, slot: Int) {
        question = nil
        questionClosed = true
        declined = false
        fromQuestion = true
        keep(team)
        inTeam = true
        practice = false
        pickedTeam = team.id
        teamSlot = slot
        let partij = team.partij(slot)
        let ownFirst = team.ownSide == TeamSide.home
        teamOwnIsPlayer1 = ownFirst
        if !partij.ownPlayer.isEmpty || !partij.opponentPlayer.isEmpty {
            player1Name = ownFirst ? partij.ownPlayer : partij.opponentPlayer
            player2Name = ownFirst ? partij.opponentPlayer : partij.ownPlayer
            player1Pick = nil
            player2Pick = nil
            pickPrefilledPlayers()
        }
    }

    /// "Nee, gewone wedstrijd": the ordinary setup, and no question after the match
    private func decline() {
        question = nil
        questionClosed = true
        declined = true
        fromQuestion = false
        inTeam = false
    }

    /// Which player is ours when the partij or "In mijn team" says so; nil has to be asked
    private var knownOwnIsPlayer1: Bool? {
        guard let team = chosenTeam else { return nil }
        var first = false
        var second = false
        if let pick = player1Pick, pickedId(pick, currentName: player1Name) != nil { first = TeamRoster.contains(pick.id, in: rosterRaw) }
        if let pick = player2Pick, pickedId(pick, currentName: player2Name) != nil { second = TeamRoster.contains(pick.id, in: rosterRaw) }
        return TeamMatchSupport.ownIsPlayer1(partij: team.partij(teamSlot), player1Name: player1Name, player2Name: player2Name,
                                             player1InTeam: first, player2InTeam: second)
    }

    /// The team match of the question is new on this phone and someone is
    /// signed in: starting shares it with the team. One that is stored here
    /// without sharing stays as its maker left it ("Deel met mijn team" off).
    private var sharesAtStart: Bool {
        guard fromQuestion, let team = chosenTeam, !team.isLive, team.fixtureId != nil else { return false }
        if storedTeamIds.contains(team.id) { return false }
        return Features.shared.playerAccount && PlayerAccount.shared.isSignedIn
    }

    /// After the question: the team match and the partij in one block, with "Wijzig" back to the question
    @ViewBuilder
    private var teamSummary: some View {
        if fromQuestion && inTeam, let team = chosenTeam {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("TEAMWEDSTRIJD", bundle: textBundle)
                        .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(SharedColors.textMuted)
                    Spacer()
                    TeamShareBadge(isLive: team.isLive)
                }
                Text(team.title)
                    .font(SharedFonts.system(15, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(loc("Partij \(team.partij(teamSlot).label) · best of 5"))
                        .font(SharedFonts.system(13))
                        .foregroundColor(SharedColors.textSecondary)
                    Spacer()
                    Button(loc("Wijzig")) { question = team }
                        .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                        .foregroundColor(SharedColors.accent)
                        .buttonStyle(.plain)
                }
                if sharesAtStart {
                    Text("Bij de start delen we deze teamwedstrijd met je team: teamgenoten zetten hun partij erbij. Alleen teamnamen, voornamen en de stand gaan naar de server.", bundle: textBundle)
                        .font(SharedFonts.system(11))
                        .foregroundColor(SharedColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.tint(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// "Wie is onze speler?", only when the partij and "In mijn team" do not say it
    @ViewBuilder
    private var ownPlayerQuestion: some View {
        if knownOwnIsPlayer1 == nil {
            VStack(spacing: 10) {
                Text("Wie is onze speler?", bundle: textBundle)
                    .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textSecondary)
                HStack(spacing: 8) {
                    ownChoice(shownName1, isPlayer1: true, color: SharedColors.accent)
                    ownChoice(shownName2, isPlayer1: false, color: SharedColors.steelBlue)
                }
            }
        }
    }

    /// Linked from Meer opties: pick the team match, the partij and which player is ours
    @ViewBuilder
    private var teamSection: some View {
        if inTeam, let team = chosenTeam {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
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
                                .background(candidate.id == team.id ? SharedColors.accent.opacity(0.12) : SharedColors.tint(0.04))
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
                    Text("PARTIJ", bundle: textBundle)
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
                                    .background(teamSlot == slot ? SharedColors.accent : SharedColors.tint(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("WIE IS ONZE SPELER?", bundle: textBundle)
                        .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(SharedColors.textMuted)
                    HStack(spacing: 8) {
                        ownChoice(shownName1, isPlayer1: true, color: SharedColors.accent)
                        ownChoice(shownName2, isPlayer1: false, color: SharedColors.steelBlue)
                    }
                    Text("Het resultaat komt na afloop vanzelf in de partij en, als de teamwedstrijd live is, gaat de stand mee naar de teampagina.", bundle: textBundle)
                        .font(SharedFonts.system(11))
                        .foregroundColor(SharedColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(SharedColors.tint(0.04))
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
        var choice = MatchSetupChoice(
            player1Name: name1, player2Name: name2,
            player1Id: pickedId(player1Pick, currentName: player1Name), player2Id: pickedId(player2Pick, currentName: player2Name),
            startingServer: server, bestOf: chosenBestOf,
            player1GamesBefore: late ? gamesBefore1 : 0, player2GamesBefore: late ? gamesBefore2 : 0,
            player1Focus: focus(player1Pick, currentName: player1Name), player2Focus: focus(player2Pick, currentName: player2Name),
            teamMatch: team, teamSlot: teamSlot,
            teamOwnIsPlayer1: fromQuestion ? (knownOwnIsPlayer1 ?? teamOwnIsPlayer1) : teamOwnIsPlayer1
        )
        choice.isPractice = practice && team == nil && !prefilled
        choice.teamDeclined = declined && team == nil
        choice.teamShareAtStart = sharesAtStart
        if team == nil && !prefilled {
            lastBestOf = bestOf
            lastPractice = practice
        }
        onStart(choice)
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

    /// "3-1 tegen Bas": this player against the one in the other slot, when they played before
    private func headToHeadText(_ player: PlayerProfile) -> String? {
        guard pickingSlot == 1 || pickingSlot == 2 else { return nil }
        let other = (pickingSlot == 1 ? player2Name : player1Name).trimmingCharacters(in: .whitespaces)
        let record = HeadToHead.record(of: player.name, against: other, in: history)
        return record.played > 0 ? record.text(against: other) : nil
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

