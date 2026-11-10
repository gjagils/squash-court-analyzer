import SwiftUI
import SquashAnalyzerCore

// "Mijn team" on Android: the card on the home screen, the team screen, and
// the settings screen where the team link is entered. iOS has its own
// `LeagueTeamCard` / `LeagueTeamDetailView` (named `Shared...` here so the two
// never collide); both use Core's `LeagueTeamFetcher` and the same storage keys.


enum LeagueDates {
    static func day(_ date: Date) -> String {
        format(date, "EEE d MMM")
    }

    static func time(_ date: Date) -> String {
        format(date, "HH:mm")
    }

    /// "6", for the date block on the home card
    static func dayNumber(_ date: Date) -> String {
        format(date, "d")
    }

    /// "NOV": the month in capitals without the Dutch full stop ("nov.")
    static func monthShort(_ date: Date) -> String {
        format(date, "MMM").replacingOccurrences(of: ".", with: "").uppercased()
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

/// A team name in the programme: the followed team light and bold, the other
/// team muted, so you see at a glance which side is yours
struct LeagueTeamName: View {
    let name: String
    let own: String

    var body: some View {
        let isOwn = TeamMatch.sameTeam(name, own)
        Text(name)
            .fontWeight(isOwn ? .semibold : .regular)
            .foregroundColor(isOwn ? SharedColors.textPrimary : SharedColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The opponent of a coming match in one line: "Nr. 2 · vorige keer 7-13
/// verloren" (backlog T5); "" when there is nothing to say (a cup match, the
/// first meeting with a team outside the poule)
enum LeagueOpponentText {
    static func line(_ info: LeagueOpponentInfo?) -> String {
        guard let info else { return "" }
        var parts: [String] = []
        if let standing = info.standing {
            parts.append(loc("Nr. \(standing.rank)"))
        }
        if let previous = info.previous {
            if previous.won {
                parts.append(loc("vorige keer \(previous.ownGames)-\(previous.theirGames) gewonnen"))
            } else if previous.lost {
                parts.append(loc("vorige keer \(previous.ownGames)-\(previous.theirGames) verloren"))
            } else {
                parts.append(loc("vorige keer \(previous.ownGames)-\(previous.theirGames) gelijk"))
            }
        }
        return parts.joined(separator: " · ")
    }

    /// "Vorige keer 7-8 verloren" as a line of its own (the home card shows the
    /// opponent's stand in a badge); "" without an earlier result
    static func previousLine(_ info: LeagueOpponentInfo?) -> String {
        guard let previous = info?.previous else { return "" }
        if previous.won {
            return loc("Vorige keer \(previous.ownGames)-\(previous.theirGames) gewonnen")
        } else if previous.lost {
            return loc("Vorige keer \(previous.ownGames)-\(previous.theirGames) verloren")
        }
        return loc("Vorige keer \(previous.ownGames)-\(previous.theirGames) gelijk")
    }
}

/// "8e" in Dutch, "8th" in English; "–" without a stand
enum LeagueOrdinal {
    static func text(_ rank: Int?) -> String {
        guard let rank else { return "–" }
        if textLanguage == "nl" { return "\(rank)e" }
        let tens = rank % 100
        let suffix: String
        if tens >= 11 && tens <= 13 {
            suffix = "th"
        } else {
            switch rank % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(rank)\(suffix)"
    }
}

/// The stand as a 52-point badge: "8e" with STAND under it; filled for the
/// own team, outlined for the opponent (home card, 1 November 2026)
struct LeagueRankBadge: View {
    let rank: Int?
    let filled: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(LeagueOrdinal.text(rank))
                .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.accent)
            Text("STAND", bundle: textBundle)
                .font(SharedFonts.system(10)).tracking(1)
                .foregroundColor(SharedColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 52, height: 52)
        .background(filled ? SharedColors.accent.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SharedColors.accent.opacity(filled ? 0.0 : 0.35), lineWidth: 1))
    }
}

/// The day of the next match as a block the size of the badge: "6" over "NOV"
struct LeagueDateBlock: View {
    let date: Date
    let fill: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(LeagueDates.dayNumber(date))
                .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
            Text(LeagueDates.monthShort(date))
                .font(SharedFonts.system(10, weight: .semibold)).tracking(1)
                .foregroundColor(SharedColors.accent)
        }
        .frame(width: 52, height: 52)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// The home-screen card: stand, played and points, and the next match. Shows
/// nothing until a team link is saved in Instellingen; keeps showing the last
/// fetched team when SBN cannot be reached.
public struct SharedLeagueTeamCard: View {
    let fetcher: LeagueTeamFetcher
    let onOpen: (LeagueTeamSnapshot) -> Void
    /// Called with the saved or freshly fetched team (the app loads its players into Spelers)
    let onTeam: ((LeagueTeamSnapshot) -> Void)?
    /// Opens Instellingen, for the prompt shown while no team link is saved; nil hides that button
    let onSetup: (() -> Void)?
    /// Where today's team match comes from (nil: the card only shows the team)
    let teamMatches: (any TeamMatchStore)?
    /// A screen that changes team matches is open: wait, and read again after it closes
    let matchesPaused: Bool
    let onTeamMatch: (TeamMatch) -> Void

    @AppStorage(LeagueTeamStorage.linkKey) private var teamURL = ""
    @State private var activeMatch: TeamMatch? = nil
    /// Goes up when a team match is joined with a link: read again at once
    @AppStorage(TeamMatchSupport.revisionKey) private var matchesRevision = 0
    /// The prompt was closed with the cross: it stays away (Instellingen still has the field)
    @AppStorage("teamPromptDismissed") private var promptDismissed = false
    @State private var snapshot: LeagueTeamSnapshot?
    @State private var errorMessage: String?
    @State private var loading = false
    /// 4.0: a live team match of a teammate or the opponent, for today or tomorrow
    @State private var offer: TeamLiveListing? = nil
    @State private var joiningOffer = false

    public init(fetcher: LeagueTeamFetcher, onTeam: ((LeagueTeamSnapshot) -> Void)? = nil,
                onSetup: (() -> Void)? = nil,
                teamMatches: (any TeamMatchStore)? = nil, matchesPaused: Bool = false,
                onTeamMatch: @escaping (TeamMatch) -> Void = { _ in },
                onOpen: @escaping (LeagueTeamSnapshot) -> Void) {
        self.fetcher = fetcher
        self.onTeam = onTeam
        self.onSetup = onSetup
        self.teamMatches = teamMatches
        self.matchesPaused = matchesPaused
        self.onTeamMatch = onTeamMatch
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let snapshot {
                HomeTeamSummary(snapshot: snapshot, match: activeMatch, offer: homeOffer(snapshot),
                                onOpen: { onOpen(snapshot) }, onMatch: onTeamMatch)
            } else if let activeMatch {
                // Joined with a link, without Mijn team: the match still gets its place
                HomeTeamMatchBar(match: activeMatch) { onTeamMatch(activeMatch) }
                    .background(SharedColors.brandCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.brandCardStroke, lineWidth: 1))
            } else if !teamURL.isEmpty {
                HStack(spacing: 10) {
                    if loading {
                        ProgressView()
                    }
                    Text(loading ? loc("Mijn team laden…") : (errorMessage ?? loc("Team laden niet gelukt")))
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textSecondary)
                    Spacer()
                    if !loading {
                        Button(loc("Opnieuw")) { Task { await load() } }
                            .foregroundColor(SharedColors.accent)
                    }
                }
                .padding(16)
                .background(SharedColors.surfaceRaised).clipShape(RoundedRectangle(cornerRadius: 14))
            } else if !promptDismissed {
                setupPrompt
            }
        }
        .padding(.horizontal, 24)
        .task(id: teamURL) { await load() }
        .task(id: "\(matchesPaused)-\(matchesRevision)") { await followActiveMatch() }
        .task(id: "\(snapshot?.source.absoluteString ?? "")-\(matchesPaused)-\(matchesRevision)") { await followOffers() }
    }

