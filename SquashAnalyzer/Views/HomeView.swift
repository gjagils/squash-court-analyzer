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

    @State private var showingPlayerManagement = false
    @State private var showingBadgeCatalog = false
    @State private var showingCompetition = false
    @Environment(\.modelContext) private var modelContext

    /// Competitie: team matches in one JSON file in Application Support, as on Android
    @MainActor static let teamMatchStore = JSONFileTeamMatchStore(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HomeMenuHeader(onSettings: onOpenSettings)
                    LeagueTeamCard()
                    HomeMenuTiles(
                        onCoach: onCoach,
                        onReferee: onReferee,
                        onHistory: onViewHistory,
                        onPlayers: { showingPlayerManagement = true },
                        onBadges: { showingBadgeCatalog = true },
                        onCompetition: { showingCompetition = true }
                    )
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
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
                SharedTeamMatchesView(store: HomeView.teamMatchStore,
                                      historyStore: SwiftDataMatchHistoryStore(context: modelContext),
                                      team: TeamMatchSupport.cachedTeam(),
                                      shareText: { text in IOSShare.text(text) })
                    .toolbar {
                        CloseToolbarItem { showingCompetition = false }
                    }
            }
        }
    }
}
