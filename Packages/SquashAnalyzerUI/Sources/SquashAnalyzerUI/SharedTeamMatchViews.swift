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

/// A coach or referee match played for a partij of a team match: the names
/// to start with and where the result goes when the match is over (and, when
/// the team match is live, where its state goes while it is played).
public struct TeamTarget: Equatable {
    public let teamMatchId: UUID
    public let slot: Int
    public let ownPlayer: String
    public let opponentPlayer: String
    /// Our player is Speler 1 of the tracked match
    public let ownIsPlayer1: Bool
    public let ownSide: TeamSide
    /// The live team match, when there is one
    public let liveId: String?
    public let liveKey: String?
    /// How the live page names the home and the away player: a first name, or
    /// empty for the default ("Squash Delft 8 E1")
    public let homeLabel: String
    public let awayLabel: String

    public init(teamMatchId: UUID, slot: Int, ownPlayer: String, opponentPlayer: String, ownIsPlayer1: Bool,
                ownSide: TeamSide = TeamSide.home, liveId: String? = nil, liveKey: String? = nil,
                homeLabel: String = "", awayLabel: String = "") {
        self.teamMatchId = teamMatchId
        self.slot = slot
        self.ownPlayer = ownPlayer
        self.opponentPlayer = opponentPlayer
        self.ownIsPlayer1 = ownIsPlayer1
        self.ownSide = ownSide
        self.liveId = liveId
        self.liveKey = liveKey
        self.homeLabel = homeLabel
        self.awayLabel = awayLabel
    }

    public var player1Name: String { ownIsPlayer1 ? ownPlayer : opponentPlayer }
    public var player2Name: String { ownIsPlayer1 ? opponentPlayer : ownPlayer }
    /// The home player of the team match is Speler 1 of the tracked match
    public var homeIsPlayer1: Bool { ownIsPlayer1 == (ownSide == TeamSide.home) }

    /// The target for `slot`: with nothing filled in the names are the
    /// defaults, and as a rule the home player starts as Speler 1 (as SBN prints it)
    public static func make(team: TeamMatch, slot: Int, ownIsPlayer1: Bool? = nil,
                            ownName: String? = nil, opponentName: String? = nil) -> TeamTarget {
        let partij = team.partij(slot)
        let own = ownName ?? team.ownDisplayName(partij)
        let opponent = opponentName ?? team.opponentDisplayName(partij)
        let ownFirst = ownIsPlayer1 ?? (team.ownSide == TeamSide.home)
        func label(_ name: String, _ standard: String) -> String {
            TeamMatch.sameTeam(name, standard) ? "" : LiveSnapshot.firstName(name, fallback: "")
        }
        let ownLabel = label(own, team.defaultOwnName(slot))
        let opponentLabel = label(opponent, team.defaultOpponentName(slot))
        return TeamTarget(teamMatchId: team.id, slot: slot, ownPlayer: own, opponentPlayer: opponent, ownIsPlayer1: ownFirst,
                          ownSide: team.ownSide, liveId: team.liveId, liveKey: team.liveKey,
                          homeLabel: team.ownSide == TeamSide.home ? ownLabel : opponentLabel,
                          awayLabel: team.ownSide == TeamSide.home ? opponentLabel : ownLabel)
    }

    /// Which player of the finished match is ours: by name, else as started
    func ownIsPlayer1(in match1: String, _ match2: String) -> Bool {
        let own = ownPlayer.trimmingCharacters(in: .whitespaces).lowercased()
        if !own.isEmpty && match1.trimmingCharacters(in: .whitespaces).lowercased() == own { return true }
        if !own.isEmpty && match2.trimmingCharacters(in: .whitespaces).lowercased() == own { return false }
        return ownIsPlayer1
    }

    /// Starts forwarding a tracked match to the live page of this team match
    @MainActor func bind(matchId: UUID) {
        guard let liveId, let liveKey else { return }
        TeamLive.shared.bind(matchId: matchId, teamId: liveId, writeKey: liveKey, slot: slot,
                             homeIsPlayer1: homeIsPlayer1, homeLabel: homeLabel, awayLabel: awayLabel)
    }
}

