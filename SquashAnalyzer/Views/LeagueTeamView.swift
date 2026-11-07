import SwiftUI
import SquashAnalyzerCore
import SquashAnalyzerUI

/// Mijn team on the iOS home screen: the shared card and team screen (as on
/// Android), so the followed team stands out in orange and the standings are
/// fetched only when something can have changed (`LeagueTeamRefresh`).
struct LeagueTeamCard: View {
    /// Opens Instellingen (for the prompt while no team link is saved)
    var onSetup: (() -> Void)? = nil
    /// A team match screen is open: the bar waits and reads again afterwards
    var matchesPaused = false
    /// The bar with today's team match
    var onTeamMatch: (TeamMatch) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @State private var openedTeam: LeagueTeamSnapshot?

    /// As in HomeView: what a team match opened from Mijn team needs
    private var teamMatchTools: TeamMatchTools {
        let players = SwiftDataPlayerStore(context: modelContext)
        return TeamMatchTools(historyStore: SwiftDataMatchHistoryStore(context: modelContext), playerStore: players,
                              coachStore: SwiftDataCoachMatchStore(context: modelContext),
                              refereeStore: SwiftDataRefereeMatchStore(context: modelContext),
                              photoStore: players, filePicker: nil, aiCoach: IOSAICoach.context,
                              shareText: { text in IOSShare.text(text) },
                              leagueFetcher: LeagueTeamService.shared)
    }

    var body: some View {
        SharedLeagueTeamCard(fetcher: LeagueTeamService.shared, onTeam: { snapshot in
            // Once per team link: the players of Mijn team into Spelers, marked "In mijn team"
            let store = SwiftDataPlayerStore(context: modelContext)
            Task { _ = await TeamRosterSync.run(snapshot, store: store) }
        }, onSetup: onSetup, teamMatches: TeamMatchStorage.store, matchesPaused: matchesPaused,
           onTeamMatch: onTeamMatch) { snapshot in
            openedTeam = snapshot
        }
        // A team match may be made or changed in it: the card reads again when it closes
        .sheet(isPresented: Binding(get: { openedTeam != nil }, set: { if !$0 { openedTeam = nil } }),
               onDismiss: { TeamMatchSupport.noteChange() }) {
            if let team = openedTeam {
                NavigationStack {
                    SharedLeagueTeamDetailView(snapshot: team, fetcher: LeagueTeamService.shared,
                                               teamMatches: TeamMatchStorage.store, tools: teamMatchTools)
                        .toolbar { CloseToolbarItem { openedTeam = nil } }
                }
            }
        }
    }
}
