import SwiftUI
import SquashAnalyzerCore
#if SKIP
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.Sports
import androidx.compose.material3.Icon
import androidx.compose.ui.unit.dp
#endif

/// Platform-independent home presentation. Navigation and persistence belong to
/// the host app; iOS keeps its existing destinations and Android adds them in phase 5.
public struct HomeMenuHeader: View {
    private let onSettings: (() -> Void)?

    public init(onSettings: (() -> Void)? = nil) {
        self.onSettings = onSettings
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image("home-logo", bundle: .module)
                .resizable().scaledToFit().frame(width: 58, height: 58)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                // Wordmark as on the sticker: "Analyzer" in brand orange.
                HStack(spacing: 0) {
                    Text("Squash").foregroundColor(SharedColors.textPrimary)
                    Text("Analyzer").foregroundColor(SharedColors.accent)
                }
                .font(SharedFonts.system(23, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                Text("Jouw spel scherp in beeld. Voor jou en je team.")
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let onSettings {
                Button(action: onSettings) {
                    AppSymbol("gearshape", size: 21, color: SharedColors.textSecondary)
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("Instellingen")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
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

    public init(onCoach: @escaping () -> Void, onReferee: @escaping () -> Void,
                onHistory: @escaping () -> Void, onPlayers: @escaping () -> Void, onBadges: @escaping () -> Void,
                onCompetition: (() -> Void)? = nil) {
        self.onCoach = onCoach
        self.onReferee = onReferee
        self.onHistory = onHistory
        self.onPlayers = onPlayers
        self.onBadges = onBadges
        self.onCompetition = onCompetition
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Klaar om te spelen?")
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            HStack(spacing: 12) {
                HomeMenuTile(title: "Coach", subtitle: "Start met coachen", icon: .coach, action: onCoach)
                HomeMenuTile(title: "Scheidsrechter", subtitle: "Start met fluiten", icon: .referee, action: onReferee)
            }
            VStack(spacing: 0) {
                menuRow("Afgeronde wedstrijden", icon: .history, action: onHistory)
                Divider().overlay(SharedColors.line(0.09))
                if let onCompetition {
                    menuRow("Competitie", icon: .competition, action: onCompetition)
                    Divider().overlay(SharedColors.line(0.09))
                }
                menuRow("Spelers", icon: .players, action: onPlayers)
                Divider().overlay(SharedColors.line(0.09))
                menuRow("Badges", icon: .badges, action: onBadges)
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
                Text("Jouw team").font(SharedFonts.system(14, weight: .semibold))
                Spacer()
                Text("Competitie").font(SharedFonts.system(12)).foregroundColor(SharedColors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("MIJN TEAM").font(SharedFonts.system(11, weight: .semibold))
                    .tracking(1.4).foregroundColor(SharedColors.accent)
                Text(snapshot.name).font(SharedFonts.system(20, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 28) {
                    stat("STAND", snapshot.rank)
                    stat("GESPEELD", snapshot.played)
                    stat("PUNTEN", snapshot.points)
                }
                if let next = snapshot.nextFixture() {
                    Divider().overlay(SharedColors.line(0.15))
                    Text("Volgende · \(LeagueDates.day(next.date)) · \(next.home) – \(next.away)")
                        .font(SharedFonts.system(12)).foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
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

/// The five home tiles' icons: a clipboard (coach), a whistle or raised hand
/// (referee), history, a group (players) and a medal (badges).
enum HomeTileIcon {
    case coach, referee, history, players, badges, competition

    /// SF Symbol on Apple. The referee is drawn (`WhistleShape`): the
    /// `whistle` symbols render as an empty glyph on the iOS SF Symbols
    /// runtime we test on, so this name is only a fallback.
    var symbol: String {
        switch self {
        case .coach: return "list.bullet.clipboard.fill"
        case .referee: return "hand.raised.fill"
        case .history: return "clock.arrow.circlepath"
        case .players: return "person.2.fill"
        case .badges: return "medal.fill"
        case .competition: return "trophy.fill"
        }
    }
}

#if !SKIP
/// A referee's whistle for iOS, in the spirit of Android's Material "Sports"
/// icon: a round body with an air hole, a mouthpiece to the right and a ring
/// for the cord. Drawn on a 24×24 grid and scaled to the frame; the body and
/// the holes are separate parts so the holes can be cut out of the union.
struct WhistleShape: Shape {
    enum Part { case body, holes }
    let part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .body:
            path.addEllipse(in: CGRect(x: 1, y: 8, width: 13, height: 13))
            path.addRoundedRect(in: CGRect(x: 8, y: 8, width: 15, height: 5.5), cornerSize: CGSize(width: 1.5, height: 1.5))
            path.addEllipse(in: CGRect(x: 2.5, y: 3, width: 5, height: 5))
        case .holes:
            path.addEllipse(in: CGRect(x: 5, y: 12.5, width: 5, height: 5))
            path.addEllipse(in: CGRect(x: 4, y: 4.5, width: 2, height: 2))
        }
        let scale = min(rect.width, rect.height) / 24
        return path.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }
}
#endif

/// SF Symbols on Apple; on Android the matching Material icons, drawn
/// directly with Compose, because Skip only maps a small set of SF Symbols
/// (the rest become a warning triangle).
struct HomeTileIconView: View {
    let icon: HomeTileIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        #if SKIP
        ComposeView { context in
            Icon(imageVector: materialIcon(), contentDescription: nil,
                 modifier: context.modifier.size(size.dp), tint: color.colorImpl())
        }
        #else
        if icon == .referee {
            // Solid whistle, then the air hole and the cord hole cut out
            ZStack {
                WhistleShape(part: .body).fill(color)
                WhistleShape(part: .holes).fill(Color.black).blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: size, height: size)
        } else {
            Image(systemName: icon.symbol)
                .font(SharedFonts.system(size * 0.85, weight: .semibold))
                .foregroundColor(color)
                .frame(width: size, height: size)
        }
        #endif
    }

    #if SKIP
    private func materialIcon() -> androidx.compose.ui.graphics.vector.ImageVector {
        switch icon {
        case .coach: return Icons.AutoMirrored.Filled.Assignment
        case .referee: return Icons.Filled.Sports
        case .history: return Icons.Filled.History
        case .players: return Icons.Filled.Groups
        case .badges: return Icons.Filled.MilitaryTech
        case .competition: return Icons.Filled.EmojiEvents
        }
    }
    #endif
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
    @State private var showingTeam = false
    @State private var team: LeagueTeamSnapshot?
    /// The tour version seen; the tour shows by itself until it is current
    @AppStorage(Onboarding.storageKey) private var tourSeen = 0
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
    @State private var showingCompetition = false

    public init(playerStore: any PlayerProfileStore, badgeStore: any PlayerBadgeSummaryStore,
                historyStore: any MatchHistoryStore,
                matchStore: any CoachMatchStore, refereeMatchStore: any RefereeMatchStore,
                shareText: @escaping (String) -> Void,
                cardInbox: CardInbox, cardImportStore: any CardImportStore,
                leagueTeamFetcher: LeagueTeamFetcher, aiCoach: AICoachContext? = nil, backup: BackupContext? = nil,
                teamImporter: (any TeamLinkImporter)? = nil, photoStore: (any PlayerPhotoStore)? = nil,
                filePicker: (any PlayerFilePicker)? = nil, shareCard: ((CardSnapshot, String) -> Void)? = nil,
                teamMatchStore: (any TeamMatchStore)? = nil) {
        self.teamMatchStore = teamMatchStore
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
                                     historyStore: historyStore, settings: SettingsContext(aiCoach: aiCoach, backup: backup),
                                     teamMatchStore: teamMatchStore,
                                     onExit: { showingCoach = false })
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $showingReferee) {
                    RefereeSessionView(store: refereeMatchStore, playerStore: playerStore, photoStore: photoStore, filePicker: filePicker, shareText: shareText,
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
                    SharedSettingsView(aiCoach: aiCoach, backup: backup)
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
                                                  aiCoach: aiCoach, shareText: shareText),
                            team: TeamMatchSupport.cachedTeam())
                    }
                }
        }
        .trackedCover(isPresented: Binding(get: { Onboarding.shouldShow(seenVersion: tourSeen) },
                                           set: { if !$0 { tourSeen = Onboarding.currentVersion } })) {
            SharedOnboardingView(manual: UserManual.android, onTeamLink: {
                tourSeen = Onboarding.currentVersion
                showingSettings = true
            }) {
                tourSeen = Onboarding.currentVersion
            }
        }
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

    private var homeContent: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        HomeMenuHeader { showingSettings = true }
                        SharedLeagueTeamCard(fetcher: leagueTeamFetcher, onTeam: { snapshot in
                            let store = playerStore
                            Task { _ = await TeamRosterSync.run(snapshot, store: store) }
                        }, onSetup: { showingSettings = true }, helpURL: UserManual.androidTeamLink) { snapshot in
                            team = snapshot
                            showingTeam = true
                        }
                        HomeMenuTiles(
                            onCoach: { showingCoach = true },
                            onReferee: { showingReferee = true },
                            onHistory: { showingHistory = true },
                            onPlayers: { showingPlayers = true },
                            onBadges: { showingBadges = true },
                            onCompetition: teamMatchStore == nil ? nil : { showingCompetition = true }
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