public enum TeamMatchSupport {
    /// A match started for a partij is remembered in the team match, so that
    /// leaving and resuming it later picks the coupling up again
    @MainActor public static func track(_ target: TeamTarget, matchId: UUID, store: any TeamMatchStore) async {
        guard let all = try? await store.loadAll() else { return }
        for var team in all where team.id == target.teamMatchId {
            team.startTracking(slot: target.slot, matchId: matchId.uuidString, ownIsPlayer1: target.ownIsPlayer1,
                               ownPlayer: target.ownPlayer, opponentPlayer: target.opponentPlayer)
            try? await store.save(team)
        }
    }

    /// The coupling of a resumed match, from the team match it was started for
    @MainActor public static func target(forMatchId id: UUID, store: any TeamMatchStore) async -> TeamTarget? {
        guard let all = try? await store.loadAll() else { return nil }
        for team in all {
            if let partij = team.partijTracking(matchId: id.uuidString) {
                return TeamTarget.make(team: team, slot: partij.slot, ownIsPlayer1: partij.trackingOwnIsPlayer1,
                                       ownName: team.ownDisplayName(partij), opponentName: team.opponentDisplayName(partij))
            }
        }
        return nil
    }

    /// The finished coach match goes into the partij it was started for
    @MainActor public static func link(coach match: Match, target: TeamTarget, store: any TeamMatchStore) async {
        guard let all = try? await store.loadAll() else { return }
        for var team in all where team.id == target.teamMatchId {
            var partij = team.partij(target.slot)
            partij.link(coach: match, ownIsPlayer1: target.ownIsPlayer1(in: match.player1Name, match.player2Name))
            team.update(partij)
            try? await store.save(team)
            _ = await TeamLive.shared.push(team.partij(target.slot), in: team)
        }
        TeamLive.shared.unbind(matchId: match.id)
    }

    /// The match-day question was answered: the finished match goes into that
    /// partij, through the same route as a match started for it (stored again
    /// from what is stored now, so what teammates put on the live page in the
    /// meantime is not overwritten, and the live page gets the result)
    @MainActor public static func linkOnMatchDay(coach match: Match, team: TeamMatch, slot: Int, ownIsPlayer1: Bool,
                                                 store: any TeamMatchStore) async {
        await ensureStored(team, store: store)
        let target = TeamTarget.make(team: team, slot: slot, ownIsPlayer1: ownIsPlayer1,
                                     ownName: ownIsPlayer1 ? match.player1Name : match.player2Name,
                                     opponentName: ownIsPlayer1 ? match.player2Name : match.player1Name)
        await link(coach: match, target: target, store: store)
    }

    @MainActor public static func linkOnMatchDay(referee match: RefereeMatch, team: TeamMatch, slot: Int, ownIsPlayer1: Bool,
                                                 store: any TeamMatchStore) async {
        await ensureStored(team, store: store)
        let target = TeamTarget.make(team: team, slot: slot, ownIsPlayer1: ownIsPlayer1,
                                     ownName: ownIsPlayer1 ? match.player1Name : match.player2Name,
                                     opponentName: ownIsPlayer1 ? match.player2Name : match.player1Name)
        await link(referee: match, target: target, store: store)
    }

    /// A team match from the fixtures of Mijn team is not saved until a partij is linked
    @MainActor private static func ensureStored(_ team: TeamMatch, store: any TeamMatchStore) async {
        if let all = try? await store.loadAll() {
            for stored in all where stored.id == team.id { return }
        }
        try? await store.save(team)
    }

    /// The finished referee match goes into the partij it was started for
    @MainActor public static func link(referee match: RefereeMatch, target: TeamTarget, store: any TeamMatchStore) async {
        guard let all = try? await store.loadAll() else { return }
        for var team in all where team.id == target.teamMatchId {
            var partij = team.partij(target.slot)
            partij.link(referee: match, ownIsPlayer1: target.ownIsPlayer1(in: match.player1Name, match.player2Name))
            team.update(partij)
            try? await store.save(team)
            _ = await TeamLive.shared.push(team.partij(target.slot), in: team)
        }
        TeamLive.shared.unbind(matchId: match.id)
    }

