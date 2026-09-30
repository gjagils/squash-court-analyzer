import SwiftUI
import SquashAnalyzerCore

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
            HomeMenuTile(title: "Coach", icon: "chart.bar.xaxis", color: HomePalette.orange, action: onCoach)
            HomeMenuTile(title: "Scheidsrechter", icon: "hand.raised.fill", color: HomePalette.orange, action: onReferee)
            HomeMenuTile(title: "Afgeronde wedstrijden", icon: "clock.arrow.circlepath", color: HomePalette.blue, action: onHistory)
            HomeMenuTile(title: "Spelers", icon: "person.2.fill", color: HomePalette.gold, action: onPlayers)
            HomeMenuTile(title: "Badges", icon: "medal.fill", color: HomePalette.gold, action: onBadges)
        }
        .padding(.horizontal, 24)
    }
}

private enum HomePalette {
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let secondary = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let blue = Color(red: 0.35, green: 0.45, blue: 0.55)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
}

private struct HomeMenuTile: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HomeMenuIcon(name: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(color)
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

/// Skip's built-in symbol mapping only covers a subset of SF Symbols.
/// These small original paths supply the three missing home symbols on Android.
private struct HomeMenuIcon: View {
    let name: String

    var body: some View {
        #if SKIP
        if name == "person.2.fill" {
            Path { path in
                path.addEllipse(in: CGRect(x: 5, y: 2, width: 8, height: 8))
                path.addEllipse(in: CGRect(x: 16, y: 4, width: 7, height: 7))
                path.addRoundedRect(in: CGRect(x: 1, y: 12, width: 16, height: 12), cornerSize: CGSize(width: 6, height: 6))
                path.addRoundedRect(in: CGRect(x: 18, y: 13, width: 8, height: 11), cornerSize: CGSize(width: 3, height: 3))
            }.fill().frame(width: 26, height: 26)
        } else if name == "clock.arrow.circlepath" {
            ZStack {
                Circle().stroke(lineWidth: 2)
                Path { path in
                    path.move(to: CGPoint(x: 13, y: 5))
                    path.addLine(to: CGPoint(x: 13, y: 13))
                    path.addLine(to: CGPoint(x: 18, y: 16))
                }.stroke(lineWidth: 2)
            }.frame(width: 26, height: 26)
        } else if name == "hand.raised.fill" {
            Path { path in
                path.move(to: CGPoint(x: 7, y: 24))
                path.addLine(to: CGPoint(x: 1, y: 15))
                path.addQuadCurve(to: CGPoint(x: 4, y: 13), control: CGPoint(x: 0, y: 10))
                path.addLine(to: CGPoint(x: 7, y: 16))
                path.addLine(to: CGPoint(x: 7, y: 5))
                path.addQuadCurve(to: CGPoint(x: 10, y: 5), control: CGPoint(x: 8.5, y: 1))
                path.addLine(to: CGPoint(x: 10, y: 12))
                path.addLine(to: CGPoint(x: 11, y: 2))
                path.addQuadCurve(to: CGPoint(x: 14, y: 2), control: CGPoint(x: 12.5, y: -1))
                path.addLine(to: CGPoint(x: 14, y: 12))
                path.addLine(to: CGPoint(x: 15, y: 4))
                path.addQuadCurve(to: CGPoint(x: 18, y: 4), control: CGPoint(x: 16.5, y: 1))
                path.addLine(to: CGPoint(x: 18, y: 13))
                path.addLine(to: CGPoint(x: 19, y: 8))
                path.addQuadCurve(to: CGPoint(x: 22, y: 8), control: CGPoint(x: 20.5, y: 5))
                path.addLine(to: CGPoint(x: 22, y: 19))
                path.addQuadCurve(to: CGPoint(x: 18, y: 25), control: CGPoint(x: 22, y: 25))
                path.closeSubpath()
            }.fill().frame(width: 26, height: 26)
        } else if name == "medal.fill" {
            ZStack {
                Circle().stroke(lineWidth: 2)
                Circle().frame(width: 9, height: 9)
            }.frame(width: 26, height: 26)
        } else {
            Image(systemName: name)
        }
        #else
        Image(systemName: name)
        #endif
    }
}

/// Android's first screen. Feature destinations are introduced individually in
/// phase 5, so every unfinished action explains its availability instead of
/// opening a nonfunctional scoring screen.
public struct AndroidHomeView: View {
    @State private var showingAvailability = false
    @State private var selectedFeature = ""

    private let playerStore: any PlayerProfileStore
    private let badgeStore: any PlayerBadgeSummaryStore
    private let historyStore: any MatchHistoryStore
    @State private var showingPlayers = false
    @State private var showingCoach = false
    @State private var showingReferee = false
    @State private var showingBadges = false
    @State private var showingHistory = false
    private let matchStore: any CoachMatchStore
    private let refereeMatchStore: any RefereeMatchStore
    /// Opens the platform share sheet with a text (a card link); Android's
    /// `MainActivity` supplies `Intent.ACTION_SEND`
    private let shareText: (String) -> Void
    /// A card link opened from outside the app; the import screen shows while one is pending
    private let cardInbox: CardInbox
    private let cardImportStore: any CardImportStore

    public init(playerStore: any PlayerProfileStore, badgeStore: any PlayerBadgeSummaryStore,
                historyStore: any MatchHistoryStore,
                matchStore: any CoachMatchStore, refereeMatchStore: any RefereeMatchStore,
                shareText: @escaping (String) -> Void,
                cardInbox: CardInbox, cardImportStore: any CardImportStore) {
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
                    PlayerDirectoryView(store: playerStore, badgeStore: badgeStore, shareText: shareText)
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
        }
        .sheet(isPresented: Binding(get: { cardInbox.pending != nil },
                                    set: { if !$0 { cardInbox.pending = nil } })) {
            if let snapshot = cardInbox.pending {
                SharedCardImportView(snapshot: snapshot, store: cardImportStore) { cardInbox.pending = nil }
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
                HomeMenuHeader { showAvailability("Instellingen") }
                ScrollView {
                    VStack(spacing: 20) {
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
        .alert(selectedFeature, isPresented: $showingAvailability) {
            Button("Begrepen", role: .cancel) {}
        } message: {
            Text("Deze functie is nog niet beschikbaar op Android. We voegen de onderdelen stap voor stap toe.")
        }
    }

    private func showAvailability(_ feature: String) {
        selectedFeature = feature
        showingAvailability = true
    }
}
