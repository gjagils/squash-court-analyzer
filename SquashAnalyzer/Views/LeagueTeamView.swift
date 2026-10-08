import SwiftUI
import SquashAnalyzerCore
import SquashAnalyzerUI

/// Mijn team on the iOS home screen: the shared card and team screen (as on
/// Android), so the followed team stands out in orange and the standings are
/// fetched only when something can have changed (`LeagueTeamRefresh`).
struct LeagueTeamCard: View {
    /// Opens Instellingen (for the prompt while no team link is saved)
    var onSetup: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @State private var openedTeam: LeagueTeamSnapshot?

    var body: some View {
        SharedLeagueTeamCard(fetcher: LeagueTeamService.shared, onTeam: { snapshot in
            // Once per team link: the players of Mijn team into Spelers, marked "In mijn team"
            let store = SwiftDataPlayerStore(context: modelContext)
            Task { _ = await TeamRosterSync.run(snapshot, store: store) }
        }, onSetup: onSetup, helpURL: UserManual.iPhoneTeamLink) { snapshot in
            openedTeam = snapshot
        }
        .sheet(isPresented: Binding(get: { openedTeam != nil }, set: { if !$0 { openedTeam = nil } })) {
            if let team = openedTeam {
                NavigationStack {
                    SharedLeagueTeamDetailView(snapshot: team, fetcher: LeagueTeamService.shared)
                        .toolbar { CloseToolbarItem { openedTeam = nil } }
                }
            }
        }
    }
}