    /// Looks for a team match to join every five minutes, only with an account
    /// and only around a match of the programme (TeamFinding.offers asks the
    /// server for today and tomorrow, so most of the week it asks nothing)
    private func followOffers() async {
        guard let store = teamMatches, !matchesPaused, let team = snapshot else { return }
        let soon = team.fixtures.contains { fixture in abs(fixture.date.timeIntervalSinceNow) < 36.0 * 3600.0 }
        guard soon else {
            offer = nil
            return
        }
        while !Task.isCancelled {
            if let context = await PlayerAccount.shared.teamFindingContext() {
                let matches = (try? await store.loadAll()) ?? []
                let found = await TeamFinding.offers(context: context, fixtures: team.fixtures, matches: matches)
                if offer != found.first { offer = found.first }
            } else if offer != nil {
                offer = nil
            }
            try? await Task.sleep(nanoseconds: 300_000_000_000)
        }
    }

    private func homeOffer(_ team: LeagueTeamSnapshot) -> HomeTeamOffer? {
        guard let offer, activeMatch == nil else { return nil }
        let title = offer.own ? loc("\(offer.starterName) heeft een teamwedstrijd aangemaakt")
            : loc("\(offer.teamName) houdt deze wedstrijd bij")
        var detail = offer.teamName
        for fixture in team.fixtures where TeamFinding.normalizedFixture(fixture.id) == offer.fixture {
            let ownIsHome = TeamMatch.sameTeam(fixture.home, team.name)
            detail = "\(ownIsHome ? loc("Thuis") : loc("Uit")) · \(ownIsHome ? fixture.away : fixture.home)"
        }
        return HomeTeamOffer(title: title, detail: detail, joining: joiningOffer) {
            Task { await join(offer, team: team) }
        }
    }

