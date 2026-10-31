import SwiftUI
import SquashAnalyzerCore

// MARK: - Zoek je club

/// The team link without copying it from the website: search the club, then
/// tap the team. Shared by the settings of iOS and Android.
public struct LeagueClubFinder: View {
    let fetcher: LeagueTeamFetcher
    let onPick: (LeagueClubTeam) -> Void

    @State private var query = ""
    @State private var clubs: [LeagueClub] = []
    @State private var searched = false
    @State private var club: LeagueClub? = nil
    @State private var teams: [LeagueClubTeam] = []
    @State private var busy = false
    @State private var problem: String? = nil
    /// The team just picked: the list folds away and says so
    @State private var picked: LeagueClubTeam? = nil

    public init(fetcher: LeagueTeamFetcher, onPick: @escaping (LeagueClubTeam) -> Void) {
        self.fetcher = fetcher
        self.onPick = onPick
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let picked {
                HStack(spacing: 8) {
                    Text(loc("Mijn team is nu \(picked.name)"))
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.positive)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(loc("Ander team")) { self.picked = nil }
                        .font(SharedFonts.system(13, weight: .medium))
                        .foregroundColor(SharedColors.accent)
                }
            } else if let club {
                HStack(spacing: 8) {
                    Text(club.name)
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    Button(loc("Andere club")) {
                        self.club = nil
                        teams = []
                        problem = nil
                    }
                    .font(SharedFonts.system(13, weight: .medium))
                    .foregroundColor(SharedColors.accent)
                }
                if busy {
                    ProgressView()
                } else if teams.isEmpty && problem == nil {
                    note(loc("Deze club heeft geen teams in de competitie."))
                } else if !teams.isEmpty {
                    note(loc("Kies je team:"))
                    ForEach(teams) { team in
                        row(team.name, detail: team.division) {
                            picked = team
                            onPick(team)
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    TextField(loc("Clubnaam"), text: $query)
                        .accessibilityLabel(loc("Zoek je club"))
                        .autocorrectionDisabled()
                        .foregroundColor(SharedColors.textPrimary)
                        .padding(12)
                        .background(SharedColors.tint(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .onSubmit { Task { await search() } }
                    ActionButton(loc("Zoek"), style: .filled, color: SharedColors.accent) { Task { await search() } }
                        .frame(width: 96)
                }
                if busy {
                    ProgressView()
                } else if searched && clubs.isEmpty && problem == nil {
                    note(loc("Geen club gevonden. Probeer een deel van de naam."))
                }
                ForEach(clubs) { found in
                    row(found.name, detail: found.place) { Task { await open(found) } }
                }
            }
            if let problem {
                Text(problem)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(SharedFonts.system(12))
            .foregroundColor(SharedColors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SharedFonts.system(14, weight: .medium))
                        .foregroundColor(SharedColors.textPrimary)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textMuted)
                    }
                }
                Spacer()
                AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.tint(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= LeagueTeamFetcher.minimumSearch else {
            problem = loc("Typ minstens 3 letters van de clubnaam.")
            return
        }
        busy = true
        problem = nil
        do {
            clubs = try await fetcher.searchClubs(text)
        } catch {
            clubs = []
            problem = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message
        }
        searched = true
        busy = false
    }

    private func open(_ found: LeagueClub) async {
        club = found
        teams = []
        busy = true
        problem = nil
        do {
            teams = try await fetcher.teams(of: found)
        } catch {
            problem = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message
        }
        busy = false
    }
}
