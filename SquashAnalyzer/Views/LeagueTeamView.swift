import SwiftUI
import SquashAnalyzerCore
import SquashAnalyzerUI

struct LeagueTeamCard: View {
    @AppStorage(CoachInputSettings.teamURLKey) private var teamURL = ""
    @State private var snapshot: LeagueTeamSnapshot?
    @State private var errorMessage: String?
    @State private var loading = false
    @State private var showingTeam = false

    var body: some View {
        Group {
            if let snapshot {
                Button { showingTeam = true } label: {
                    HomeTeamSummary(snapshot: snapshot)
                }.buttonStyle(.plain).sheet(isPresented: $showingTeam) { LeagueTeamDetailView(initial: snapshot) }
            } else if !teamURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack { if loading { ProgressView().tint(AppColors.warmOrange) }; Text(loading ? "Mijn team laden…" : (errorMessage ?? "Team laden niet gelukt")).font(AppFonts.caption(12)).foregroundColor(AppColors.textSecondary); Spacer(); if !loading { Button("Opnieuw") { load() }.foregroundColor(AppColors.warmOrange) } }.padding(16)
            }
        }.padding(.horizontal, 24).task(id: teamURL) { load() }
    }
    private func stat(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 2) { Text(title).font(AppFonts.caption(9)).foregroundColor(AppColors.textMuted); Text(value).font(AppFonts.title(16)).foregroundColor(AppColors.accentGold) } }
    private func load() {
        // As on Android: no link, no card; another link shows that team's cache only
        guard let link = try? LeagueTeamLink(teamURL) else { snapshot = nil; return }
        if snapshot?.source != link.url { snapshot = LeagueTeamStorage.cachedSnapshot(for: link) }
        loading = true
        errorMessage = nil
        Task {
            do {
                let result = try await LeagueTeamService.shared.fetch(link)
                LeagueTeamStorage.store(result)
                await MainActor.run { snapshot = result; loading = false }
            } catch { await MainActor.run { errorMessage = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message; loading = false } }
        }
    }
}

struct LeagueTeamDetailView: View {
    let initial: LeagueTeamSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: LeagueTeamSnapshot
    init(initial: LeagueTeamSnapshot) { self.initial = initial; _snapshot = State(initialValue: initial) }
    var body: some View {
        NavigationStack { ZStack { AppBackground(); ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text(snapshot.name).font(AppFonts.title(24)).foregroundColor(AppColors.textPrimary)
            Text("\(snapshot.division) · \(snapshot.competition)").font(AppFonts.caption(12)).foregroundColor(AppColors.textSecondary)
            section("STAND") { ForEach(snapshot.standings) { row in HStack { Text("\(row.rank)").foregroundColor(row.name == snapshot.name ? AppColors.warmOrange : AppColors.textMuted).frame(width: 26); Text(row.name).fontWeight(row.name == snapshot.name ? .bold : .regular).foregroundColor(AppColors.textPrimary); Spacer(); Text("\(row.points) pt").foregroundColor(AppColors.accentGold) }.padding(.vertical, 5) } }
            section("WEDSTRIJDEN") { ForEach(snapshot.fixtures) { fixture in HStack { Text(LeagueDay.text(fixture.date)).font(AppFonts.caption(11)).foregroundColor(AppColors.textMuted).frame(width: 75, alignment: .leading); VStack(alignment: .leading) { Text(fixture.home).foregroundColor(AppColors.textPrimary); Text(fixture.away).foregroundColor(AppColors.textSecondary) }; Spacer(); Text(fixture.score ?? LeagueDay.time(fixture.date)).foregroundColor(fixture.score == nil ? AppColors.textMuted : AppColors.accentGold) }.padding(.vertical, 5) } }
            section("SPELERS") { ForEach(snapshot.players) { player in HStack { Text(player.name).foregroundColor(AppColors.textPrimary); Spacer(); Text(player.record).font(AppFonts.caption(12)).foregroundColor(AppColors.textSecondary) }.padding(.vertical, 4) } }
            Text("Bijgewerkt: \(LeagueDay.text(snapshot.updatedAt)) \(LeagueDay.time(snapshot.updatedAt))").font(AppFonts.caption(11)).foregroundColor(AppColors.textMuted)
        }.padding(24) } }.navigationTitle("Mijn team").navigationBarTitleDisplayMode(.inline)
            .toolbar { CloseToolbarItem { dismiss() } } }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(AppFonts.caption(11)).tracking(1.4).foregroundColor(AppColors.warmOrange); VStack(alignment: .leading) { content() }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))) } }
}

/// Dates as on Android: Dutch "di 3 okt" and "20:15", in Dutch time (SBN's)
enum LeagueDay {
    static func text(_ date: Date) -> String { format(date, "EEE d MMM") }
    static func time(_ date: Date) -> String { format(date, "HH:mm") }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