    private func join(_ listing: TeamLiveListing, team: LeagueTeamSnapshot) async {
        guard let store = teamMatches, !joiningOffer else { return }
        joiningOffer = true
        do {
            let joined = try await TeamFinding.join(listing, ownTeamName: team.name, fixtures: team.fixtures, store: store)
            offer = nil
            joiningOffer = false
            TeamMatchSupport.noteChange()
            onTeamMatch(joined)
        } catch {
            // Gone or not possible: Competitie explains it; the card just drops the offer
            offer = nil
            joiningOffer = false
        }
    }

    /// Keeps the bar current while the home screen is in front: the saved
    /// match each minute, and what teammates put on its live page. Stops while
    /// a team match screen is open, so it never saves over a change made there.
    private func followActiveMatch() async {
        guard let store = teamMatches, !matchesPaused else { return }
        while !Task.isCancelled {
            var current = TeamMatchSupport.homeMatch(in: (try? await store.loadAll()) ?? [])
            if current?.isLive == true, TeamLiveSync.changed(await TeamLiveSync.pull(store: store)) {
                current = TeamMatchSupport.homeMatch(in: (try? await store.loadAll()) ?? [])
            }
            if activeMatch != current { activeMatch = current }
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
    }

    /// Shown while no team link is saved: what Mijn team gives, and where to start
    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("Speel je competitie bij SBN?", bundle: textBundle)
                    .font(SharedFonts.system(16, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                Spacer()
                Button { promptDismissed = true } label: {
                    Text("Sluiten", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textMuted)
                }
                .accessibilityLabel(loc("Sluiten"))
            }
            Text("Zoek je club en kies je team: je ziet de stand en het programma, en je teamleden komen vanzelf bij Spelers.", bundle: textBundle)
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let onSetup {
                Button { onSetup() } label: {
                    Text("Zoek je club", bundle: textBundle)
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.surfaceRaised).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        guard let link = try? LeagueTeamLink(teamURL) else {
            snapshot = nil
            return
        }
        // The saved team (also after "Vernieuwen" in the team screen); another link starts empty
        if let cached = LeagueTeamStorage.cachedSnapshot(for: link) {
            snapshot = cached
            onTeam?(cached)
        } else if snapshot?.source != link.url {
            snapshot = nil
        }
        // The saved team as long as nothing can have changed (LeagueTeamRefresh)
        guard LeagueTeamRefresh.isDue(snapshot, lastAttempt: LeagueTeamStorage.lastAttempt()) else { return }
        LeagueTeamStorage.noteAttempt()
        loading = true
        errorMessage = nil
        do {
            let result = try await fetcher.fetch(link)
            LeagueTeamStorage.store(result)
            snapshot = result
            onTeam?(result)
        } catch {
            errorMessage = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message
        }
        loading = false
    }
}

/// The whole team: standings, matches and players
public struct SharedLeagueTeamDetailView: View {
    @State private var snapshot: LeagueTeamSnapshot
    /// "Vernieuwen" fetches the team now, whatever LeagueTeamRefresh says
    private let fetcher: LeagueTeamFetcher?
    @State private var refreshing = false
    @State private var refreshError: String?
    /// The team matches on this phone: a match of the programme shows its
    /// stand and LIVE, and a tap opens it or makes one (7 November 2026)
    private let teamMatches: (any TeamMatchStore)?
    private let tools: TeamMatchTools?
    @State private var matches: [TeamMatch] = []
    @State private var opened: TeamMatch? = nil
    @State private var shareOnOpen = false
    @State private var creatingFor: LeagueFixture? = nil
    @State private var matchMessage: String? = nil

    public init(snapshot: LeagueTeamSnapshot, fetcher: LeagueTeamFetcher? = nil,
                teamMatches: (any TeamMatchStore)? = nil, tools: TeamMatchTools? = nil) {
        _snapshot = State(initialValue: snapshot)
        self.fetcher = fetcher
        self.teamMatches = teamMatches
        self.tools = tools
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.name)
                            .font(SharedFonts.system(24, weight: .bold, design: .rounded))
                            .foregroundColor(SharedColors.textPrimary)
                        Text("\(snapshot.division) · \(snapshot.competition)")
                            .font(SharedFonts.system(12))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                    section(loc("STAND")) {
                        ForEach(snapshot.standings) { row in
                            let own = isOwnTeam(row)
                            HStack {
                                Text("\(row.rank)")
                                    .foregroundColor(own ? SharedColors.accent : SharedColors.textMuted)
                                    .frame(width: 26, alignment: .leading)
                                Text(row.name)
                                    .foregroundColor(own ? SharedColors.accent : SharedColors.textPrimary)
                                    .fontWeight(own ? .bold : .regular)
                                Spacer()
                                Text("\(row.points) pt", bundle: textBundle)
                                    .foregroundColor(own ? SharedColors.accent : SharedColors.gold)
                                    .fontWeight(own ? .bold : .regular)
                            }
                            .padding(.vertical, 5)
                            // The team you follow stands out: an orange band, as on the home tiles
                            // (every row indented alike; Compose has no negative padding)
                            .padding(.horizontal, 8)
                            .background(own ? SharedColors.accent.opacity(0.14) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(own ? SharedColors.accent.opacity(0.5) : Color.clear, lineWidth: 1))
                        }
                    }
                    section(loc("WEDSTRIJDEN")) {
                        // As in Competitie: today and what comes, a line, the past from old to recent
                        let order = CompetitionOverview.make(matches: [], fixtures: snapshot.fixtures)
                        ForEach(order.coming) { entry in
                            fixtureRow(entry)
                        }
                        if !order.coming.isEmpty && !order.past.isEmpty {
                            Divider().overlay(SharedColors.line(0.25)).padding(.vertical, 4)
                        }
                        ForEach(order.past) { entry in
                            fixtureRow(entry)
                        }
                        if let matchMessage {
                            Text(matchMessage)
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.error)
                                .padding(.top, 6)
                        }
                    }
                    // Seizoen per speler (4.0, T2): SBN's record and the team matches in the app
                    section(loc("SEIZOEN PER SPELER")) {
                        ForEach(TeamSeason.rows(team: snapshot, matches: matches)) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(row.name).foregroundColor(SharedColors.textPrimary)
                                    if !row.onTeamPage {
                                        Text("invaller", bundle: textBundle)
                                            .font(SharedFonts.system(11))
                                            .foregroundColor(SharedColors.textMuted)
                                    }
                                    Spacer()
                                    Text(row.sbnText)
                                        .font(SharedFonts.system(12, weight: .semibold))
                                        .foregroundColor(SharedColors.textSecondary)
                                }
                                if let app = row.appText {
                                    Text(app)
                                        .font(SharedFonts.system(11))
                                        .foregroundColor(SharedColors.textMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    HStack(spacing: 12) {
                        Text(refreshError ?? loc("Bijgewerkt: \(LeagueDates.day(snapshot.updatedAt)) \(LeagueDates.time(snapshot.updatedAt))"))
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textMuted)
                        Spacer()
                        if fetcher != nil {
                            if refreshing {
                                ProgressView()
                            } else {
                                Button(loc("Vernieuwen")) { Task { await refresh() } }
                                    .font(SharedFonts.system(13, weight: .semibold))
                                    .foregroundColor(SharedColors.accent)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .pageTitle(loc("Mijn team"))
        .task { await loadMatches() }
        .sheet(isPresented: Binding(get: { creatingFor != nil }, set: { if !$0 { creatingFor = nil } })) {
            if let fixture = creatingFor {
                NewTeamMatchSheet(team: snapshot, existing: matches, fixture: fixture) { match, share in
                    creatingFor = nil
                    Task { await create(match, share: share) }
                } onCancel: { creatingFor = nil }
            }
        }
        .navigationDestination(isPresented: Binding(get: { opened != nil }, set: { if !$0 { opened = nil } })) {
            if let opened, let teamMatches, let tools {
                SharedTeamMatchView(match: opened, store: teamMatches, tools: tools, team: snapshot, openShare: shareOnOpen) { _ in
                    Task { await loadMatches() }
                }
            }
        }
    }

    private func loadMatches() async {
        guard let teamMatches else { return }
        matches = (try? await teamMatches.loadAll()) ?? []
    }

    private func create(_ match: TeamMatch, share: Bool) async {
        guard let teamMatches else { return }
        do {
            let result = try await TeamMatchCreation.save(match, share: share, store: teamMatches)
            matchMessage = result.note
            await loadMatches()
            shareOnOpen = result.openShare
            opened = result.match
        } catch {
            matchMessage = loc("Opslaan is niet gelukt.")
        }
    }

    /// What a tap on a match does: open its team match, or make one for a
    /// coming match; nil for a past match without a team match here
    private func tapAction(_ fixture: LeagueFixture, match: TeamMatch?) -> (() -> Void)? {
        guard teamMatches != nil, tools != nil else { return nil }
        if let match {
            return { shareOnOpen = false; opened = match }
        }
        let coming = fixture.date >= Date() || Calendar.current.isDate(fixture.date, inSameDayAs: Date())
        guard coming else { return nil }
        return { matchMessage = nil; creatingFor = fixture }
    }

    private func refresh() async {
        guard let fetcher, let link = try? LeagueTeamLink(snapshot.source.absoluteString) else { return }
        refreshing = true
        refreshError = nil
        LeagueTeamStorage.noteAttempt()
        do {
            let result = try await fetcher.fetch(link)
            LeagueTeamStorage.store(result)
            snapshot = result
        } catch {
            refreshError = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message
        }
        refreshing = false
    }

    /// The followed team's row: same team page, or else the same name
    private func isOwnTeam(_ row: LeagueStanding) -> Bool {
        row.id == snapshot.source.path || row.name == snapshot.name
    }

    @ViewBuilder
    private func fixtureRow(_ entry: CompetitionEntry) -> some View {
        if let fixture = entry.fixture {
            let match = CompetitionOverview.match(for: fixture, in: matches, among: snapshot.fixtures)
            if let action = tapAction(fixture, match: match) {
                Button(action: action) { fixtureLine(fixture, match: match, tappable: true) }
                    .buttonStyle(.plain)
            } else {
                fixtureLine(fixture, match: match, tappable: false)
            }
        }
    }

    private func fixtureLine(_ fixture: LeagueFixture, match: TeamMatch?, tappable: Bool) -> some View {
            HStack(spacing: 10) {
                Text(LeagueDates.day(fixture.date))
                    .font(SharedFonts.system(11))
                    .foregroundColor(SharedColors.textMuted)
                    .frame(width: 82, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    LeagueTeamName(name: fixture.home, own: snapshot.name)
                    LeagueTeamName(name: fixture.away, own: snapshot.name)
                    // A coming match: who the opponent is in the standings and how it went last time
                    let opponent = fixture.score == nil ? LeagueOpponentText.line(snapshot.opponent(in: fixture)) : ""
                    if !opponent.isEmpty {
                        Text(opponent)
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if let match, fixture.score == nil {
                    // The team match on this phone: LIVE (or Bezig) and its stand in games
                    VStack(alignment: .trailing, spacing: 4) {
                        if match.isProbablyLive() {
                            LivePill(text: "LIVE")
                        } else if !match.isComplete {
                            Text("Bezig", bundle: textBundle)
                                .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                                .foregroundColor(SharedColors.support)
                        }
                        Text(match.gamesText)
                            .font(SharedFonts.system(15, weight: .bold, design: .rounded))
                            .foregroundColor(SharedColors.textPrimary)
                    }
                } else {
                    Text(fixture.score ?? LeagueDates.time(fixture.date))
                        .foregroundColor(fixture.score == nil ? SharedColors.textMuted : SharedColors.gold)
                }
                if tappable {
                    AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                }
            }
            .padding(.vertical, 5)
            #if !SKIP
            // The whole row is the tap target, also the space between the names and the stand
            .contentShape(Rectangle())
            #endif
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.tint(0.04)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
