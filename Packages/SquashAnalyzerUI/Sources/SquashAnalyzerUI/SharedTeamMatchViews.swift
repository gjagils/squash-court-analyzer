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
    /// Reads the opponent's players from sbn.toernooi.nl (none: type them)
    public let leagueFetcher: LeagueTeamFetcher?

    public init(historyStore: any MatchHistoryStore, playerStore: any PlayerProfileStore,
                coachStore: any CoachMatchStore, refereeStore: any RefereeMatchStore,
                photoStore: (any PlayerPhotoStore)? = nil, filePicker: (any PlayerFilePicker)? = nil,
                aiCoach: AICoachContext? = nil, shareText: ((String) -> Void)? = nil,
                leagueFetcher: LeagueTeamFetcher? = nil) {
        self.historyStore = historyStore
        self.playerStore = playerStore
        self.coachStore = coachStore
        self.refereeStore = refereeStore
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.aiCoach = aiCoach
        self.shareText = shareText
        self.leagueFetcher = leagueFetcher
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
                    SectionHeader(loc("COMPETITIE VANDAAG"))
                    Text(team.title)
                        .font(SharedFonts.system(20, weight: .semibold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Hoort \(player1Name) – \(player2Name) bij deze teamwedstrijd? Kies de partij.", bundle: textBundle)
                        .font(SharedFonts.system(14))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 8) {
                        ForEach(team.partijen, id: \.slot) { partij in
                            Button { slot = partij.slot } label: {
                                HStack(spacing: 12) {
                                    Text(partij.label)
                                        .font(SharedFonts.system(12, weight: .bold, design: .rounded))
                                        .foregroundColor(SharedColors.background)
                                        .frame(width: 30, height: 30)
                                        .background(slot == partij.slot ? SharedColors.accent : SharedColors.textMuted)
                                        .clipShape(Circle())
                                    Text(partij.hasEntry
                                         ? "\(team.ownDisplayName(partij)) – \(team.opponentDisplayName(partij)) · \(partij.standText)"
                                         : loc("nog leeg"))
                                        .font(SharedFonts.system(14))
                                        .foregroundColor(partij.hasEntry ? SharedColors.textPrimary : SharedColors.textMuted)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .background(slot == partij.slot ? SharedColors.accent.opacity(0.14) : SharedColors.tint(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let slot {
                        Text("Wie is onze speler (\(team.ownName))?", bundle: textBundle)
                            .font(SharedFonts.system(14, weight: .semibold))
                            .foregroundColor(SharedColors.textPrimary)
                        HStack(spacing: 10) {
                            ActionButton(player1Name, style: .filled) { onLink(slot, true) }
                            ActionButton(player2Name, style: .filled, color: SharedColors.steelBlueLight) { onLink(slot, false) }
                        }
                    }
                    ActionButton(loc("Nee, gewone wedstrijd"), color: SharedColors.textSecondary, action: onSkip)
                        .padding(.top, 8)
                }
                .padding(24)
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
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
    /// Opened right after creating it shared: its share screen opens too
    @State private var shareOnOpen = false
    @State private var message: String? = nil
    /// The fixture whose SBN result is being fetched ("Ophalen bij SBN")
    @State private var fetchingFixture: String? = nil
    /// 4.0: live team matches of the team and the opponent this phone does not follow yet
    @State private var offers: [TeamLiveListing] = []
    @State private var joiningOffer: String? = nil

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
                    Text("Een teamwedstrijd van de SBN-competitie: vier partijen (E1–E4). Koppel de wedstrijden die je bijhield of vul de game-standen in; de app telt de games, de bonuspunten en de winnaar.", bundle: textBundle)
                        .font(SharedFonts.system(13))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ActionButton(loc("Nieuwe teamwedstrijd"), style: .filled) { creating = true }
                    ActionButton(loc("Deelnemen met link of code")) { joining = true }
                    if !offers.isEmpty {
                        SectionHeader(loc("LOPENDE TEAMWEDSTRIJDEN"))
                        ForEach(offers) { offer in
                            offerRow(offer)
                        }
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if overview.isEmpty {
                        Text("Nog geen teamwedstrijden.", bundle: textBundle)
                            .font(SharedFonts.system(14))
                            .foregroundColor(SharedColors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else {
                        // Today and what comes, a line, then the past from old to recent.
                        // With the whole programme, so every phone shows every match.
                        ForEach(overview.coming) { entry in
                            entryRow(entry)
                        }
                        if !overview.coming.isEmpty && !overview.past.isEmpty {
                            Divider().overlay(SharedColors.line(0.25))
                        }
                        ForEach(overview.past) { entry in
                            entryRow(entry)
                        }
                    }
                    if let message {
                        Text(message).font(SharedFonts.system(12)).foregroundColor(SharedColors.error)
                    }
                }
                .padding(24)
            }
        }
        .pageTitle(loc("Competitie"))
        .task {
            await load()
            await AppUsage.shared.used(AppUsagePart.competition)
            // What teammates put on the live pages since the last look
            if TeamLiveSync.changed(await TeamLiveSync.pull(store: store)) { await load() }
            await loadOffers()
        }
        .sheet(isPresented: $creating) {
            NewTeamMatchSheet(team: team, existing: matches) { match, share in
                creating = false
                Task { await save(match, share: share) }
            } onCancel: { creating = false }
        }
        .sheet(isPresented: $joining) {
            SharedTeamJoinView(store: store, team: team) { joined in
                joining = false
                shareOnOpen = false
                Task {
                    await load()
                    opened = joined
                }
            } onCancel: { joining = false }
        }
        .navigationDestination(isPresented: Binding(get: { opened != nil }, set: { if !$0 { opened = nil } })) {
            if let opened {
                SharedTeamMatchView(match: opened, store: store, tools: tools, team: team, openShare: shareOnOpen) { _ in
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
            message = loc("De teamwedstrijden konden niet worden geladen.")
        }
        isLoading = false
    }

    /// 4.0: what teammates and the opponent made that this phone can join
    private func loadOffers() async {
        guard let context = await PlayerAccount.shared.teamFindingContext() else {
            offers = []
            return
        }
        offers = await TeamFinding.offers(context: context, fixtures: team?.fixtures ?? [], matches: matches)
    }

    /// "Kees heeft … aangemaakt" or "Squash City 2 houdt deze wedstrijd bij", with Meedoen
    private func offerRow(_ offer: TeamLiveListing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(offerTitle(offer))
                .font(SharedFonts.system(14, weight: .semibold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(offerDetail(offer))
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ActionButton(joiningOffer == offer.id ? loc("Even geduld…") : loc("Meedoen"), style: .filled,
                         color: SharedColors.support, disabled: joiningOffer != nil) {
                Task { await join(offer) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.tint(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SharedColors.line(0.10), lineWidth: 1))
    }

    private func offerFixture(_ offer: TeamLiveListing) -> LeagueFixture? {
        guard let team else { return nil }
        for fixture in team.fixtures where TeamFinding.normalizedFixture(fixture.id) == offer.fixture { return fixture }
        return nil
    }

    private func offerTitle(_ offer: TeamLiveListing) -> String {
        if offer.own {
            return loc("\(offer.starterName) heeft een teamwedstrijd aangemaakt")
        }
        return loc("\(offer.teamName) houdt deze wedstrijd bij")
    }

    private func offerDetail(_ offer: TeamLiveListing) -> String {
        let fixture = offerFixture(offer)
        var teams = offer.teamName
        if let fixture { teams = "\(fixture.home) – \(fixture.away)" }
        if offer.own {
            return loc("\(teams). Doe mee en zet je eigen partij erop.")
        }
        guard let fixture else { return loc("\(teams). Kijk mee.") }
        let keepingSide: TeamSide = TeamMatch.sameTeam(fixture.away, offer.teamName) ? TeamSide.away : TeamSide.home
        let slots = TeamLiveCard.labels(TeamFinding.opponentRefereeSlots(keepingSide: keepingSide))
        return loc("\(teams). Kijk mee en zet de partijen erop die jullie fluiten (\(slots)).")
    }

    private func join(_ offer: TeamLiveListing) async {
        joiningOffer = offer.id
        message = nil
        do {
            let joined = try await TeamFinding.join(offer, ownTeamName: team?.name ?? "", fixtures: team?.fixtures ?? [], store: store)
            await load()
            offers = offers.filter { other in other.id != offer.id }
            shareOnOpen = false
            opened = joined
        } catch let error as TeamFindingError {
            switch error {
            case TeamFindingError.gone:
                message = loc("Deze teamwedstrijd is afgelopen of de link klopt niet.")
                offers = offers.filter { other in other.id != offer.id }
            case TeamFindingError.sharedElsewhere:
                message = loc("Je hebt deze teamwedstrijd al, maar gekoppeld aan een andere livepagina. Stop die eerst of gebruik die.")
            default:
                message = loc("Deelnemen is niet gelukt.")
            }
        } catch {
            message = loc("Deelnemen is niet gelukt.")
        }
        joiningOffer = nil
    }

    private var overview: CompetitionOverview {
        CompetitionOverview.make(matches: matches, fixtures: team?.fixtures ?? [])
    }

    @ViewBuilder
    private func entryRow(_ entry: CompetitionEntry) -> some View {
        if let match = entry.match {
            TeamMatchCard(match: match) { shareOnOpen = false; opened = match }
        } else if let fixture = entry.fixture {
            if fixture.score != nil {
                playedRow(fixture)
            } else {
                openRow(fixture)
            }
        }
    }

    /// A match of the programme without a result and without a team match
    /// here: a coming one starts through Nieuwe teamwedstrijd (with its share
    /// choice), a past one has no result at SBN
    private func openRow(_ fixture: LeagueFixture) -> some View {
        let own = team?.name ?? ""
        let coming = fixture.date >= Date() || Calendar.current.isDate(fixture.date, inSameDayAs: Date())
        return Button { if coming { creating = true } } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TeamMatchReport.dayText(fixture.date))
                        .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textSecondary)
                    fixtureTeam(fixture.home, own: TeamMatch.sameTeam(fixture.home, own))
                    fixtureTeam(fixture.away, own: TeamMatch.sameTeam(fixture.away, own))
                }
                Spacer(minLength: 0)
                if coming {
                    AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                } else {
                    Text("Geen uitslag", bundle: textBundle)
                        .font(SharedFonts.system(11))
                        .foregroundColor(SharedColors.textMuted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.tint(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SharedColors.line(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!coming)
    }

    private func fixtureTeam(_ name: String, own: Bool) -> some View {
        Text(name)
            .font(SharedFonts.system(14, weight: own ? .bold : .regular, design: .rounded))
            .foregroundColor(own ? SharedColors.accent : SharedColors.textPrimary)
            .lineLimit(1)
    }

    /// Date, the two teams with the SBN score, and "Ophalen bij SBN" (played,
    /// result at SBN, not in the app: one tap brings it in, 1 November 2026)
    private func playedRow(_ fixture: LeagueFixture) -> some View {
        let own = team?.name ?? ""
        let atHome = TeamMatch.sameTeam(fixture.home, own)
        return VStack(alignment: .leading, spacing: 8) {
            Text(TeamMatchReport.dayText(fixture.date))
                .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 8) {
                Text(fixture.home)
                    .font(SharedFonts.system(14, weight: atHome ? .bold : .regular, design: .rounded))
                    .foregroundColor(atHome ? SharedColors.accent : SharedColors.textPrimary)
                    .lineLimit(1)
                Text(fixture.score ?? "")
                    .font(SharedFonts.system(14, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                Text(fixture.away)
                    .font(SharedFonts.system(14, weight: atHome ? .regular : .bold, design: .rounded))
                    .foregroundColor(atHome ? SharedColors.textPrimary : SharedColors.accent)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            if tools.leagueFetcher != nil {
                ActionButton(fetchingFixture == fixture.id ? loc("Even geduld…") : loc("Ophalen bij SBN"), icon: "arrow.down.circle",
                             color: SharedColors.support, disabled: fetchingFixture != nil) {
                    Task { await importFromSBN(fixture) }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.tint(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SharedColors.line(0.10), lineWidth: 1))
    }

    /// Reads the SBN team-match page and keeps the match with the result in it
    private func importFromSBN(_ fixture: LeagueFixture) async {
        guard let fetcher = tools.leagueFetcher, let team else { return }
        fetchingFixture = fixture.id
        message = nil
        do {
            let result = try await fetcher.fetchTeamMatch(fixture.url)
            guard result.hasResult else {
                message = loc("SBN heeft nog geen uitslag van deze wedstrijd.")
                fetchingFixture = nil
                return
            }
            let match = TeamMatch.from(fixture: fixture, ownTeam: team.name, sbn: result)
            try await store.save(match)
            await load()
        } catch let error as LeagueTeamError {
            message = error.message
        } catch {
            message = LeagueTeamError.unavailable.message
        }
        fetchingFixture = nil
    }

    /// A new team match: kept, shared with the team when asked (a failure leaves it
    /// as an own team match; its screen says so), then opened
    private func save(_ match: TeamMatch, share: Bool) async {
        do {
            var created = match
            try await store.save(created)
            if share {
                // 4.0: a match from the programme becomes visible for the team (and the opponent), not public
                if let context = await PlayerAccount.shared.teamFindingContext(), TeamFinding.canShare(created, context: context) {
                    if let found = try? await TeamFinding.makeVisible(created, context: context, store: store) {
                        created = found.match
                        switch found.outcome {
                        case TeamFindingOutcome.joined(let starter):
                            message = loc("\(starter) had deze teamwedstrijd al aangemaakt: je doet mee met die.")
                        case TeamFindingOutcome.started:
                            break
                        }
                    }
                    await load()
                    shareOnOpen = false
                    opened = created
                    return
                }
                if let live = try? await TeamMatchSupport.goLive(created, store: store) { created = live }
            }
            await load()
            shareOnOpen = share
            opened = created
        } catch {
            message = loc("Opslaan is niet gelukt.")
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
                        .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textSecondary)
                    TeamShareBadge(isLive: match.isLive)
                    Spacer()
                    if score.isComplete, let winner = match.winnerName {
                        HStack(spacing: 4) {
                            AppSymbol("crown.fill", size: 10, color: SharedColors.gold)
                            Text(winner)
                                .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.gold)
                                .lineLimit(1)
                        }
                    } else {
                        Text(score.partijenPlayed == 0 ? loc("NOG NIET BEGONNEN") : loc("BEZIG"))
                            .font(SharedFonts.system(9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(SharedColors.textMuted)
                    }
                }
                HStack(alignment: .center, spacing: 12) {
                    teamSide(match.home, own: match.ownSide == TeamSide.home)
                    Text(match.gamesText)
                        .font(SharedFonts.system(28, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                        .lineLimit(1)
                    teamSide(match.away, own: match.ownSide == TeamSide.away)
                }
                Text("\(match.homePartijen)-\(match.awayPartijen) in partijen · \(match.homeCompetitionPoints)-\(match.awayCompetitionPoints) competitiepunten", bundle: textBundle)
                    .font(SharedFonts.system(11))
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
            .font(SharedFonts.system(14, weight: own ? .bold : .regular, design: .rounded))
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
    /// The share screen ("Deel met team en supporters")
    @State private var sharingTeam = false
    /// Open the share screen once this screen is up (right after "Deel met mijn team" at creating)
    private let openShare: Bool
    @State private var liveBusy = false
    @State private var confirmStopLive = false
    /// 4.0, owner of a team-only live team match: the partijen the opponent referees now
    @State private var refereeSlotsNow: [Int]? = nil
    /// "Uitslag van SBN ophalen": busy, and what it did (not an error)
    @State private var sbnBusy = false
    @State private var sbnMessage: String? = nil
    /// A tracked match being played for a partij (full screen)
    @State private var tracking: TeamTrackRequest? = nil
    /// Asked for in the editor; opens as soon as the editor sheet is gone
    @State private var pendingTrack: TeamTrackRequest? = nil
    @State private var players: [PlayerProfile] = []
    /// The opponent's players from SBN, for a team match from the programme
    @State private var opponentRoster: [String] = []
    /// Scouting (3.2): the profile of an opponent who is a saved player
    @State private var scouting: PlayerProfile? = nil
    @AppStorage(TeamRoster.storageKey) private var rosterRaw = ""
    @Environment(\.dismiss) private var dismiss

    public init(match: TeamMatch, store: any TeamMatchStore, tools: TeamMatchTools,
                team: LeagueTeamSnapshot? = nil, openShare: Bool = false, onChange: @escaping (TeamMatch?) -> Void) {
        _match = State(initialValue: match)
        self.openShare = openShare
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
                    TeamShareBanner(match: match)
                    partijenList
                    opponentScouting
                    if sbnFixture != nil && (!match.isComplete || match.hasUnknownPoints) {
                        // The back-up for a live page that is gone, and for partijen nobody tracked
                        ActionButton(sbnBusy ? loc("Even geduld…") : loc("Uitslag van SBN ophalen"), icon: "arrow.down.circle",
                                     color: SharedColors.support, disabled: sbnBusy) {
                            Task { await fetchFromSBN(announce: true) }
                        }
                    }
                    if let sbnMessage {
                        Text(sbnMessage).font(SharedFonts.system(12)).foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    TeamLiveCard(match: match, busy: liveBusy, canShare: tools.shareText != nil,
                                 problem: liveProblem,
                                 refereeSlots: refereeSlotsNow,
                                 onGoPublic: { Task { await goPublic() } },
                                 onToggleReferee: { slot in Task { await toggleReferee(slot) } },
                                 onGoLive: { Task { await goLive() } },
                                 onShare: { sharingTeam = true },
                                 onRefresh: { Task { await refreshLive() } },
                                 onStop: { confirmStopLive = true })
                    if let message {
                        Text(message).font(SharedFonts.system(12)).foregroundColor(SharedColors.error)
                    }
                    if tools.shareText != nil {
                        ActionButton(loc("Deel verslag"), icon: "square.and.arrow.up", style: .filled) { sharing = true }
                    }
                    ActionButton(loc("Verwijder teamwedstrijd"), color: SharedColors.textSecondary) { confirmDelete = true }
                }
                .padding(24)
            }
        }
        .pageTitle(loc("Teamwedstrijd"))
        .task {
            players = (try? await tools.playerStore.loadPlayers()) ?? []
            if let fetcher = tools.leagueFetcher, let link = LeagueOpponent.link(for: match, in: team) {
                opponentRoster = await LeagueOpponentStorage.names(for: link, fetcher: fetcher)
            }
            await syncFromLive(showGone: false)
            if match.isTeamOnly && match.isLiveOwner {
                refereeSlotsNow = await TeamFinding.currentRefereeSlots(match)
            }
            await autoLinkHistory()
            // A played match that is still not complete: SBN may have the rest
            if match.date < Date() && (!match.isComplete || match.hasUnknownPoints) && !match.isLive {
                await fetchFromSBN(announce: false)
            }
            if openShare {
                if match.isLive {
                    sharingTeam = true
                } else {
                    message = loc("Delen lukte niet. Controleer de internetverbinding en tik op Deel met mijn team om het opnieuw te proberen.")
                }
            }
        }
        .alert(match.isLiveOwner ? loc("Live stoppen?") : loc("Live verlaten?"), isPresented: $confirmStopLive) {
            Button(match.isLiveOwner ? loc("Stop live") : loc("Verlaat live"), role: .destructive) { Task { await stopLive() } }
            Button(loc("Annuleren"), role: .cancel) { }
        } message: {
            Text(match.isLiveOwner
                 ? loc("De livepagina is meteen weg voor iedereen. Je teamwedstrijd blijft in de app staan.")
                 : loc("Je partijen komen niet meer op de livepagina van je teamgenoot. De pagina blijft bestaan voor de rest; je teamwedstrijd blijft in de app staan."))
        }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }), onDismiss: {
            // The full screen may only open once the sheet is really gone
            if let request = pendingTrack {
                pendingTrack = nil
                tracking = request
            }
        }) {
            if let editing {
                TeamPartijEditor(partij: editing, match: match, roster: rosterNames, opponentRoster: opponentRoster, historyStore: tools.historyStore) { updated in
                    var changed = match
                    changed.update(updated)
                    self.editing = nil
                    Task { await save(changed) }
                } onTrack: { updated, kind in
                    startTracking(updated, kind: kind)
                } onCancel: { self.editing = nil }
            }
        }
        .sheet(isPresented: $sharingTeam) {
            TeamShareSheet(match: match, baseURL: TeamLive.shared.baseURL, shareText: tools.shareText) { sharingTeam = false }
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
        .alert(loc("Teamwedstrijd verwijderen?"), isPresented: $confirmDelete) {
            Button(loc("Verwijder"), role: .destructive) { Task { await remove() } }
            Button(loc("Annuleren"), role: .cancel) { }
        } message: {
            Text("De gekoppelde coach- en scheidsrechterwedstrijden blijven in Afgeronde wedstrijden staan.", bundle: textBundle)
        }
    }

    /// Why this phone's partijen may not reach the live page, for the card
    private var liveProblem: String? {
        guard let id = match.liveId else { return nil }
        if TeamLive.shared.isRejected(id) {
            return loc("De livepagina wil je partij niet hebben: de uitnodigingscode klopt niet (meer). Vraag je teamgenoot de uitnodiging opnieuw te sturen en doe weer mee.")
        }
        if TeamLive.shared.offline {
            return loc("Geen verbinding: je partij staat nog niet op de livepagina. Tik op Vernieuwen zodra je weer internet hebt.")
        }
        return nil
    }

    /// The SBN fixture of this team match, when it came from the programme and SBN can be read
    private var sbnFixture: LeagueFixture? {
        guard tools.leagueFetcher != nil, let team, let id = match.fixtureId else { return nil }
        return team.fixtures.first { fixture in fixture.id == id }
    }

    /// Finished matches of this evening (tracked here, or shared to this phone)
    /// with the players of an empty partij are linked by themselves
    private func autoLinkHistory() async {
        guard let history = try? await tools.historyStore.loadHistory() else { return }
        var changed = match
        let linked = TeamMatchSupport.autoLink(&changed, history: history)
        guard !linked.isEmpty else { return }
        try? await store.save(changed)
        match = changed
        onChange(changed)
    }

    /// Reads the SBN team-match page into this match; `announce` says what it
    /// did even when nothing changed (the button), the automatic run only when it did
    private func fetchFromSBN(announce: Bool) async {
        guard let fetcher = tools.leagueFetcher, let fixture = sbnFixture else { return }
        sbnBusy = true
        do {
            let result = try await fetcher.fetchTeamMatch(fixture.url)
            var changed = match
            let outcome = changed.fill(fromSBN: result)
            if outcome.changedAnything {
                try await store.save(changed)
                match = changed
                onChange(changed)
            }
            var lines: [String] = []
            if !outcome.filled.isEmpty {
                lines.append(loc("Van SBN overgenomen: \(LeagueFillOutcome.labels(outcome.filled))."))
            }
            if !outcome.completed.isEmpty {
                lines.append(loc("Gamestanden aangevuld: \(LeagueFillOutcome.labels(outcome.completed))."))
            }
            if !outcome.differences.isEmpty {
                lines.append(loc("Anders dan op deze telefoon (niet gewijzigd): ") + outcome.differences.joined(separator: "; "))
            }
            if lines.isEmpty && announce {
                lines.append(result.hasResult ? loc("Alles stond er al.") : loc("SBN heeft nog geen uitslag van deze wedstrijd."))
            }
            if !lines.isEmpty { sbnMessage = lines.joined(separator: " ") }
        } catch let error as LeagueTeamError {
            if announce { sbnMessage = error.message }
        } catch {
            if announce { sbnMessage = LeagueTeamError.unavailable.message }
        }
        sbnBusy = false
    }

    /// "Vernieuwen": send our partijen again (what failed earlier), then read what teammates put there
    private func refreshLive() async {
        liveBusy = true
        await TeamLive.shared.pushAll(match)
        liveBusy = false
        await syncFromLive(showGone: true)
    }

    /// Our players to pick from: "In mijn team" first, then Mijn team
    /// Opponents (SBN roster and the partijen) who are saved players, for scouting
    private var scoutablePlayers: [PlayerProfile] {
        var names: [String] = []
        for name in opponentRoster { names.append(name.trimmingCharacters(in: .whitespaces).lowercased()) }
        for partij in match.partijen {
            let name = partij.opponentPlayer.trimmingCharacters(in: .whitespaces).lowercased()
            if !name.isEmpty { names.append(name) }
        }
        var result: [PlayerProfile] = []
        for player in players where names.contains(player.name.trimmingCharacters(in: .whitespaces).lowercased()) {
            result.append(player)
        }
        return result
    }

    /// "Tegenstanders": open the profile of an opponent you have matches of (3.2, scouting)
    @ViewBuilder
    private var opponentScouting: some View {
        let opponents = scoutablePlayers
        if !opponents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(loc("TEGENSTANDERS"))
                ForEach(opponents) { player in
                    Button { scouting = player } label: {
                        HStack(spacing: 10) {
                            Text(player.name)
                                .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.textPrimary)
                            Spacer()
                            Text("Profiel bekijken", bundle: textBundle)
                                .font(SharedFonts.system(12, weight: .semibold, design: .rounded))
                                .foregroundColor(SharedColors.steelBlueLight)
                            AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                        }
                        .padding(12)
                        .background(SharedColors.tint(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(item: $scouting) { player in
                NavigationStack {
                    SharedPlayerTrendView(playerId: player.id, playerName: player.name, historyStore: tools.historyStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                CloseButton { scouting = nil }
                            }
                        }
                }
            }
        }
    }

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
                               teamMatchStore: store, teamTarget: target, historyStore: tools.historyStore,
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
            Text("\(TeamMatchReport.dayText(match.date)) · \(match.ownSide == TeamSide.home ? loc("thuis") : loc("uit"))")
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 4) {
                    Text(match.home)
                        .font(SharedFonts.system(15, weight: match.ownSide == TeamSide.home ? .bold : .regular, design: .rounded))
                        .foregroundColor(match.ownSide == TeamSide.home ? SharedColors.accent : SharedColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(match.homeGames)")
                        .font(SharedFonts.system(44, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                Text("–").font(SharedFonts.system(32, weight: .bold, design: .rounded)).foregroundColor(SharedColors.textMuted)
                VStack(spacing: 4) {
                    Text(match.away)
                        .font(SharedFonts.system(15, weight: match.ownSide == TeamSide.away ? .bold : .regular, design: .rounded))
                        .foregroundColor(match.ownSide == TeamSide.away ? SharedColors.accent : SharedColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(match.awayGames)")
                        .font(SharedFonts.system(44, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            Text("games", bundle: textBundle).font(SharedFonts.system(10)).tracking(1.2).foregroundColor(SharedColors.textMuted).frame(maxWidth: .infinity)
            Divider().overlay(SharedColors.line(0.15))
            HStack {
                statCell(loc("PARTIJEN"), "\(match.homePartijen)-\(match.awayPartijen)")
                statCell(loc("COMPETITIEPUNTEN"), "\(match.homeCompetitionPoints)-\(match.awayCompetitionPoints)")
                statCell(loc("RALLYPUNTEN"), score.pointsKnown
                         ? (match.ownSide == TeamSide.home ? "\(score.ownPoints)-\(score.theirPoints)" : "\(score.theirPoints)-\(score.ownPoints)")
                         : "–")
            }
            Text(match.statusText)
                .font(SharedFonts.system(13, weight: .semibold))
                .foregroundColor(score.isComplete ? SharedColors.gold : SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if score.isComplete {
                Text("Winnaar: meeste partijen; gelijk → het volledige team; dan meeste games, meeste rallypunten, winnaar E1. Competitiepunten: games + 3 bonus voor de winnaar.", bundle: textBundle)
                    .font(SharedFonts.system(11))
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
                .font(SharedFonts.system(18, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.accent)
            Text(title).font(SharedFonts.system(9)).tracking(1.0).foregroundColor(SharedColors.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private var partijenList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(loc("PARTIJEN"))
            VStack(spacing: 0) {
                ForEach(match.partijen, id: \.slot) { partij in
                    partijRow(partij)
                    if partij.slot < 4 { Divider().overlay(SharedColors.line(0.09)) }
                }
            }
            .background(SharedColors.tint(0.04)).clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Tik op een partij om spelers en games in te vullen of een bijgehouden wedstrijd te koppelen.", bundle: textBundle)
                .font(SharedFonts.system(11))
                .foregroundColor(SharedColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func partijRow(_ partij: TeamPartij) -> some View {
        Button { editing = partij } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(partij.label)
                    .font(SharedFonts.system(12, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.background)
                    .frame(width: 30, height: 30)
                    .background(partij.hasEntry ? SharedColors.accent : SharedColors.textMuted)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(match.ownDisplayName(partij))
                            .font(SharedFonts.system(14, weight: .semibold))
                            .foregroundColor(partij.ownPlayer.isEmpty ? SharedColors.textMuted : SharedColors.accent)
                            .lineLimit(1)
                        Text("–").foregroundColor(SharedColors.textMuted)
                        Text(match.opponentDisplayName(partij))
                            .font(SharedFonts.system(14, weight: .semibold))
                            .foregroundColor(partij.opponentPlayer.isEmpty ? SharedColors.textMuted : SharedColors.steelBlueLight)
                            .lineLimit(1)
                    }
                    if partij.hasEntry {
                        HStack(spacing: 6) {
                            Text(partij.standText)
                                .font(SharedFonts.system(13, weight: .bold, design: .rounded))
                                .foregroundColor(partij.ownWon == true ? SharedColors.accent : (partij.ownWon == false ? SharedColors.steelBlueLight : SharedColors.textPrimary))
                            Text(partij.gamesText)
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.textSecondary)
                                .lineLimit(1)
                            if partij.isLinked {
                                AppSymbol("arrow.right", size: 10, color: SharedColors.textMuted)
                            }
                        }
                    } else {
                        Text("Nog niet ingevuld", bundle: textBundle)
                            .font(SharedFonts.system(12))
                            .foregroundColor(SharedColors.textMuted)
                    }
                    if let order = partij.playOrder {
                        Text("Gespeeld als \(teamPlayOrderText(order))", bundle: textBundle)
                            .font(SharedFonts.system(10))
                            .foregroundColor(SharedColors.textMuted)
                    }
                }
                Spacer()
                AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
            }
            .padding(12)
            // Apple only: a no-op in SkipUI, and Compose's clickable already covers the row (docs/bewuste-keuzes.md)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc("Partij \(partij.label)"))
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
            message = loc("Opslaan is niet gelukt.")
        }
    }

    /// "Deel met mijn team": make the live page, put what is filled in on it, open the share screen
    private func goLive() async {
        liveBusy = true
        defer { liveBusy = false }
        do {
            let changed = try await TeamMatchSupport.goLive(match, store: store)
            match = changed
            onChange(changed)
            message = nil
            sharingTeam = true
        } catch {
            message = loc("Delen lukte niet. Controleer de internetverbinding en probeer het opnieuw.")
        }
    }

    private func stopLive() async {
        liveBusy = true
        // Only the phone that started it ends the page for everyone; a phone
        // that joined just leaves it
        if match.isLiveOwner {
            await TeamLive.shared.stop(match)
            // 4.0: teammates and the opponent no longer find it
            if let context = await PlayerAccount.shared.teamFindingContext() { await TeamFinding.forget(match, context: context) }
        }
        liveBusy = false
        await clearLive()
    }

    /// 4.0: Live delen on a team-only live team match: on the club screen, with the viewers' link
    private func goPublic() async {
        liveBusy = true
        let done = await TeamLive.shared.setClubScreen(match, on: true)
        liveBusy = false
        guard done else {
            message = loc("Delen lukte niet. Controleer de internetverbinding en probeer het opnieuw.")
            return
        }
        var changed = match
        changed.liveTeamOnly = nil
        try? await store.save(changed)
        match = changed
        onChange(changed)
        message = nil
        sharingTeam = true
    }

    /// 4.0, owner: a partij moves between "wij fluiten" and "tegenstander fluit"
    private func toggleReferee(_ slot: Int) async {
        var slots = refereeSlotsNow ?? []
        if slots.contains(slot) {
            slots = slots.filter { other in other != slot }
        } else {
            slots.append(slot)
        }
        slots.sort()
        liveBusy = true
        let done = await TeamLive.shared.setRefereeSlots(match, slots: slots)
        liveBusy = false
        if done {
            refereeSlotsNow = slots
            message = nil
        } else {
            message = loc("Geen verbinding om de livepagina te lezen.")
        }
    }

    /// The live page is over (stopped, or gone a day after the last update)
    private func clearLive() async {
        var changed = match
        changed.clearLiveState()
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
                // The server answered that the page is gone (two hours after the
                // last update, or stopped): the live state ends here, also on
                // opening the screen, so the LIVE marker on the home screen
                // follows the server (Gerd-Jan, 1 November 2026)
                await clearLive()
                var missing: [String] = []
                for partij in match.partijen where !partij.hasEntry { missing.append(partij.label) }
                if missing.isEmpty {
                    message = loc("De livepagina is afgelopen (een dag na de laatste update) en wordt niet meer bijgewerkt.")
                } else {
                    message = loc("De livepagina is afgelopen (een dag na de laatste update). Niet binnengekomen: \(missing.joined(separator: ", ")). Haal de uitslag op bij SBN of vul ze in.")
                }
            } else if showGone {
                message = loc("Geen verbinding om de livepagina te lezen.")
            }
        } catch {
        }
    }

    private func remove() async {
        // 4.0: a team-only live team match nobody else started goes with it
        if match.isTeamOnly && match.isLiveOwner {
            await TeamLive.shared.stop(match)
            if let context = await PlayerAccount.shared.teamFindingContext() { await TeamFinding.forget(match, context: context) }
        }
        do {
            try await store.delete(id: match.id)
            onChange(nil)
            dismiss()
        } catch {
            message = loc("Verwijderen is niet gelukt.")
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
