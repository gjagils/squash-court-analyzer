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
    /// Wedstrijd volgen (live score op het vergrendelscherm)
    var onLiveFollow: () -> Void

    @State private var showingPlayerManagement = false
    @State private var showingBadgeCatalog = false
    @State private var showingCompetition = false
    /// A live team match of the own team is running (LIVE on the Competitie row)
    @State private var competitionLive = false
    @Environment(\.modelContext) private var modelContext


    /// A team match on the server (shared live, or joined with a code) that can
    /// still be live: not finished, and updated within the server's two-hour window
    private static func hasLiveTeamMatch() async -> Bool {
        let matches = (try? await TeamMatchStorage.store.loadAll()) ?? []
        return matches.contains { match in match.isProbablyLive() }
    }

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HomeMenuHeader(onSettings: onOpenSettings)
                    LeagueTeamCard(onSetup: onFindClub)
                    HomeMenuTiles(
                        onCoach: onCoach,
                        onReferee: onReferee,
                        onHistory: onViewHistory,
                        onPlayers: { showingPlayerManagement = true },
                        onBadges: { showingBadgeCatalog = true },
                        onCompetition: { showingCompetition = true },
                        onLiveFollow: onLiveFollow,
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
                let players = SwiftDataPlayerStore(context: modelContext)
                SharedTeamMatchesView(
                    store: TeamMatchStorage.store,
                    tools: TeamMatchTools(historyStore: SwiftDataMatchHistoryStore(context: modelContext), playerStore: players,
                                          coachStore: SwiftDataCoachMatchStore(context: modelContext),
                                          refereeStore: SwiftDataRefereeMatchStore(context: modelContext),
                                          photoStore: players, filePicker: nil, aiCoach: IOSAICoach.context,
                                          shareText: { text in IOSShare.text(text) },
                                          leagueFetcher: LeagueTeamService.shared),
                    team: TeamMatchSupport.cachedTeam())
                    .toolbar {
                        CloseToolbarItem { showingCompetition = false }
                    }
            }
        }
    }
}
