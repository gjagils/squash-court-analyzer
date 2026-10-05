import SwiftUI
import SquashAnalyzerCore

// MARK: - Competitie: teamwedstrijden (SBN, vier partijen E1–E4)
//
// Shared by iOS and Android. The list opens one team match; a team match
// has four partijen that are filled in by hand (game scores) or linked to a
// coach or referee match tracked on this phone. The stand, the winner and
// the competition points come from Core (`TeamMatch`), the message from
// `TeamMatchReport`.

public enum TeamMatchSupport {
    /// Mijn team as last fetched (Instellingen holds the link), for the
    /// fixtures and the roster; nil without a link
    public static func cachedTeam() -> LeagueTeamSnapshot? {
        let saved = UserDefaults.standard.string(forKey: LeagueTeamStorage.linkKey) ?? ""
        guard !saved.isEmpty, let link = try? LeagueTeamLink(saved) else { return nil }
        return LeagueTeamStorage.cachedSnapshot(for: link)
    }
}

/// Afgeronde en lopende teamwedstrijden, nieuwste eerst
public struct SharedTeamMatchesView: View {
    private let store: any TeamMatchStore
    private let historyStore: any MatchHistoryStore
    /// Mijn team, when a link is saved: its matches and players
    private let team: LeagueTeamSnapshot?
    private let shareText: ((String) -> Void)?

    @State private var matches: [TeamMatch] = []
    @State private var isLoading = true
    @State private var creating = false
    @State private var opened: TeamMatch? = nil
    @State private var message: String? = nil

    public init(store: any TeamMatchStore, historyStore: any MatchHistoryStore,
                team: LeagueTeamSnapshot? = nil, shareText: ((String) -> Void)? = nil) {
        self.store = store
        self.historyStore = historyStore
        self.team = team
        self.shareText = shareText
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Een teamwedstrijd van de SBN-competitie: vier partijen (E1–E4). Koppel de wedstrijden die je bijhield of vul de game-standen in; de app telt de games, de bonuspunten en de winnaar.")
                        .font(.system(size: 13))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ActionButton("Nieuwe teamwedstrijd", style: .filled) { creating = true }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if matches.isEmpty {
                        Text("Nog geen teamwedstrijden.")
                            .font(.system(size: 14))
                            .foregroundColor(SharedColors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else {
                        ForEach(matches) { match in
                            TeamMatchCard(match: match) { opened = match }
                        }
                    }
                    if let message {
                        Text(message).font(.system(size: 12)).foregroundColor(SharedColors.error)
                    }
                }
                .padding(24)
            }
        }
        .pageTitle("Competitie")
        .task { await load() }
        .sheet(isPresented: $creating) {
            NewTeamMatchSheet(team: team, existing: matches) { match in
                creating = false
                Task { await save(match, thenOpen: true) }
            } onCancel: { creating = false }
        }
        .navigationDestination(isPresented: Binding(get: { opened != nil }, set: { if !$0 { opened = nil } })) {
            if let opened {
                SharedTeamMatchView(match: opened, store: store, historyStore: historyStore, team: team, shareText: shareText) { _ in
                    Task { await load() }
                }
            }
        }
    }

    private func load() async {
        do {
            matches = try await store.loadAll()
            message = nil
        } catch {
            message = "De teamwedstrijden konden niet worden geladen."
        }
        isLoading = false
    }

    private func save(_ match: TeamMatch, thenOpen: Bool) async {
        do {
            try await store.save(match)
            await load()
            if thenOpen { opened = match }
        } catch {
            message = "Opslaan is niet gelukt."
        }
    }
}

/// One team match in the list
struct TeamMatchCard: View {
    let match: TeamMatch
    let onTap: () -> Void