    /// The names to offer as our player: the players marked "In mijn team"
    /// first, then the players of Mijn team, without doubles
    public static func rosterNames(players: [PlayerProfile], team: LeagueTeamSnapshot?, rosterRaw: String) -> [String] {
        let ids = TeamRoster.parse(rosterRaw)
        var names: [String] = []
        for player in players where ids.contains(player.id) {
            if !names.contains(player.name) { names.append(player.name) }
        }
        if let team {
            for player in team.players where !names.contains(player.name) { names.append(player.name) }
        }
        return names
    }

    /// Mijn team as last fetched (Instellingen holds the link), for the
    /// fixtures and the roster; nil without a link
    public static func cachedTeam() -> LeagueTeamSnapshot? {
        let saved = UserDefaults.standard.string(forKey: LeagueTeamStorage.linkKey) ?? ""
        guard !saved.isEmpty, let link = try? LeagueTeamLink(saved) else { return nil }
        return LeagueTeamStorage.cachedSnapshot(for: link)
    }

    /// Team matches a new coach or referee match can belong to: the saved ones
    /// that are not decided yet (nearest to today first), then the coming
    /// matches of Mijn team that have no team match yet (not saved until used)
    @MainActor public static func candidates(store: any TeamMatchStore, now: Date = Date()) async -> [TeamMatch] {
        var result: [TeamMatch] = []
        var taken: [String] = []
        if let all = try? await store.loadAll() {
            var open: [TeamMatch] = []
            for match in all {
                if let id = match.fixtureId { taken.append(id) }
                if !match.isComplete { open.append(match) }
            }
            result = open.sorted(by: { a, b in abs(a.date.timeIntervalSince(now)) < abs(b.date.timeIntervalSince(now)) })
        }
        if let team = cachedTeam() {
            let from = now.addingTimeInterval(-24.0 * 3600.0)
            let until = now.addingTimeInterval(14.0 * 24.0 * 3600.0)
            for fixture in team.fixtures where fixture.date >= from && fixture.date <= until && !taken.contains(fixture.id) {
                result.append(TeamMatch.from(fixture: fixture, ownTeam: team.name))
            }
        }
        return Array(result.prefix(6))
    }

