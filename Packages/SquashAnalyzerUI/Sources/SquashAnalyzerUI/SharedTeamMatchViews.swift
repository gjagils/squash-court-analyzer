import SwiftUI
import SquashAnalyzerCore

// MARK: - Competitie: teamwedstrijden (SBN, vier partijen E1–E4)
//
// Shared by iOS and Android. The list opens one team match; a team match
// has four partijen that are filled in by hand (game scores) or linked to a
// coach or referee match tracked on this phone. The stand, the winner and
// the competition points come from Core (`TeamMatch`), the message from
// `TeamMatchReport`.

/// What a team match screen needs to start a tracked match for a partij and
/// to share the report: the stores of the coach and referee sessions, the
/// players and the platform share sheet. Built by the host app.
public struct TeamMatchTools {
    public let historyStore: any MatchHistoryStore
    public let playerStore: any PlayerProfileStore
    public let coachStore: any CoachMatchStore
    public let refereeStore: any RefereeMatchStore
    public let photoStore: (any PlayerPhotoStore)?
    public let filePicker: (any PlayerFilePicker)?
    public let aiCoach: AICoachContext?
    public let shareText: ((String) -> Void)?

    public init(historyStore: any MatchHistoryStore, playerStore: any PlayerProfileStore,
                coachStore: any CoachMatchStore, refereeStore: any RefereeMatchStore,
                photoStore: (any PlayerPhotoStore)? = nil, filePicker: (any PlayerFilePicker)? = nil,
                aiCoach: AICoachContext? = nil, shareText: ((String) -> Void)? = nil) {
        self.historyStore = historyStore
        self.playerStore = playerStore
        self.coachStore = coachStore
        self.refereeStore = refereeStore
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.aiCoach = aiCoach
        self.shareText = shareText
    }
}

/// After a match on a match day of Mijn team: does it belong to the team
/// match, as which partij, and which player is ours?
public struct TeamMatchLinkPrompt: View {
    let team: TeamMatch
    let player1Name: String
    let player2Name: String
    /// slot (1...4) and whether our player is player 1 of the match
    let onLink: (Int, Bool) -> Void
    let onSkip: () -> Void

    @State private var slot: Int? = nil

