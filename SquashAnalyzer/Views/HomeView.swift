import SwiftUI
import SwiftData
import SquashAnalyzerCore
import SquashAnalyzerUI

// MARK: - Home screen

/// The app's starting point: the "Mijn team" card, then one tile per thing you
/// can do. Coach and Scheidsrechter open the shared sessions (resume question,
/// match start and scoring, as on Android); see `ContentView`.
struct HomeView: View {
    var onCoach: () -> Void
    var onReferee: () -> Void
    var onViewHistory: () -> Void
    var onOpenSettings: () -> Void
    /// "Zoek je club" on the competition card: Instellingen with Mijn team open
    var onFindClub: () -> Void
    /// A cover or a first-time screen is up: the question about the sample players waits
    var questionsWaiting = false

    @State private var showingPlayerManagement = false
    @State private var showingBadgeCatalog = false
    @State private var showingCompetition = false
    /// A live team match of the own team is running (LIVE on the Competitie row)
    @State private var competitionLive = false
    /// Opened from the bar on the Mijn team card
    @State private var openedTeamMatch: TeamMatch?
    @Environment(\.modelContext) private var modelContext

    private var teamMatchTools: TeamMatchTools {
        let players = SwiftDataPlayerStore(context: modelContext)
        return TeamMatchTools(historyStore: SwiftDataMatchHistoryStore(context: modelContext), playerStore: players,
                              coachStore: SwiftDataCoachMatchStore(context: modelContext),
                              refereeStore: SwiftDataRefereeMatchStore(context: modelContext),
                              photoStore: players, filePicker: nil, aiCoach: IOSAICoach.context,
                              shareText: { text in IOSShare.text(text) },
                              leagueFetcher: LeagueTeamService.shared)
    }

    /// A team match on the server (shared live, or joined with a code) that can
    /// still be live: not finished, and updated within the server's two-hour window
    private static func hasLiveTeamMatch() async -> Bool {
        // First what teammates put on the live pages, then the marker
        _ = await TeamLiveSync.pull(store: TeamMatchStorage.store)
        let matches = (try? await TeamMatchStorage.store.loadAll()) ?? []
        return matches.contains { match in match.isProbablyLive() }
    }

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            SamplePlayersQuestion(store: SwiftDataPlayerStore(context: modelContext), waiting: questionsWaiting)

            ScrollView {
                VStack(spacing: 16) {
                    HomeMenuHeader(onSettings: onOpenSettings)
                    LeagueTeamCard(onSetup: onFindClub, matchesPaused: showingCompetition || openedTeamMatch != nil) { match in
                        openedTeamMatch = match
                    }
                    HomeMenuTiles(
                        onCoach: onCoach,
                        onReferee: onReferee,
                        onHistory: onViewHistory,
                        onPlayers: { showingPlayerManagement = true },
                        onBadges: { showingBadgeCatalog = true },
                        onCompetition: { showingCompetition = true },
                        competitionLive: competitionLive
                    )
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        // LIVE on the Competitie row while a team match of the own team is live
        .task { competitionLive = await Self.hasLiveTeamMatch() }
        // Back from Competitie (Live stoppen, a new live match): read it again
        .onChange(of: showingCompetition) { _, shown in
            if !shown { Task { competitionLive = await Self.hasLiveTeamMatch() } }
        }
        .sheet(isPresented: $showingPlayerManagement) {
            PlayerManagementView()
        }
        .sheet(isPresented: $showingBadgeCatalog) {
            NavigationStack {
                SharedBadgeCatalogView()
                    .toolbar {
                        CloseToolbarItem { showingBadgeCatalog = false }
                    }
            }
        }
        .sheet(isPresented: $showingCompetition) {
            NavigationStack {
                SharedTeamMatchesView(
                    store: TeamMatchStorage.store,
                    tools: teamMatchTools,
                    team: TeamMatchSupport.cachedTeam())
                    .toolbar {
                        CloseToolbarItem { showingCompetition = false }
                    }
            }
        }
        .sheet(isPresented: Binding(get: { openedTeamMatch != nil }, set: { if !$0 { openedTeamMatch = nil } })) {
            if let match = openedTeamMatch {
                NavigationStack {
                    SharedTeamMatchView(match: match, store: TeamMatchStorage.store, tools: teamMatchTools,
                                        team: TeamMatchSupport.cachedTeam()) { changed in
                        // Removed there: nothing left to show
                        if changed == nil { openedTeamMatch = nil }
                    }
                    .toolbar {
                        CloseToolbarItem { openedTeamMatch = nil }
                    }
                }
            }
        }
    }
}