    /// The team match of today, to ask about after a coach or referee match:
    /// one already started on this phone, else a match of Mijn team played
    /// today (not saved until a partij is linked). Nil on an ordinary day.
    @MainActor public static func candidate(store: any TeamMatchStore, now: Date = Date()) async -> TeamMatch? {
        let calendar = Calendar.current
        if let all = try? await store.loadAll() {
            for match in all where calendar.isDate(match.date, inSameDayAs: now) { return match }
        }
        guard let team = cachedTeam() else { return nil }
        for fixture in team.fixtures where calendar.isDate(fixture.date, inSameDayAs: now) {
            return TeamMatch.from(fixture: fixture, ownTeam: team.name)
        }
        return nil
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

// MARK: - Partij invullen of koppelen

struct TeamPartijEditor: View {
    @State private var partij: TeamPartij
    let match: TeamMatch
    let roster: [String]
    let historyStore: any MatchHistoryStore
    let onSave: (TeamPartij) -> Void
    /// A new tracked match for this partij: the partij as edited and "coach" or "referee"
    let onTrack: (TeamPartij, String) -> Void
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
         onSave: @escaping (TeamPartij) -> Void, onTrack: @escaping (TeamPartij, String) -> Void,
         onCancel: @escaping () -> Void) {
        _partij = State(initialValue: partij)
        self.match = match
        self.roster = roster
        self.historyStore = historyStore
        self.onSave = onSave
        self.onTrack = onTrack
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
                TrackedMatchPicker(entries: history, loaded: historyLoaded, matchDate: match.date,
                                   homeIsOurs: match.ownSide == TeamSide.home) { summary in
                    choosingMatch = false
                    chosen = summary
                } onNew: { kind in
                    choosingMatch = false
                    onTrack(partij, kind)
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
            field(match.defaultOwnName(partij.slot), text: $partij.ownPlayer)
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
            field(match.defaultOpponentName(partij.slot), text: $partij.opponentPlayer)
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
            partij.refreshLink(from: entry)
        }
    }
}

/// Coach and referee matches on this phone, the ones of the match day on top
struct TrackedMatchPicker: View {
    let entries: [MatchHistorySummary]
    let loaded: Bool
    let matchDate: Date
    /// Our team plays at home: our player starts as Speler 1
    let homeIsOurs: Bool
    let onPick: (MatchHistorySummary) -> Void
    /// "coach" or "referee": a new match to track for this partij
    let onNew: (String) -> Void
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
                        Text("NIEUWE WEDSTRIJD BIJHOUDEN")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(SharedColors.accent)
                        HStack(spacing: 10) {
                            ActionButton("Coach") { onNew("coach") }
                            ActionButton("Scheidsrechter") { onNew("referee") }
                        }
                        Text(homeIsOurs ? "Wij spelen thuis: onze speler start als Speler 1." : "Wij spelen uit: onze speler start als Speler 2.")
                            .font(.system(size: 11))
                            .foregroundColor(SharedColors.textMuted)
                        Text("OF EEN BIJGEHOUDEN WEDSTRIJD")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(SharedColors.accent)
                            .padding(.top, 10)
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


/// A new tracked match for one partij of the team match on screen
struct TeamTrackRequest: Equatable {
    /// Every request is its own: asking for the same partij again opens it again
    let id = UUID()
    let slot: Int
    /// "coach" or "referee"
    let kind: String

    static func == (a: TeamTrackRequest, b: TeamTrackRequest) -> Bool { a.id == b.id }
}

// MARK: - Verslag delen

/// "Deel verslag": the same three choices as "Deel score" of a match
/// (Scorekaart, Verslag, Plaatje), with a preview and one Delen button. The
/// choice is the same setting as for a match.
struct TeamMatchShareView: View {
    let match: TeamMatch
    let shareText: (String) -> Void
    let onClose: () -> Void

    @AppStorage(MatchShareChoice.storageKey) private var storedChoice = MatchShareChoice.scorecard.rawValue

    private var choices: [MatchShareChoice] {
        ResultImageSharing.share == nil ? MatchShareChoice.allCases.filter { $0 != MatchShareChoice.picture } : MatchShareChoice.allCases
    }

    private var choice: MatchShareChoice {
        let stored = MatchShareChoice.from(stored: storedChoice)
        return choices.contains(stored) ? stored : MatchShareChoice.scorecard
    }

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                tabs
                Text(choice.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                ScrollView {
                    if let style = choice.textStyle {
                        WhatsAppPreview(text: TeamMatchReport.text(match, style: style))
                            .padding(16)
                            .background(Color.white.opacity(0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    } else {
                        ResultCardPreview(card: ResultCard.from(match))
                    }
                }
                ActionButton("DELEN", style: .filled) { share() }
                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
        .preferredColorScheme(.dark)
    }

    private func share() {
        if let style = choice.textStyle {
            shareText(TeamMatchReport.text(match, style: style))
        } else if let shareImage = ResultImageSharing.share {
            shareImage(ResultCard.from(match))
        }
    }

    private var header: some View {
        ZStack {
            Text("DEEL VERSLAG")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(SharedColors.textPrimary)
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        AppSymbol("xmark", size: 14, color: SharedColors.textSecondary)
                        Text("Sluiten")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sluiten")
                Spacer()
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(choices) { option in
                let active = option == choice
                Button { storedChoice = option.rawValue } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(active ? SharedColors.background : SharedColors.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(active ? SharedColors.gold : SharedColors.gold.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SharedColors.gold.opacity(active ? 0.0 : 0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
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