    public init(team: TeamMatch, player1Name: String, player2Name: String,
                onLink: @escaping (Int, Bool) -> Void, onSkip: @escaping () -> Void) {
        self.team = team
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.onLink = onLink
        self.onSkip = onSkip
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("COMPETITIE VANDAAG")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(SharedColors.accent)
                    Text(team.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Hoort \(player1Name) – \(player2Name) bij deze teamwedstrijd? Kies de partij.")
                        .font(.system(size: 14))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 8) {
                        ForEach(team.partijen, id: \.slot) { partij in
                            Button { slot = partij.slot } label: {
                                HStack(spacing: 12) {
                                    Text(partij.label)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(SharedColors.background)
                                        .frame(width: 30, height: 30)
                                        .background(slot == partij.slot ? SharedColors.accent : SharedColors.textMuted)
                                        .clipShape(Circle())
                                    Text(partij.hasEntry
                                         ? "\(team.ownDisplayName(partij)) – \(team.opponentDisplayName(partij)) · \(partij.standText)"
                                         : "nog leeg")
                                        .font(.system(size: 14))
                                        .foregroundColor(partij.hasEntry ? SharedColors.textPrimary : SharedColors.textMuted)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .background(slot == partij.slot ? SharedColors.accent.opacity(0.14) : Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let slot {
                        Text("Wie is onze speler (\(team.ownName))?")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(SharedColors.textPrimary)
                        HStack(spacing: 10) {
                            ActionButton(player1Name, style: .filled) { onLink(slot, true) }
                            ActionButton(player2Name, style: .filled, color: SharedColors.steelBlueLight) { onLink(slot, false) }
                        }
                    }
                    ActionButton("Nee, gewone wedstrijd", color: SharedColors.textSecondary, action: onSkip)
                        .padding(.top, 8)
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Afgeronde en lopende teamwedstrijden, nieuwste eerst
public struct SharedTeamMatchesView: View {
    private let store: any TeamMatchStore
    private let tools: TeamMatchTools
    /// Mijn team, when a link is saved: its matches and players
    private let team: LeagueTeamSnapshot?

    @State private var matches: [TeamMatch] = []
    @State private var isLoading = true
    @State private var creating = false
    @State private var joining = false
    @State private var opened: TeamMatch? = nil
    @State private var message: String? = nil

    public init(store: any TeamMatchStore, tools: TeamMatchTools, team: LeagueTeamSnapshot? = nil) {
        self.store = store
        self.tools = tools
        self.team = team
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
                    ActionButton("Deelnemen met link of code") { joining = true }
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
        .sheet(isPresented: $joining) {
            SharedTeamJoinView(store: store, team: team) { joined in
                joining = false
                Task {
                    await load()
                    opened = joined
                }
            } onCancel: { joining = false }
        }
        .navigationDestination(isPresented: Binding(get: { opened != nil }, set: { if !$0 { opened = nil } })) {
            if let opened {
                SharedTeamMatchView(match: opened, store: store, tools: tools, team: team) { _ in
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
    private let tools: TeamMatchTools
    private let team: LeagueTeamSnapshot?
    /// After a save (the match) or a delete (nil)
    private let onChange: (TeamMatch?) -> Void

    @State private var editing: TeamPartij? = nil
    @State private var confirmDelete = false
    @State private var message: String? = nil
    @State private var sharing = false
    @State private var liveBusy = false
    @State private var confirmStopLive = false
    /// A tracked match being played for a partij (full screen)
    @State private var tracking: TeamTrackRequest? = nil
    /// Asked for in the editor; opens as soon as the editor sheet is gone
    @State private var pendingTrack: TeamTrackRequest? = nil
    @State private var players: [PlayerProfile] = []
    @AppStorage(TeamRoster.storageKey) private var rosterRaw = ""
    @Environment(\.dismiss) private var dismiss

    public init(match: TeamMatch, store: any TeamMatchStore, tools: TeamMatchTools,
                team: LeagueTeamSnapshot? = nil, onChange: @escaping (TeamMatch?) -> Void) {
        _match = State(initialValue: match)
        self.store = store
        self.tools = tools
        self.team = team
        self.onChange = onChange
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    partijenList
                    TeamLiveCard(match: match, busy: liveBusy, canShare: tools.shareText != nil,
                                 problem: liveProblem,
                                 onGoLive: { Task { await goLive() } },
                                 onShareViewers: { tools.shareText?(TeamLiveTexts.viewers(match, baseURL: TeamLive.shared.baseURL)) },
                                 onShareInvite: { tools.shareText?(TeamLiveTexts.invite(match)) },
                                 onRefresh: { Task { await refreshLive() } },
                                 onStop: { confirmStopLive = true })
                    if let message {
                        Text(message).font(.system(size: 12)).foregroundColor(SharedColors.error)
                    }
                    if tools.shareText != nil {
                        ActionButton("Deel verslag", icon: "square.and.arrow.up", style: .filled) { sharing = true }
                    }
                    ActionButton("Verwijder teamwedstrijd", color: SharedColors.textSecondary) { confirmDelete = true }
                }
                .padding(24)
            }
        }
        .pageTitle("Teamwedstrijd")
        .task {
            players = (try? await tools.playerStore.loadPlayers()) ?? []
            await syncFromLive(showGone: false)
        }
        .alert(match.isLiveOwner ? "Live stoppen?" : "Live verlaten?", isPresented: $confirmStopLive) {
            Button(match.isLiveOwner ? "Stop live" : "Verlaat live", role: .destructive) { Task { await stopLive() } }
            Button("Annuleer", role: .cancel) { }
        } message: {
            Text(match.isLiveOwner
                 ? "De livepagina is meteen weg voor iedereen. Je teamwedstrijd blijft in de app staan."
                 : "Je partijen komen niet meer op de livepagina van je teamgenoot. De pagina blijft bestaan voor de rest; je teamwedstrijd blijft in de app staan.")
        }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }), onDismiss: {
            // The full screen may only open once the sheet is really gone
            if let request = pendingTrack {
                pendingTrack = nil
                tracking = request
            }
        }) {
            if let editing {
                TeamPartijEditor(partij: editing, match: match, roster: rosterNames, historyStore: tools.historyStore) { updated in
                    var changed = match
                    changed.update(updated)
                    self.editing = nil
                    Task { await save(changed) }
                } onTrack: { updated, kind in
                    startTracking(updated, kind: kind)
                } onCancel: { self.editing = nil }
            }
        }
        .sheet(isPresented: $sharing) {
            if let shareText = tools.shareText {
                TeamMatchShareView(match: match, shareText: shareText) { sharing = false }
            }
        }
        .trackedCover(isPresented: Binding(get: { tracking != nil }, set: { if !$0 { tracking = nil } })) {
            if let request = tracking {
                trackedSession(request)
            }
        }
        .alert("Teamwedstrijd verwijderen?", isPresented: $confirmDelete) {
            Button("Verwijder", role: .destructive) { Task { await remove() } }
            Button("Annuleer", role: .cancel) { }
        } message: {
            Text("De gekoppelde coach- en scheidsrechterwedstrijden blijven in Afgeronde wedstrijden staan.")
        }
    }

    /// Why this phone's partijen may not reach the live page, for the card
    private var liveProblem: String? {
        guard let id = match.liveId else { return nil }
        if TeamLive.shared.isRejected(id) {
            return "De livepagina wil je partij niet hebben: de uitnodigingscode klopt niet (meer). Vraag je teamgenoot de uitnodiging opnieuw te sturen en doe weer mee."
        }
        if TeamLive.shared.offline {
            return "Geen verbinding: je partij staat nog niet op de livepagina. Tik op Vernieuwen zodra je weer internet hebt."
        }
        return nil
    }

    /// "Vernieuwen": send our partijen again (what failed earlier), then read what teammates put there
    private func refreshLive() async {
        liveBusy = true
        await TeamLive.shared.pushAll(match)
        liveBusy = false
        await syncFromLive(showGone: true)
    }

    /// Our players to pick from: "In mijn team" first, then Mijn team
    private var rosterNames: [String] {
        TeamMatchSupport.rosterNames(players: players, team: team, rosterRaw: rosterRaw)
    }

    /// The editor asks for a new tracked match: keep the partij as edited,
    /// close the editor, then open the coach or referee screen for it
    private func startTracking(_ updated: TeamPartij, kind: String) {
        var changed = match
        changed.update(updated)
        match = changed
        // Asked for before the sheet closes: its onDismiss opens the full screen
        pendingTrack = TeamTrackRequest(slot: updated.slot, kind: kind)
        editing = nil
        Task { @MainActor in
            await save(changed)
        }
    }

    @ViewBuilder
    private func trackedSession(_ request: TeamTrackRequest) -> some View {
        let target = TeamTarget.make(team: match, slot: request.slot)
        if request.kind == "referee" {
            RefereeSessionView(store: tools.refereeStore, playerStore: tools.playerStore, photoStore: tools.photoStore,
                               filePicker: tools.filePicker, shareText: tools.shareText,
                               teamMatchStore: store, teamTarget: target,
                               onExit: { trackingDone() })
        } else {
            CoachSessionView(store: tools.coachStore, playerStore: tools.playerStore, photoStore: tools.photoStore,
                             filePicker: tools.filePicker, aiCoach: tools.aiCoach, shareText: tools.shareText,
                             historyStore: tools.historyStore, settings: nil,
                             teamMatchStore: store, teamTarget: target,
                             onExit: { trackingDone() })
        }
    }

    /// Back from the tracked match: it was linked to the partij while closing
    @MainActor private func trackingDone() {
        tracking = nil
        Task { @MainActor in
            if let all = try? await store.loadAll() {
                for stored in all where stored.id == match.id { match = stored }
            }
            onChange(match)
        }
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
                        Text(match.ownDisplayName(partij))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(partij.ownPlayer.isEmpty ? SharedColors.textMuted : SharedColors.accent)
                            .lineLimit(1)
                        Text("–").foregroundColor(SharedColors.textMuted)
                        Text(match.opponentDisplayName(partij))
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
            let before = match
            match = changed
            message = nil
            onChange(changed)
            // Live: only the partijen this save changed go up, so another
            // phone's partij is never overwritten with an old copy
            if changed.isLive {
                for slot in 1...4 where before.partij(slot) != changed.partij(slot) {
                    if changed.partij(slot).hasEntry {
                        _ = await TeamLive.shared.push(changed.partij(slot), in: changed)
                    } else if before.partij(slot).hasEntry {
                        // Emptied here: it leaves the live page too
                        _ = await TeamLive.shared.clear(slot: slot, in: changed)
                    }
                }
            }
        } catch {
            message = "Opslaan is niet gelukt."
        }
    }

    /// "Live delen": make the live page, put what is filled in on it, share the viewers' link
    private func goLive() async {
        liveBusy = true
        defer { liveBusy = false }
        do {
            let created = try await TeamLive.shared.create(match)
            var changed = match
            changed.liveId = created.id
            changed.liveKey = created.writeKey
            changed.liveOwnerKey = created.ownerKey
            try await store.save(changed)
            match = changed
            onChange(changed)
            await TeamLive.shared.pushAll(changed)
            message = nil
            tools.shareText?(TeamLiveTexts.viewers(changed, baseURL: TeamLive.shared.baseURL))
        } catch {
            message = "Live delen lukte niet. Controleer de internetverbinding en probeer het opnieuw."
        }
    }

    private func stopLive() async {
        liveBusy = true
        // Only the phone that started it ends the page for everyone; a phone
        // that joined just leaves it
        if match.isLiveOwner { await TeamLive.shared.stop(match) }
        liveBusy = false
        await clearLive()
    }

    /// The live page is over (stopped, or gone two hours after the last update)
    private func clearLive() async {
        var changed = match
        changed.liveId = nil
        changed.liveKey = nil
        changed.liveOwnerKey = nil
        try? await store.save(changed)
        match = changed
        onChange(changed)
    }

    /// Takes in what teammates put on the live page; a page that is gone ends the live state here
    private func syncFromLive(showGone: Bool) async {
        guard let id = match.liveId else { return }
        do {
            let state = try await TeamLive.shared.fetch(id: id)
            var changed = match
            if changed.mergeLive(state) {
                try await store.save(changed)
                match = changed
                onChange(changed)
            }
            if showGone { message = nil }
        } catch let error as TeamLiveError {
            if error == TeamLiveError.gone {
                if showGone {
                    // Asked for by the user: the page is really gone, the live state ends here
                    await clearLive()
                    message = "De livepagina is afgelopen (2 uur na de laatste update) en wordt niet meer bijgewerkt."
                } else {
                    // On opening the screen: not yet sure enough to throw the key away
                    message = "De livepagina lijkt afgelopen. Tik op Vernieuwen om dat te bevestigen."
                }
            } else if showGone {
                message = "Geen verbinding om de livepagina te lezen."
            }
        } catch {
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

/// A new tracked match for one partij of the team match on screen
struct TeamTrackRequest: Equatable {
    /// Every request is its own: asking for the same partij again opens it again
    let id = UUID()
    let slot: Int
    /// "coach" or "referee"
    let kind: String

    static func == (a: TeamTrackRequest, b: TeamTrackRequest) -> Bool { a.id == b.id }
}


extension View {
    /// A full-screen cover for a tracked match; the macOS build of the UI
    /// package (run before the Android build) has no full-screen covers
    func trackedCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(macOS) && !SKIP
        return self.sheet(isPresented: isPresented, content: content)
        #else
        return self.fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}
