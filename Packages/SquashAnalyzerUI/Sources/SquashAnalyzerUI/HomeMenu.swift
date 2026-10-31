import SwiftUI
import SquashAnalyzerCore

/// Platform-independent home presentation. Navigation and persistence belong to
/// the host app; iOS keeps its existing destinations and Android adds them in phase 5.
public struct HomeMenuHeader: View {
    private let onSettings: (() -> Void)?

    public init(onSettings: (() -> Void)? = nil) {
        self.onSettings = onSettings
    }

    /// The logo and the text block are the same height; the text is centred
    /// next to the logo, the gear sits in the top right corner so the text
    /// gets the full width (Gerd-Jan, 12 October 2026)
    private static let logoSize: CGFloat = 72

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if let onSettings {
                    Button(action: onSettings) {
                        AppSymbol("gearshape", size: 20, color: SharedColors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(loc("Instellingen"))
                    // Same spot as the gear in the coach and referee headers (20 pt from the edge)
                    .padding(.trailing, -4)
                }
            }
            .frame(height: 36)
            HStack(spacing: 12) {
                // The logo on its own dark tile, or on warm light in the light theme
                Image(AppTheme.shared.isLight ? "home-logo-light" : "home-logo", bundle: .module)
                    .resizable().scaledToFit().frame(width: HomeMenuHeader.logoSize, height: HomeMenuHeader.logoSize)
                    .accessibilityHidden(true)
                VStack(alignment: .center, spacing: 0) {
                    // Wordmark as on the sticker: "Analyzer" in brand orange.
                    HStack(spacing: 0) {
                        Text("Squash").foregroundColor(SharedColors.textPrimary)
                        Text("Analyzer").foregroundColor(SharedColors.accent)
                    }
                    .font(SharedFonts.system(26, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    Text("Jouw spel scherp in beeld. Voor jou en je team.", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.top, 2)
                    // The line from the stickers and the website; the sentence
                    // sits halfway between the wordmark and this line (the wordmark's
                    // line already has some room under it, hence 2 and 6)
                    Text("SCHEIDSEN · COACHEN · DELEN", bundle: textBundle)
                        .font(SharedFonts.system(11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(SharedColors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel(loc("Scheidsen, coachen, delen"))
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: HomeMenuHeader.logoSize)
            }
            // Outlined like the other blocks on the home screen; no fill, so
            // the logo keeps the page background it was made for
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

}

public struct HomeMenuTiles: View {
    private let onCoach: () -> Void
    private let onReferee: () -> Void
    private let onHistory: () -> Void
    private let onPlayers: () -> Void
    private let onBadges: () -> Void
    /// Competitie (teamwedstrijden); the row only shows when the host wires it
    private let onCompetition: (() -> Void)?
    /// Wedstrijd volgen (live score op het vergrendelscherm); only where the platform supports it
    private let onLiveFollow: (() -> Void)?

    public init(onCoach: @escaping () -> Void, onReferee: @escaping () -> Void,
                onHistory: @escaping () -> Void, onPlayers: @escaping () -> Void, onBadges: @escaping () -> Void,
                onCompetition: (() -> Void)? = nil, onLiveFollow: (() -> Void)? = nil) {
        self.onLiveFollow = onLiveFollow
        self.onCoach = onCoach
        self.onReferee = onReferee
        self.onHistory = onHistory
        self.onPlayers = onPlayers
        self.onBadges = onBadges
        self.onCompetition = onCompetition
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Klaar om te spelen?", bundle: textBundle)
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            HStack(spacing: 12) {
                HomeMenuTile(title: loc("Scheidsrechter"), subtitle: loc("Start met fluiten"), icon: .referee, action: onReferee)
                HomeMenuTile(title: loc("Coach"), subtitle: loc("Start met coachen"), icon: .coach, action: onCoach)
            }
            VStack(spacing: 0) {
                menuRow(loc("Afgeronde wedstrijden"), icon: .history, action: onHistory)
                Divider().overlay(SharedColors.line(0.09))
                if let onCompetition {
                    menuRow(loc("Competitie"), icon: .competition, action: onCompetition)
                    Divider().overlay(SharedColors.line(0.09))
                }
                if let onLiveFollow {
                    menuRow(loc("Wedstrijd volgen"), icon: .liveFollow, action: onLiveFollow)
                    Divider().overlay(SharedColors.line(0.09))
                }
                menuRow(loc("Spelers"), icon: .players, action: onPlayers)
                Divider().overlay(SharedColors.line(0.09))
                menuRow(loc("Badges"), icon: .badges, action: onBadges)
            }
        }
        .padding(.horizontal, 24)
    }

    private func menuRow(_ title: String, icon: HomeTileIcon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HomeTileIconView(icon: icon, color: SharedColors.accent, size: 23)
                Text(title).font(SharedFonts.system(14))
                Spacer()
                AppSymbol("chevron.right", size: 12, color: SharedColors.textPrimary)
            }
            .foregroundColor(SharedColors.textPrimary)
            .frame(minHeight: 50)
            // Apple only: a no-op in SkipUI, and Compose's clickable already covers the row (docs/bewuste-keuzes.md)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Identical home team presentation for both native hosts; loading and navigation stay with the host.
public struct HomeTeamSummary: View {
    private let snapshot: LeagueTeamSnapshot
    public init(snapshot: LeagueTeamSnapshot) { self.snapshot = snapshot }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Jouw team", bundle: textBundle).font(SharedFonts.system(14, weight: .semibold))
                Spacer()
                Text("Competitie", bundle: textBundle).font(SharedFonts.system(12)).foregroundColor(SharedColors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("MIJN TEAM", bundle: textBundle).font(SharedFonts.system(11, weight: .semibold))
                    .tracking(1.4).foregroundColor(SharedColors.accent)
                Text(snapshot.name).font(SharedFonts.system(20, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 28) {
                    stat(loc("STAND"), snapshot.rank)
                    stat(loc("GESPEELD"), snapshot.played)
                    stat(loc("PUNTEN"), snapshot.points)
                }
                if let next = snapshot.nextFixture() {
                    Divider().overlay(SharedColors.line(0.15))
                    Text("Volgende · \(LeagueDates.day(next.date))", bundle: textBundle)
                        .font(SharedFonts.system(12)).foregroundColor(SharedColors.textSecondary)
                    // The own team lighter and bolder, so you see at a glance which side you are
                    HStack(spacing: 4) {
                        LeagueTeamName(name: next.home, own: snapshot.name)
                        Text("–").foregroundColor(SharedColors.textMuted)
                        LeagueTeamName(name: next.away, own: snapshot.name)
                    }
                    .font(SharedFonts.system(13))
                    let opponent = LeagueOpponentText.line(snapshot.opponent(in: next))
                    if !opponent.isEmpty {
                        Text(opponent)
                            .font(SharedFonts.system(11)).foregroundColor(SharedColors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
        }
        .foregroundColor(SharedColors.textPrimary)
    }

    private func stat(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.map { String($0) } ?? "–")
                .font(SharedFonts.system(24, weight: .bold, design: .rounded)).foregroundColor(SharedColors.accent)
            Text(title).font(SharedFonts.system(10)).foregroundColor(SharedColors.textSecondary)
        }
    }
}


/// All tiles share one accent colour, so the icon is what tells them apart
private struct HomeMenuTile: View {
    let title: String
    let subtitle: String
    let icon: HomeTileIcon
    let action: () -> Void

    private var color: Color { SharedColors.accent }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HomeTileIconView(icon: icon, color: color, size: 30)
                Text(title.uppercased())
                    .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(SharedColors.textPrimary)
                    .multilineTextAlignment(.center)
                    // Large system text broke "SCHEIDSRECHTE / R" on Android: one line, a little smaller
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 110)
            .background(SharedColors.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The home tiles' icons, outlines like the sticker: a clipboard (coach), a
/// whistle (referee), history, a group (players), a medal (badges) and a cup
/// (competition). The clipboard also marks the coach card, everywhere.
enum HomeTileIcon {
    case coach, referee, history, players, badges, competition, liveFollow

    /// The AppSymbol name; all but history are drawn by the app (`OutlineIcon`)
    var symbol: String {
        switch self {
        case .coach: return "list.bullet.clipboard"
        case .referee: return "whistle"
        case .history: return "clock.arrow.circlepath"
        case .players: return "person.2"
        case .badges: return "medal"
        case .competition: return "trophy"
        case .liveFollow: return "lock.iphone"
        }
    }
}

/// The home tiles' icons in one place, so the tour and the menu draw the same
struct HomeTileIconView: View {
    let icon: HomeTileIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        AppSymbol(icon.symbol, size: size, color: color, weight: .medium)
            .frame(width: size, height: size)
    }
}

/// Android's first screen: the Mijn team card (once a team link is saved in
/// Instellingen) above the five tiles; every tile and the gear lead somewhere.
public struct AndroidHomeView: View {
    private let playerStore: any PlayerProfileStore
    private let badgeStore: any PlayerBadgeSummaryStore
    private let historyStore: any MatchHistoryStore
    @State private var showingPlayers = false
    @State private var showingCoach = false
    @State private var showingReferee = false
    @State private var showingBadges = false
    @State private var showingHistory = false
    /// A coach match opened for its analysis from Afgeronde wedstrijden
    @State private var analysedMatch: Match? = nil
    @State private var showingSettings = false
    /// Instellingen opens with Mijn team unfolded
    @State private var settingsOpensTeam = false
    @State private var showingTeam = false
    @State private var team: LeagueTeamSnapshot?
    /// The tour version seen; the tour shows by itself until it is current
    @AppStorage(Onboarding.storageKey) private var tourSeen = 0
    /// The "Nieuw in 3.0" version seen; it comes first, with the tour as a choice
    @AppStorage(WhatsNew.storageKey) private var whatsNewSeen = 0
    /// "Testgegevens opruimen" was answered (once, after the badge reset)
    @AppStorage(TestDataCleanup.storageKey) private var testDataCleanupDone = false
    /// What the cleanup question offers; set when there is something to clean up
    @State private var testDataCounts: TestDataCounts? = nil
    /// The test period's matches (Android supplies Room)
    private let testDataStore: (any TestDataCleanupStore)?
    private let matchStore: any CoachMatchStore
    private let refereeMatchStore: any RefereeMatchStore
    /// Opens the platform share sheet with a text (a card link); Android's
    /// `MainActivity` supplies `Intent.ACTION_SEND`
    private let shareText: (String) -> Void
    /// A card link opened from outside the app; the import screen shows while one is pending
    private let cardInbox: CardInbox
    private let cardImportStore: any CardImportStore
    /// Fetches Mijn team from sbn.toernooi.nl (Android supplies the page loader)
    private let leagueTeamFetcher: LeagueTeamFetcher
    private var settingsContext: SettingsContext {
        var context = SettingsContext(aiCoach: aiCoach, backup: backup, onLanguage: onLanguage)
        context.leagueFetcher = leagueTeamFetcher
        return context
    }
    /// AI Coach (Android supplies the key store and the sender)
    private let aiCoach: AICoachContext?
    /// Backups in Instellingen (Android supplies Room and the file pickers)
    private let backup: BackupContext?
    /// Spelers → Team via link or zip (Android supplies download, unzip and Room)
    private let teamImporter: (any TeamLinkImporter)?
    /// Player photos and the system pickers (Android)
    private let photoStore: (any PlayerPhotoStore)?
    private let filePicker: (any PlayerFilePicker)?
    /// "Deel kaart" with a picture (Android draws it)
    private let shareCard: ((CardSnapshot, String) -> Void)?
    /// Competitie: team matches in a JSON file (Android supplies its files directory)
    private let teamMatchStore: (any TeamMatchStore)?
    /// Instellingen → Taal: the system's per-app language screen (Android's
    /// MainActivity supplies it); nil hides the row
    private let onLanguage: ((String) -> Void)?
    @State private var showingCompetition = false
    /// Wedstrijd volgen (live score op het vergrendelscherm), when the app set a presenter
    @State private var showingLiveFollow = false

    public init(playerStore: any PlayerProfileStore, badgeStore: any PlayerBadgeSummaryStore,
                historyStore: any MatchHistoryStore,
                matchStore: any CoachMatchStore, refereeMatchStore: any RefereeMatchStore,
                shareText: @escaping (String) -> Void,
                cardInbox: CardInbox, cardImportStore: any CardImportStore,
                leagueTeamFetcher: LeagueTeamFetcher, aiCoach: AICoachContext? = nil, backup: BackupContext? = nil,
                teamImporter: (any TeamLinkImporter)? = nil, photoStore: (any PlayerPhotoStore)? = nil,
                filePicker: (any PlayerFilePicker)? = nil, shareCard: ((CardSnapshot, String) -> Void)? = nil,
                teamMatchStore: (any TeamMatchStore)? = nil, testDataStore: (any TestDataCleanupStore)? = nil,
                onLanguage: ((String) -> Void)? = nil) {
        self.onLanguage = onLanguage
        self.teamMatchStore = teamMatchStore
        self.testDataStore = testDataStore
        self.teamImporter = teamImporter
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.leagueTeamFetcher = leagueTeamFetcher
        self.backup = backup
        self.aiCoach = aiCoach
        self.shareText = shareText
        self.shareCard = shareCard
        self.cardInbox = cardInbox
        self.cardImportStore = cardImportStore
        self.playerStore = playerStore
        self.badgeStore = badgeStore
        self.historyStore = historyStore
        self.matchStore = matchStore
        self.refereeMatchStore = refereeMatchStore
    }

    public var body: some View {
        NavigationStack {
            homeContent
                .navigationDestination(isPresented: $showingPlayers) {
                    PlayerDirectoryView(store: playerStore, badgeStore: badgeStore, shareText: shareText, cardInbox: cardInbox, teamImporter: teamImporter,
                                        photoStore: photoStore, filePicker: filePicker, shareCard: shareCard, historyStore: historyStore)
                }
                .navigationDestination(isPresented: $showingCoach) {
                    CoachSessionView(store: matchStore, playerStore: playerStore, photoStore: photoStore, filePicker: filePicker, aiCoach: aiCoach, shareText: shareText,
                                     historyStore: historyStore, settings: settingsContext,
                                     teamMatchStore: teamMatchStore,
                                     onExit: { showingCoach = false })
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $showingReferee) {
                    RefereeSessionView(store: refereeMatchStore, playerStore: playerStore, photoStore: photoStore, filePicker: filePicker, shareText: shareText,
                                       settings: settingsContext,
                                       teamMatchStore: teamMatchStore, onExit: { showingReferee = false })
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $showingBadges) {
                    SharedBadgeCatalogView()
                }
                .navigationDestination(isPresented: $showingHistory) {
                    SharedMatchHistoryView(store: historyStore, aiCoach: aiCoach, shareText: shareText) { match in
                        // As on iOS: the list closes and the analysis opens
                        showingHistory = false
                        analysedMatch = match
                    }
                }
                .navigationDestination(isPresented: $showingSettings) {
                    SharedSettingsView(aiCoach: aiCoach, backup: backup, onLanguage: onLanguage, leagueFetcher: leagueTeamFetcher,
                                       opensTeam: settingsOpensTeam)
                }
                .navigationDestination(isPresented: $showingTeam) {
                    if let team {
                        SharedLeagueTeamDetailView(snapshot: team, fetcher: leagueTeamFetcher)
                    }
                }
                .navigationDestination(isPresented: $showingCompetition) {
                    if let teamMatchStore {
                        SharedTeamMatchesView(
                            store: teamMatchStore,
                            tools: TeamMatchTools(historyStore: historyStore, playerStore: playerStore, coachStore: matchStore,
                                                  refereeStore: refereeMatchStore, photoStore: photoStore, filePicker: filePicker,
                                                  aiCoach: aiCoach, shareText: shareText, leagueFetcher: leagueTeamFetcher),
                            team: TeamMatchSupport.cachedTeam())
                    }
                }
        }
        // "Nieuw in 3.0" (with the tour as a choice), or the tour alone once it is raised
        .trackedCover(isPresented: Binding(get: { welcomeNeeded },
                                           set: { if !$0 { welcomeSeen() } })) {
            if WhatsNew.shouldShow(seenVersion: whatsNewSeen) {
                SharedWhatsNewView(manual: UserManual.android, onTeamLink: {
                    welcomeSeen()
                    settingsOpensTeam = true
                    showingSettings = true
                }) { welcomeSeen() }
            } else {
                SharedOnboardingView(manual: UserManual.android, onTeamLink: {
                    welcomeSeen()
                    settingsOpensTeam = true
                    showingSettings = true
                }) { welcomeSeen() }
            }
        }
        .sheet(isPresented: $showingLiveFollow) {
            SharedLiveFollowView { showingLiveFollow = false }
        }
        .sheet(isPresented: Binding(get: { testDataCounts != nil && !welcomeNeeded },
                                    set: { if !$0 { testDataCounts = nil } })) {
            if let counts = testDataCounts, let start = BadgeSeason.start, let testDataStore {
                SharedTestDataCleanupView(counts: counts, before: start, store: testDataStore) {
                    testDataCleanupDone = true
                    testDataCounts = nil
                }
            }
        }
        .task { await offerTestDataCleanup() }
        .sheet(isPresented: Binding(get: { cardInbox.pending != nil },
                                    set: { if !$0 { cardInbox.pending = nil } })) {
            if let snapshot = cardInbox.pending {
                SharedCardImportView(snapshot: snapshot, store: cardImportStore) { imported in
                    if imported { cardInbox.finishImport() } else { cardInbox.pending = nil }
                }
            }
        }
        .sheet(isPresented: Binding(get: { cardInbox.pendingTeam != nil }, set: { if !$0 { cardInbox.pendingTeam = nil } })) {
            // A link to a live team match was opened: join it
            if let invite = cardInbox.pendingTeam, let teamMatchStore {
                SharedTeamJoinView(store: teamMatchStore, team: TeamMatchSupport.cachedTeam(), initialCode: invite.code) { _ in
                    cardInbox.pendingTeam = nil
                    showingCompetition = true
                } onCancel: { cardInbox.pendingTeam = nil }
            }
        }
        .sheet(isPresented: Binding(get: { analysedMatch != nil }, set: { if !$0 { analysedMatch = nil } })) {
            if let match = analysedMatch {
                SharedCoachDashboardView(match: match, game: match.games.last ?? match.currentGame, aiCoach: aiCoach,
                                         shareText: shareText) { analysedMatch = nil }
            }
        }
        .appAppearance()
    }

    /// After the badge reset, once: offers to remove the test period's matches
    /// when there are any; with nothing to remove the question is done at once
    private func offerTestDataCleanup() async {
        guard TestDataCleanup.shouldOffer(done: testDataCleanupDone), let start = BadgeSeason.start, let testDataStore else { return }
        guard let counts = try? await testDataStore.counts(before: start) else { return }
        if counts.needsSheet { testDataCounts = counts } else { testDataCleanupDone = true }
    }

    /// "Nieuw in 3.0" or the tour still has to show
    private var welcomeNeeded: Bool {
        WhatsNew.shouldShow(seenVersion: whatsNewSeen) || Onboarding.shouldShow(seenVersion: tourSeen)
    }

    /// Both seen, whether the tour was chosen or skipped: neither comes back by itself
    private func welcomeSeen() {
        whatsNewSeen = WhatsNew.currentVersion
        tourSeen = Onboarding.currentVersion
    }

    private var homeContent: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        HomeMenuHeader { settingsOpensTeam = false; showingSettings = true }
                        SharedLeagueTeamCard(fetcher: leagueTeamFetcher, onTeam: { snapshot in
                            let store = playerStore
                            Task { _ = await TeamRosterSync.run(snapshot, store: store) }
                        }, onSetup: { settingsOpensTeam = true; showingSettings = true }) { snapshot in
                            team = snapshot
                            showingTeam = true
                        }
                        HomeMenuTiles(
                            onCoach: { showingCoach = true },
                            onReferee: { showingReferee = true },
                            onHistory: { showingHistory = true },
                            onPlayers: { showingPlayers = true },
                            onBadges: { showingBadges = true },
                            onCompetition: teamMatchStore == nil ? nil : { showingCompetition = true },
                            onLiveFollow: LiveFollow.shared.presenter == nil ? nil : { showingLiveFollow = true }
                        )
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }
}
