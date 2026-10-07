import SwiftUI
import SquashAnalyzerCore

// "Mijn team" on Android: the card on the home screen, the team screen, and
// the settings screen where the team link is entered. iOS has its own
// `LeagueTeamCard` / `LeagueTeamDetailView` (named `Shared...` here so the two
// never collide); both use Core's `LeagueTeamFetcher` and the same storage keys.


enum LeagueDates {
    static func day(_ date: Date) -> String {
        format(date, "EEE d MMM")
    }

    static func time(_ date: Date) -> String {
        format(date, "HH:mm")
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

/// The home-screen card: stand, played and points, and the next match. Shows
/// nothing until a team link is saved in Instellingen; keeps showing the last
/// fetched team when SBN cannot be reached.
public struct SharedLeagueTeamCard: View {
    let fetcher: LeagueTeamFetcher
    let onOpen: (LeagueTeamSnapshot) -> Void

    @AppStorage(LeagueTeamStorage.linkKey) private var teamURL = ""
    @State private var snapshot: LeagueTeamSnapshot?
    @State private var errorMessage: String?
    @State private var loading = false

    public init(fetcher: LeagueTeamFetcher, onOpen: @escaping (LeagueTeamSnapshot) -> Void) {
        self.fetcher = fetcher
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let snapshot {
                Button { onOpen(snapshot) } label: { card(snapshot) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mijn team: \(snapshot.name)")
            } else if !teamURL.isEmpty {
                HStack(spacing: 10) {
                    if loading {
                        ProgressView()
                    }
                    Text(loading ? "Mijn team laden…" : (errorMessage ?? "Team laden niet gelukt"))
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textSecondary)
                    Spacer()
                    if !loading {
                        Button("Opnieuw") { Task { await load() } }
                            .foregroundColor(SharedColors.accent)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(SharedColors.surfaceRaised))
            }
        }
        .padding(.horizontal, 24)
        .task(id: teamURL) { await load() }
    }

    private func card(_ snapshot: LeagueTeamSnapshot) -> some View {
        HomeTeamSummary(snapshot: snapshot)
    }

    private func load() async {
        guard let link = try? LeagueTeamLink(teamURL) else {
            snapshot = nil
            return
        }
        // The saved team (also after "Vernieuwen" in the team screen); another link starts empty
        if let cached = LeagueTeamStorage.cachedSnapshot(for: link) {
            snapshot = cached
        } else if snapshot?.source != link.url {
            snapshot = nil
        }
        // The saved team as long as nothing can have changed (LeagueTeamRefresh)
        guard LeagueTeamRefresh.isDue(snapshot, lastAttempt: LeagueTeamStorage.lastAttempt()) else { return }
        LeagueTeamStorage.noteAttempt()
        loading = true
        errorMessage = nil
        do {
            let result = try await fetcher.fetch(link)
            LeagueTeamStorage.store(result)
            snapshot = result
        } catch {
            errorMessage = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message
        }
        loading = false
    }
}

/// The whole team: standings, matches and players
public struct SharedLeagueTeamDetailView: View {
    @State private var snapshot: LeagueTeamSnapshot
    /// "Vernieuwen" fetches the team now, whatever LeagueTeamRefresh says
    private let fetcher: LeagueTeamFetcher?
    @State private var refreshing = false
    @State private var refreshError: String?

    public init(snapshot: LeagueTeamSnapshot, fetcher: LeagueTeamFetcher? = nil) {
        _snapshot = State(initialValue: snapshot)
        self.fetcher = fetcher
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.name)
                            .font(SharedFonts.system(24, weight: .bold, design: .rounded))
                            .foregroundColor(SharedColors.textPrimary)
                        Text("\(snapshot.division) · \(snapshot.competition)")
                            .font(SharedFonts.system(12))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                    section("STAND") {
                        ForEach(snapshot.standings) { row in
                            let own = isOwnTeam(row)
                            HStack {
                                Text("\(row.rank)")
                                    .foregroundColor(own ? SharedColors.accent : SharedColors.textMuted)
                                    .frame(width: 26, alignment: .leading)
                                Text(row.name)
                                    .foregroundColor(own ? SharedColors.accent : SharedColors.textPrimary)
                                    .fontWeight(own ? .bold : .regular)
                                Spacer()
                                Text("\(row.points) pt")
                                    .foregroundColor(own ? SharedColors.accent : SharedColors.gold)
                                    .fontWeight(own ? .bold : .regular)
                            }
                            .padding(.vertical, 5)
                            // The team you follow stands out: an orange band, as on the home tiles
                            // (every row indented alike; Compose has no negative padding)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(own ? SharedColors.accent.opacity(0.14) : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(own ? SharedColors.accent.opacity(0.5) : Color.clear, lineWidth: 1))
                        }
                    }
                    section("WEDSTRIJDEN") {
                        ForEach(snapshot.fixtures) { fixture in
                            HStack(spacing: 10) {
                                Text(LeagueDates.day(fixture.date))
                                    .font(SharedFonts.system(11))
                                    .foregroundColor(SharedColors.textMuted)
                                    .frame(width: 82, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fixture.home).foregroundColor(SharedColors.textPrimary)
                                    Text(fixture.away).foregroundColor(SharedColors.textSecondary)
                                }
                                Spacer()
                                Text(fixture.score ?? LeagueDates.time(fixture.date))
                                    .foregroundColor(fixture.score == nil ? SharedColors.textMuted : SharedColors.gold)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    section("SPELERS") {
                        ForEach(snapshot.players) { player in
                            HStack {
                                Text(player.name).foregroundColor(SharedColors.textPrimary)
                                Spacer()
                                Text(player.record)
                                    .font(SharedFonts.system(12))
                                    .foregroundColor(SharedColors.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    HStack(spacing: 12) {
                        Text(refreshError ?? "Bijgewerkt: \(LeagueDates.day(snapshot.updatedAt)) \(LeagueDates.time(snapshot.updatedAt))")
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textMuted)
                        Spacer()
                        if fetcher != nil {
                            if refreshing {
                                ProgressView()
                            } else {
                                Button("Vernieuwen") { Task { await refresh() } }
                                    .font(SharedFonts.system(13, weight: .semibold))
                                    .foregroundColor(SharedColors.accent)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .pageTitle("Mijn team")
    }

    private func refresh() async {
        guard let fetcher, let link = try? LeagueTeamLink(snapshot.source.absoluteString) else { return }
        refreshing = true
        refreshError = nil
        LeagueTeamStorage.noteAttempt()
        do {
            let result = try await fetcher.fetch(link)
            LeagueTeamStorage.store(result)
            snapshot = result
        } catch {
            refreshError = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message
        }
        refreshing = false
    }

    /// The followed team's row: same team page, or else the same name
    private func isOwnTeam(_ row: LeagueStanding) -> Bool {
        row.id == snapshot.source.path || row.name == snapshot.name
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
    }
}