    var body: some View {
        let score = match.score
        return Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(TeamMatchReport.dayText(match.date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textSecondary)
                    Spacer()
                    if score.isComplete, let winner = match.winnerName {
                        HStack(spacing: 4) {
                            AppSymbol("crown.fill", size: 10, color: SharedColors.gold)
                            Text(winner)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.gold)
                                .lineLimit(1)
                        }
                    } else {
                        Text(score.partijenPlayed == 0 ? "NOG NIET BEGONNEN" : "BEZIG")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(SharedColors.textMuted)
                    }
                }
                HStack(alignment: .center, spacing: 12) {
                    teamSide(match.home, own: match.ownSide == TeamSide.home)
                    Text(match.gamesText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                        .lineLimit(1)
                    teamSide(match.away, own: match.ownSide == TeamSide.away)
                }
                Text("\(match.homePartijen)-\(match.awayPartijen) in partijen · \(match.homeCompetitionPoints)-\(match.awayCompetitionPoints) competitiepunten")
                    .font(.system(size: 11))
                    .foregroundColor(SharedColors.textMuted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func teamSide(_ name: String, own: Bool) -> some View {
        Text(name)
            .font(.system(size: 14, weight: own ? .bold : .regular, design: .rounded))
            .foregroundColor(own ? SharedColors.accent : SharedColors.textPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Eén teamwedstrijd

public struct SharedTeamMatchView: View {
    @State private var match: TeamMatch
    private let store: any TeamMatchStore
    private let historyStore: any MatchHistoryStore
    private let team: LeagueTeamSnapshot?
    private let shareText: ((String) -> Void)?
    /// After a save (the match) or a delete (nil)
    private let onChange: (TeamMatch?) -> Void

    @State private var editing: TeamPartij? = nil
    @State private var confirmDelete = false
    @State private var message: String? = nil
    @Environment(\.dismiss) private var dismiss

    public init(match: TeamMatch, store: any TeamMatchStore, historyStore: any MatchHistoryStore,
                team: LeagueTeamSnapshot? = nil, shareText: ((String) -> Void)? = nil,
                onChange: @escaping (TeamMatch?) -> Void) {
        _match = State(initialValue: match)
        self.store = store
        self.historyStore = historyStore
        self.team = team
        self.shareText = shareText
        self.onChange = onChange
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    partijenList
                    if let message {
                        Text(message).font(.system(size: 12)).foregroundColor(SharedColors.error)
                    }
                    if let shareText {
                        ActionButton("Deel verslag", icon: "square.and.arrow.up", style: .filled) {
                            shareText(TeamMatchReport.text(match))
                        }
                    }
                    ActionButton("Verwijder teamwedstrijd", color: SharedColors.textSecondary) { confirmDelete = true }
                }
                .padding(24)
            }
        }
        .pageTitle("Teamwedstrijd")
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            if let editing {
                TeamPartijEditor(partij: editing, match: match, roster: rosterNames, historyStore: historyStore) { updated in
                    var changed = match
                    changed.update(updated)
                    self.editing = nil
                    Task { await save(changed) }
                } onCancel: { self.editing = nil }
            }
        }
        .alert("Teamwedstrijd verwijderen?", isPresented: $confirmDelete) {
            Button("Verwijder", role: .destructive) { Task { await remove() } }
            Button("Annuleer", role: .cancel) { }
        } message: {
            Text("De gekoppelde coach- en scheidsrechterwedstrijden blijven in Afgeronde wedstrijden staan.")
        }
    }

    /// Players of Mijn team, to pick our player from
    private var rosterNames: [String] {
        guard let team else { return [] }
        var names: [String] = []
        for player in team.players { names.append(player.name) }
        return names
    }

    private var header: some View {
        let score = match.score
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(TeamMatchReport.dayText(match.date)) · \(match.ownSide == TeamSide.home ? "thuis" : "uit")")
                .font(.system(size: 12))
                .foregroundColor(SharedColors.textSecondary)
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 4) {
                    Text(match.home)
                        .font(.system(size: 15, weight: match.ownSide == TeamSide.home ? .bold : .regular, design: .rounded))
                        .foregroundColor(match.ownSide == TeamSide.home ? SharedColors.accent : SharedColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(match.homeGames)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                Text("–").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundColor(SharedColors.textMuted)
                VStack(spacing: 4) {
                    Text(match.away)
                        .font(.system(size: 15, weight: match.ownSide == TeamSide.away ? .bold : .regular, design: .rounded))
                        .foregroundColor(match.ownSide == TeamSide.away ? SharedColors.accent : SharedColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(match.awayGames)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            Text("games").font(.system(size: 10)).tracking(1.2).foregroundColor(SharedColors.textMuted).frame(maxWidth: .infinity)
            Divider().overlay(Color.white.opacity(0.15))
            HStack {
                statCell("PARTIJEN", "\(match.homePartijen)-\(match.awayPartijen)")
                statCell("COMPETITIEPUNTEN", "\(match.homeCompetitionPoints)-\(match.awayCompetitionPoints)")
                statCell("RALLYPUNTEN", score.pointsKnown
                         ? (match.ownSide == TeamSide.home ? "\(score.ownPoints)-\(score.theirPoints)" : "\(score.theirPoints)-\(score.ownPoints)")
                         : "–")
            }
            Text(match.statusText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(score.isComplete ? SharedColors.gold : SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if score.isComplete {
                Text("Winnaar: meeste games; gelijk → meeste partijen; nog gelijk → meeste rallypunten. Competitiepunten: games + 3 bonus voor de winnaar.")
                    .font(.system(size: 11))
                    .foregroundColor(SharedColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.brandCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
    }

    private func statCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.accent)
            Text(title).font(.system(size: 9)).tracking(1.0).foregroundColor(SharedColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var partijenList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PARTIJEN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(SharedColors.accent)
            VStack(spacing: 0) {
                ForEach(match.partijen, id: \.slot) { partij in
                    partijRow(partij)
                    if partij.slot < 4 { Divider().overlay(Color.white.opacity(0.09)) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
            Text("Tik op een partij om spelers en games in te vullen of een bijgehouden wedstrijd te koppelen.")
                .font(.system(size: 11))
                .foregroundColor(SharedColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func partijRow(_ partij: TeamPartij) -> some View {
        Button { editing = partij } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(partij.label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.background)
                    .frame(width: 30, height: 30)
                    .background(partij.hasEntry ? SharedColors.accent : SharedColors.textMuted)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(partij.ownPlayer.isEmpty ? "Onze speler" : partij.ownPlayer)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(partij.ownPlayer.isEmpty ? SharedColors.textMuted : SharedColors.accent)
                            .lineLimit(1)
                        Text("–").foregroundColor(SharedColors.textMuted)
                        Text(partij.opponentPlayer.isEmpty ? "Tegenstander" : partij.opponentPlayer)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(partij.opponentPlayer.isEmpty ? SharedColors.textMuted : SharedColors.steelBlueLight)
                            .lineLimit(1)
                    }
                    if partij.hasEntry {
                        HStack(spacing: 6) {
                            Text(partij.standText)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(partij.ownWon == true ? SharedColors.accent : (partij.ownWon == false ? SharedColors.steelBlueLight : SharedColors.textPrimary))
                            Text(partij.gamesText)
                                .font(.system(size: 12))
                                .foregroundColor(SharedColors.textSecondary)
                                .lineLimit(1)
                            if partij.isLinked {
                                AppSymbol("arrow.right", size: 10, color: SharedColors.textMuted)
                            }
                        }
                    } else {
                        Text("Nog niet ingevuld")
                            .font(.system(size: 12))
                            .foregroundColor(SharedColors.textMuted)
                    }
                    if let order = partij.playOrder {
                        Text("Gespeeld als \(order)e")
                            .font(.system(size: 10))
                            .foregroundColor(SharedColors.textMuted)
                    }
                }
                Spacer()
                AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
            }
            .padding(12)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Partij \(partij.label)")
    }

    private func save(_ changed: TeamMatch) async {
        do {
            try await store.save(changed)
            match = changed
            message = nil
            onChange(changed)
        } catch {
            message = "Opslaan is niet gelukt."
        }
    }

    private func remove() async {
        do {
            try await store.delete(id: match.id)
            onChange(nil)
            dismiss()
        } catch {
            message = "Verwijderen is niet gelukt."
        }
    }
}

// MARK: - Partij invullen of koppelen

struct TeamPartijEditor: View {
    @State private var partij: TeamPartij
    let match: TeamMatch
    let roster: [String]
    let historyStore: any MatchHistoryStore
    let onSave: (TeamPartij) -> Void
    let onCancel: () -> Void

    @State private var ownText = ""
    @State private var theirText = ""
    @State private var scoreError: String? = nil
    @State private var choosingMatch = false
    @State private var history: [MatchHistorySummary] = []
    @State private var historyLoaded = false
    /// A tracked match chosen; which of its players is ours is asked next
    @State private var chosen: MatchHistorySummary? = nil

    init(partij: TeamPartij, match: TeamMatch, roster: [String], historyStore: any MatchHistoryStore,
         onSave: @escaping (TeamPartij) -> Void, onCancel: @escaping () -> Void) {
        _partij = State(initialValue: partij)
        self.match = match
        self.roster = roster
        self.historyStore = historyStore
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        playersSection
                        linkSection
                        gamesSection
                        orderSection
                    }
                    .padding(24)
                }
            }
            .pageTitle("Partij \(partij.label)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onCancel).foregroundColor(SharedColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") { onSave(partij) }.fontWeight(.bold).foregroundColor(SharedColors.accent)
                }
            }
            .sheet(isPresented: $choosingMatch) {
                TrackedMatchPicker(entries: history, loaded: historyLoaded, matchDate: match.date) { summary in
                    choosingMatch = false
                    chosen = summary
                } onCancel: { choosingMatch = false }
            }
            .alert("Wie is onze speler?", isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } })) {
                if let chosen {
                    Button(chosen.player1Name) { link(chosen, ownIsPlayer1: true) }
                    Button(chosen.player2Name) { link(chosen, ownIsPlayer1: false) }
                }
                Button("Annuleer", role: .cancel) { chosen = nil }
            } message: {
                Text("De games komen uit die wedstrijd, gezien vanuit onze speler.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var playersSection: some View {
        section("SPELERS") {
            field("Onze speler (\(match.ownName))", text: $partij.ownPlayer)
            if !roster.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(roster, id: \.self) { name in
                            Button { partij.ownPlayer = name } label: {
                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(partij.ownPlayer == name ? SharedColors.background : SharedColors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(partij.ownPlayer == name ? SharedColors.accent : SharedColors.accent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 999))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 2)
            }
            field("Tegenstander (\(match.opponentName))", text: $partij.opponentPlayer)
                .padding(.top, 8)
        }
    }

    private var linkSection: some View {
        section("BIJGEHOUDEN WEDSTRIJD") {
            if partij.isLinked {
                Text("Gekoppeld aan een \(partij.linkedKind == "referee" ? "scheidsrechter" : "coach")wedstrijd uit Afgeronde wedstrijden.")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ActionButton("Vernieuwen", icon: "arrow.counterclockwise") { Task { await refreshLink() } }
                    ActionButton("Ontkoppel", color: SharedColors.textSecondary) { partij.unlink() }
                }
                .padding(.top, 8)
            } else {
                Text("Hield je deze partij bij als coach of scheidsrechter? Dan komen de games vanzelf mee.")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionButton("Kies wedstrijd", icon: "arrow.right") {
                    choosingMatch = true
                    Task { await loadHistory() }
                }
                .padding(.top, 8)
            }
        }
    }

    private var gamesSection: some View {
        section("GAMES") {
            if partij.games.isEmpty {
                Text("Nog geen games.").font(.system(size: 12)).foregroundColor(SharedColors.textMuted)
            } else {
                ForEach(0..<partij.games.count, id: \.self) { index in
                    let game = partij.games[index]
                    HStack {
                        Text("Game \(index + 1)").font(.system(size: 13)).foregroundColor(SharedColors.textSecondary)
                        Spacer()
                        Text(game.text)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(game.ownWon ? SharedColors.accent : SharedColors.steelBlueLight)
                        Text(game.ownWon ? "wij" : "zij")
                            .font(.system(size: 11))
                            .foregroundColor(SharedColors.textMuted)
                            .frame(width: 26, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    Text("Stand \(partij.standText)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(partij.isOver ? SharedColors.gold : SharedColors.textPrimary)
                    Spacer()
                    Button("Laatste game wissen") { partij.removeLastGame() }
                        .font(.system(size: 12))
                        .foregroundColor(SharedColors.textSecondary)
                }
                .padding(.top, 4)
            }
            if partij.canAddGame {
                Divider().overlay(Color.white.opacity(0.09)).padding(.vertical, 6)
                Text("Game \(partij.games.count + 1) toevoegen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                HStack(spacing: 10) {
                    scoreField("wij", text: $ownText)
                    Text("–").foregroundColor(SharedColors.textMuted)
                    scoreField("zij", text: $theirText)
                    ActionButton("Voeg toe", style: .filled) { addScoredGame() }
                }
                if let scoreError {
                    Text(scoreError).font(.system(size: 11)).foregroundColor(SharedColors.error)
                }
                Text("Stand niet bekend? Dan alleen wie won:")
                    .font(.system(size: 11))
                    .foregroundColor(SharedColors.textMuted)
                    .padding(.top, 4)
                HStack(spacing: 10) {
                    winnerButton("Wij wonnen", own: true, color: SharedColors.accent)
                    winnerButton("Zij wonnen", own: false, color: SharedColors.steelBlueLight)
                }
            } else if partij.isOver {
                Text("Partij beslist.").font(.system(size: 12)).foregroundColor(SharedColors.textMuted).padding(.top, 4)
            }
        }
    }

    private var orderSection: some View {
        section("SPEELVOLGORDE (OPTIONEEL)") {
            HStack(spacing: 8) {
                ForEach(1..<5, id: \.self) { order in
                    Button { partij.playOrder = partij.playOrder == order ? nil : order } label: {
                        Text("\(order)e")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(partij.playOrder == order ? SharedColors.background : SharedColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(partij.playOrder == order ? SharedColors.accent : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(SharedColors.accent)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14))
            .foregroundColor(SharedColors.textPrimary)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }

    private func scoreField(_ placeholder: String, text: Binding<String>) -> some View {
        let field = TextField(placeholder, text: text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(SharedColors.textPrimary)
            .multilineTextAlignment(.center)
        #if os(iOS)
        return field
            .keyboardType(.numberPad)
            .lineLimit(1)
            .padding(8)
            .frame(width: 76)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        #else
        return field
            .lineLimit(1)
            .padding(8)
            .frame(width: 76)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        #endif
    }

    private func winnerButton(_ title: String, own: Bool, color: Color) -> some View {
        Button {
            _ = partij.addGame(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: own))
            scoreError = nil
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func addScoredGame() {
        guard let own = Int(ownText.trimmingCharacters(in: .whitespaces)),
              let their = Int(theirText.trimmingCharacters(in: .whitespaces)) else {
            scoreError = "Vul beide standen in, bijvoorbeeld 11 en 8."
            return
        }
        guard TeamGame.isValidScore(own, their) else {
            scoreError = "Geen squashstand: tot 11 met twee punten verschil (11-9, 12-10, 15-13)."
            return
        }
        if partij.addGame(TeamGame(own: own, their: their)) {
            ownText = ""
            theirText = ""
            scoreError = nil
        }
    }

    private func loadHistory() async {
        guard !historyLoaded else { return }
        if let entries = try? await historyStore.loadHistory() {
            history = entries
        }
        historyLoaded = true
    }

    private func link(_ summary: MatchHistorySummary, ownIsPlayer1: Bool) {
        partij.link(summary, ownIsPlayer1: ownIsPlayer1)
        chosen = nil
        scoreError = nil
    }

    /// Reads the linked match again, e.g. after its result was completed
    private func refreshLink() async {
        guard let id = partij.linkedMatchId else { return }
        historyLoaded = false
        await loadHistory()
        for entry in history where entry.id == id {
            let ownIsPlayer1 = entry.player1Name == partij.ownPlayer
            partij.link(entry, ownIsPlayer1: ownIsPlayer1)
        }
    }
}

/// Coach and referee matches on this phone, the ones of the match day on top
struct TrackedMatchPicker: View {
    let entries: [MatchHistorySummary]
    let loaded: Bool
    let matchDate: Date
    let onPick: (MatchHistorySummary) -> Void
    let onCancel: () -> Void

    private var sorted: [MatchHistorySummary] {
        let calendar = Calendar.current
        let sameDay = entries.filter { entry in calendar.isDate(entry.updatedAt, inSameDayAs: matchDate) }
        let others = entries.filter { entry in !calendar.isDate(entry.updatedAt, inSameDayAs: matchDate) }
        return sameDay + others
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !loaded {
                            ProgressView().frame(maxWidth: .infinity)
                        } else if entries.isEmpty {
                            Text("Nog geen bijgehouden wedstrijden.").font(.system(size: 13)).foregroundColor(SharedColors.textMuted)
                        } else {
                            Text("Wedstrijden van de speeldag staan bovenaan.")
                                .font(.system(size: 12))
                                .foregroundColor(SharedColors.textMuted)
                            ForEach(sorted) { entry in
                                Button { onPick(entry) } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(entry.player1Name) – \(entry.player2Name)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(SharedColors.textPrimary)
                                                .lineLimit(1)
                                            Text("\(TeamMatchReport.dayText(entry.updatedAt)) · \(entry.kind == "referee" ? "scheidsrechter" : "coach") · \(entry.player1Games)-\(entry.player2Games)" + (entry.status == "abandoned" ? " · incompleet" : ""))
                                                .font(.system(size: 11))
                                                .foregroundColor(SharedColors.textSecondary)
                                        }
                                        Spacer()
                                        AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .pageTitle("Kies wedstrijd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onCancel).foregroundColor(SharedColors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Nieuwe teamwedstrijd

struct NewTeamMatchSheet: View {
    let team: LeagueTeamSnapshot?
    let existing: [TeamMatch]
    let onCreate: (TeamMatch) -> Void
    let onCancel: () -> Void

    @State private var ownTeam = ""
    @State private var opponent = ""
    @State private var atHome = true
    @State private var date = Date()

    /// Matches of Mijn team without a team match yet, nearest to today first
    private var openFixtures: [LeagueFixture] {
        guard let team else { return [] }
        var taken: [String] = []
        for match in existing { if let id = match.fixtureId { taken.append(id) } }
        let now = Date()
        return team.fixtures
            .filter { fixture in !taken.contains(fixture.id) }
            .sorted(by: { a, b in abs(a.date.timeIntervalSince(now)) < abs(b.date.timeIntervalSince(now)) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let team, !openFixtures.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("UIT HET PROGRAMMA VAN \(team.name.uppercased())")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1.4)
                                    .foregroundColor(SharedColors.accent)
                                ForEach(openFixtures) { fixture in
                                    Button { onCreate(TeamMatch.from(fixture: fixture, ownTeam: team.name)) } label: {
                                        HStack(spacing: 10) {
                                            Text(TeamMatchReport.dayText(fixture.date))
                                                .font(.system(size: 11))
                                                .foregroundColor(SharedColors.textMuted)
                                                .frame(width: 70, alignment: .leading)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(fixture.home).foregroundColor(SharedColors.textPrimary)
                                                Text(fixture.away).foregroundColor(SharedColors.textSecondary)
                                            }
                                            .font(.system(size: 13))
                                            Spacer()
                                            AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ZELF INVULLEN")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.4)
                                .foregroundColor(SharedColors.accent)
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Ons team", text: $ownTeam)
                                    .font(.system(size: 14))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                TextField("Tegenstander", text: $opponent)
                                    .font(.system(size: 14))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                Picker("Waar", selection: $atHome) {
                                    Text("Thuis").tag(true)
                                    Text("Uit").tag(false)
                                }
                                .pickerStyle(.segmented)
                                DatePicker("Datum", selection: $date, displayedComponents: .date)
                                    .font(.system(size: 14))
                                    .foregroundColor(SharedColors.textPrimary)
                                ActionButton("Maak teamwedstrijd", style: .filled, disabled: ownTeam.trimmingCharacters(in: .whitespaces).isEmpty || opponent.trimmingCharacters(in: .whitespaces).isEmpty) {
                                    let own = ownTeam.trimmingCharacters(in: .whitespaces)
                                    let other = opponent.trimmingCharacters(in: .whitespaces)
                                    onCreate(TeamMatch(date: date, home: atHome ? own : other, away: atHome ? other : own,
                                                       ownSide: atHome ? TeamSide.home : TeamSide.away))
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                        }
                    }
                    .padding(24)
                }
            }
            .pageTitle("Nieuwe teamwedstrijd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onCancel).foregroundColor(SharedColors.textSecondary)
                }
            }
            .onAppear { if ownTeam.isEmpty, let team { ownTeam = team.name } }
        }
        .preferredColorScheme(.dark)
    }
}
