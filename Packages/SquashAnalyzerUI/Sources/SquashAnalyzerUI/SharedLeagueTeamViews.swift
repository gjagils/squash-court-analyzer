import SwiftUI
import SquashAnalyzerCore

// "Mijn team" on Android: the card on the home screen, the team screen, and
// the settings screen where the team link is entered. iOS has its own
// `LeagueTeamCard` / `LeagueTeamDetailView` (named `Shared...` here so the two
// never collide); both use Core's `LeagueTeamFetcher` and the same storage keys.

enum LeaguePalette {
    static let orange = Color(red: 0.96, green: 0.55, blue: 0.20)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let secondary = Color(red: 0.75, green: 0.73, blue: 0.70)
    static let muted = Color(red: 0.55, green: 0.53, blue: 0.50)
    static let card = Color(red: 0.14, green: 0.12, blue: 0.10)
    static let background = Color(red: 0.06, green: 0.05, blue: 0.04)
}

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
                        .font(.system(size: 12))
                        .foregroundColor(LeaguePalette.secondary)
                    Spacer()
                    if !loading {
                        Button("Opnieuw") { Task { await load() } }
                            .foregroundColor(LeaguePalette.orange)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(LeaguePalette.card))
            }
        }
        .padding(.horizontal, 24)
        .task(id: teamURL) { await load() }
    }

    private func card(_ snapshot: LeagueTeamSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HomeTileIconView(icon: .players, color: LeaguePalette.orange, size: 16)
                Text("MIJN TEAM")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(LeaguePalette.orange)
            Text(snapshot.name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(LeaguePalette.text)
                .lineLimit(1)
            HStack(spacing: 20) {
                stat("STAND", snapshot.rank)
                stat("GESPEELD", snapshot.played)
                stat("PUNTEN", snapshot.points)
            }
            if let next = snapshot.nextFixture() {
                Text("Volgende · \(LeagueDates.day(next.date)) · \(next.home) – \(next.away)")
                    .font(.system(size: 12))
                    .foregroundColor(LeaguePalette.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LeaguePalette.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LeaguePalette.orange.opacity(0.32), lineWidth: 1))
        )
    }

    private func stat(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(LeaguePalette.muted)
            Text(value.map { number in String(number) } ?? "–")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(LeaguePalette.gold)
        }
    }

    private func load() async {
        guard let link = try? LeagueTeamLink(teamURL) else {
            snapshot = nil
            return
        }
        if snapshot?.source != link.url {
            snapshot = LeagueTeamStorage.cachedSnapshot(for: link)
        }
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
    let snapshot: LeagueTeamSnapshot

    public init(snapshot: LeagueTeamSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        ZStack {
            LeaguePalette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(LeaguePalette.text)
                        Text("\(snapshot.division) · \(snapshot.competition)")
                            .font(.system(size: 12))
                            .foregroundColor(LeaguePalette.secondary)
                    }
                    section("STAND") {
                        ForEach(snapshot.standings) { row in
                            HStack {
                                Text("\(row.rank)")
                                    .foregroundColor(row.name == snapshot.name ? LeaguePalette.orange : LeaguePalette.muted)
                                    .frame(width: 26, alignment: .leading)
                                Text(row.name)
                                    .foregroundColor(LeaguePalette.text)
                                    .fontWeight(row.name == snapshot.name ? .bold : .regular)
                                Spacer()
                                Text("\(row.points) pt")
                                    .foregroundColor(LeaguePalette.gold)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    section("WEDSTRIJDEN") {
                        ForEach(snapshot.fixtures) { fixture in
                            HStack(spacing: 10) {
                                Text(LeagueDates.day(fixture.date))
                                    .font(.system(size: 11))
                                    .foregroundColor(LeaguePalette.muted)
                                    .frame(width: 82, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fixture.home).foregroundColor(LeaguePalette.text)
                                    Text(fixture.away).foregroundColor(LeaguePalette.secondary)
                                }
                                Spacer()
                                Text(fixture.score ?? LeagueDates.time(fixture.date))
                                    .foregroundColor(fixture.score == nil ? LeaguePalette.muted : LeaguePalette.gold)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    section("SPELERS") {
                        ForEach(snapshot.players) { player in
                            HStack {
                                Text(player.name).foregroundColor(LeaguePalette.text)
                                Spacer()
                                Text(player.record)
                                    .font(.system(size: 12))
                                    .foregroundColor(LeaguePalette.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Text("Bijgewerkt: \(LeagueDates.day(snapshot.updatedAt)) \(LeagueDates.time(snapshot.updatedAt))")
                        .font(.system(size: 11))
                        .foregroundColor(LeaguePalette.muted)
                }
                .padding(24)
            }
        }
        .navigationTitle("Mijn team")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(LeaguePalette.orange)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
    }
}

/// Android's settings. For now only the Mijn team link; the other iOS settings
/// (AI Coach, input mode, backups) follow later.
public struct SharedSettingsView: View {
    @AppStorage(LeagueTeamStorage.linkKey) private var teamURL = ""
    @State private var draft = ""
    @State private var message: String?
    @State private var messageIsError = false

    public init() {}

    public var body: some View {
        ZStack {
            LeaguePalette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        HomeTileIconView(icon: .players, color: LeaguePalette.orange, size: 20)
                        Text("Mijn team")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LeaguePalette.text)
                    }
                    Text("Vul de openbare teamlink van sbn.toernooi.nl in. Daarna verschijnt Mijn team op het beginscherm.")
                        .font(.system(size: 13))
                        .foregroundColor(LeaguePalette.secondary)
                    TextField("https://sbn.toernooi.nl/league/.../team/...", text: $draft)
                        .accessibilityLabel("Teamlink")
                        // No autocapitalization/URL-keyboard modifiers: this package also builds
                        // for macOS; the link check is case-insensitive where it matters
                        .autocorrectionDisabled()
                        .foregroundColor(LeaguePalette.text)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    HStack(spacing: 12) {
                        Button("Bewaar teamlink") { save() }
                            .buttonStyle(.borderedProminent)
                            .tint(LeaguePalette.orange)
                        if !teamURL.isEmpty {
                            Button("Verwijder") { remove() }
                                .foregroundColor(LeaguePalette.secondary)
                        }
                    }
                    if let message {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(messageIsError ? Color(red: 0.95, green: 0.40, blue: 0.35) : Color(red: 0.45, green: 0.80, blue: 0.45))
                    }
                    Text("Meer instellingen volgen later op Android.")
                        .font(.system(size: 12))
                        .foregroundColor(LeaguePalette.muted)
                        .padding(.top, 12)
                }
                .padding(24)
            }
        }
        .navigationTitle("Instellingen")
        .onAppear { draft = teamURL }
    }

    private func save() {
        do {
            let link = try LeagueTeamLink(draft)
            teamURL = link.url.absoluteString
            draft = teamURL
            message = "Teamlink opgeslagen"
            messageIsError = false
        } catch {
            message = (error as? LeagueTeamError)?.message ?? LeagueTeamError.invalidLink.message
            messageIsError = true
        }
    }

    private func remove() {
        teamURL = ""
        draft = ""
        message = "Teamlink verwijderd"
        messageIsError = false
    }
}
