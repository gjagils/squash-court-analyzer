import SwiftUI
import SquashAnalyzerCore

/// "Zoek je club" over Nieuw in 4.0 or Mijn account: search the club, tap the
/// team, and Mijn team is linked. The team's players are fetched at once, so
/// Mijn account can offer them straight after ("Wie ben jij in Mijn team?").
/// New users need the team before the account can choose who they are
/// (Minnie via Gerd-Jan, 25 November 2026). iOS and Android alike.
struct SharedTeamLinkSheet: View {
    let fetcher: LeagueTeamFetcher
    let onClose: () -> Void

    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Mijn team", bundle: textBundle)
                        .font(SharedFonts.system(18, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    Button(loc("Klaar")) { onClose() }
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                Text(loc("Zoek je club en kies je team. Daarna verschijnt Mijn team op het beginscherm."))
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if busy {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(loc("Team ophalen…"))
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                } else {
                    LeagueClubFinder(fetcher: fetcher) { team in link(team) }
                }
            }
            .padding(20)
        }
        .background(SharedColors.background.ignoresSafeArea())
        .appAppearance()
    }

    /// Saved as Instellingen does, then the players fetched; a failed fetch
    /// still keeps the link (the home card tries again)
    private func link(_ team: LeagueClubTeam) {
        UserDefaults.standard.set(team.link.url.absoluteString, forKey: LeagueTeamStorage.linkKey)
        busy = true
        Task {
            if let snapshot = try? await fetcher.fetch(team.link) {
                LeagueTeamStorage.store(snapshot)
            }
            busy = false
            onClose()
        }
    }
}

/// Mijn team is linked (the link saved in Instellingen or here)
func mijnTeamLinked() -> Bool {
    !(UserDefaults.standard.string(forKey: LeagueTeamStorage.linkKey) ?? "").isEmpty
}

/// The name of Mijn team as last fetched; nil without a link or before the first fetch
func mijnTeamName() -> String? {
    let saved = UserDefaults.standard.string(forKey: LeagueTeamStorage.linkKey) ?? ""
    guard !saved.isEmpty, let link = try? LeagueTeamLink(saved) else { return nil }
    return LeagueTeamStorage.cachedSnapshot(for: link)?.name
}
