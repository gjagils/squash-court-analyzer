import SwiftUI
import SquashAnalyzerCore
#if SKIP
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
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
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Text("SQUASH ANALYZER")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(HomePalette.text)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if let onSettings {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 21))
                        .foregroundColor(HomePalette.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Instellingen")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 5)
    }
}

public struct HomeMenuTiles: View {
    private let onCoach: () -> Void
    private let onReferee: () -> Void
    private let onHistory: () -> Void
    private let onPlayers: () -> Void
    private let onBadges: () -> Void

    public init(onCoach: @escaping () -> Void, onReferee: @escaping () -> Void,
                onHistory: @escaping () -> Void, onPlayers: @escaping () -> Void, onBadges: @escaping () -> Void) {
        self.onCoach = onCoach
        self.onReferee = onReferee
        self.onHistory = onHistory
        self.onPlayers = onPlayers
        self.onBadges = onBadges
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
            HomeMenuTile(title: "Coach", icon: .coach, action: onCoach)
            HomeMenuTile(title: "Scheidsrechter", icon: .referee, action: onReferee)
            HomeMenuTile(title: "Afgeronde wedstrijden", icon: .history, action: onHistory)
            HomeMenuTile(title: "Spelers", icon: .players, action: onPlayers)
            HomeMenuTile(title: "Badges", icon: .badges, action: onBadges)
        }
        .padding(.horizontal, 24)
    }
}

private enum HomePalette {
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let secondary = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
}

/// All tiles share one accent colour, so the icon is what tells them apart
private struct HomeMenuTile: View {
    let title: String
    let icon: HomeTileIcon
    let action: () -> Void

    private var color: Color { HomePalette.orange }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HomeTileIconView(icon: icon, color: color, size: 30)
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(HomePalette.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The five home tiles' icons: a clipboard (coach), a whistle or raised hand
/// (referee), history, a group (players) and a medal (badges).
enum HomeTileIcon {
    case coach, referee, history, players, badges

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
                .font(.system(size: size * 0.85, weight: .semibold))
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
    @State private var showingSettings = false
    @State private var showingTeam = false
    @State private var team: LeagueTeamSnapshot?
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

    public init(playerStore: any PlayerProfileStore, badgeStore: any PlayerBadgeSummaryStore,
                historyStore: any MatchHistoryStore,
                matchStore: any CoachMatchStore, refereeMatchStore: any RefereeMatchStore,
                shareText: @escaping (String) -> Void,
                cardInbox: CardInbox, cardImportStore: any CardImportStore,
                leagueTeamFetcher: LeagueTeamFetcher) {
        self.leagueTeamFetcher = leagueTeamFetcher
        self.shareText = shareText
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
                    PlayerDirectoryView(store: playerStore, badgeStore: badgeStore, shareText: shareText, cardInbox: cardInbox)
                }
                .navigationDestination(isPresented: $showingCoach) {
                    CoachSessionView(store: matchStore, playerStore: playerStore, onExit: { showingCoach = false })
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $showingReferee) {
                    RefereeSessionView(store: refereeMatchStore, playerStore: playerStore, onExit: { showingReferee = false })
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $showingBadges) {
                    SharedBadgeCatalogView()
                }
                .navigationDestination(isPresented: $showingHistory) {
                    SharedMatchHistoryView(store: historyStore)
                }
                .navigationDestination(isPresented: $showingSettings) {
                    SharedSettingsView()
                }
                .navigationDestination(isPresented: $showingTeam) {
                    if let team {
                        SharedLeagueTeamDetailView(snapshot: team)
                    }
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
        .preferredColorScheme(.dark)
    }

    private var homeContent: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.08),
                                    Color(red: 0.06, green: 0.05, blue: 0.04)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HomeMenuHeader { showingSettings = true }
                ScrollView {
                    VStack(spacing: 20) {
                        SharedLeagueTeamCard(fetcher: leagueTeamFetcher) { snapshot in
                            team = snapshot
                            showingTeam = true
                        }
                        HomeMenuTiles(
                            onCoach: { showingCoach = true },
                            onReferee: { showingReferee = true },
                            onHistory: { showingHistory = true },
                            onPlayers: { showingPlayers = true },
                            onBadges: { showingBadges = true }
                        )
                        Text("Coach- en scheidsrechterwedstrijden worden automatisch opgeslagen en kunnen worden hervat.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(HomePalette.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
