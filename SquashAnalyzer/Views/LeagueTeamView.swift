import SwiftUI

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
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Label("MIJN TEAM", systemImage: "person.3.fill").font(AppFonts.caption(11)).tracking(1.4); Spacer(); Image(systemName: "chevron.right") }
                        Text(snapshot.name).font(AppFonts.title(20))
                        HStack(spacing: 16) { stat("STAND", snapshot.rank.map(String.init) ?? "–"); stat("GESPEELD", snapshot.played.map(String.init) ?? "–"); stat("PUNTEN", snapshot.points.map(String.init) ?? "–") }
                        if let next = snapshot.fixtures.first(where: { $0.date >= Date() }) { Text("Volgende · \(next.home) – \(next.away)").font(AppFonts.caption(12)).foregroundColor(AppColors.textSecondary) }
                    }.foregroundColor(AppColors.textPrimary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).sheet(isPresented: $showingTeam) { LeagueTeamDetailView(initial: snapshot) }
            } else if !teamURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack { if loading { ProgressView().tint(AppColors.warmOrange) }; Text(loading ? "Mijn team laden…" : (errorMessage ?? "Team laden niet gelukt")).font(AppFonts.caption(12)).foregroundColor(AppColors.textSecondary); Spacer(); Button("Opnieuw") { load() }.foregroundColor(AppColors.warmOrange) }.padding(16)
            }
        }.background(RoundedRectangle(cornerRadius: 14).fill(AppColors.backgroundMedium)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.warmOrange.opacity(0.32), lineWidth: 1)).padding(.horizontal, 24).task { load() }
    }
    private func stat(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 2) { Text(title).font(AppFonts.caption(9)).foregroundColor(AppColors.textMuted); Text(value).font(AppFonts.title(16)).foregroundColor(AppColors.accentGold) } }
    private func load() {
        if snapshot == nil, let data = UserDefaults.standard.data(forKey: "sbnTeamSnapshot"), let cached = try? JSONDecoder().decode(LeagueTeamSnapshot.self, from: data) { snapshot = cached }
        guard let link = try? LeagueTeamLink(teamURL) else { return }
        loading = true
        errorMessage = nil
        Task {
            do {
                let result = try await LeagueTeamService.shared.fetch(link)
                if let data = try? JSONEncoder().encode(result) { UserDefaults.standard.set(data, forKey: "sbnTeamSnapshot") }
                await MainActor.run { snapshot = result; loading = false }
            } catch { await MainActor.run { errorMessage = error.localizedDescription; loading = false } }
        }
    }
}

struct LeagueTeamDetailView: View {
    let initial: LeagueTeamSnapshot
    @State private var snapshot: LeagueTeamSnapshot
    init(initial: LeagueTeamSnapshot) { self.initial = initial; _snapshot = State(initialValue: initial) }
    var body: some View {
        NavigationStack { ZStack { AppBackground(); ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text(snapshot.name).font(AppFonts.title(24)).foregroundColor(AppColors.textPrimary)
            Text("\(snapshot.division) · \(snapshot.competition)").font(AppFonts.caption(12)).foregroundColor(AppColors.textSecondary)
            section("STAND") { ForEach(snapshot.standings) { row in HStack { Text("\(row.rank)").foregroundColor(row.name == snapshot.name ? AppColors.warmOrange : AppColors.textMuted).frame(width: 26); Text(row.name).foregroundColor(AppColors.textPrimary); Spacer(); Text("\(row.points) pt").foregroundColor(AppColors.accentGold) }.padding(.vertical, 5) } }
            section("WEDSTRIJDEN") { ForEach(snapshot.fixtures) { fixture in HStack { Text(fixture.date, style: .date).font(AppFonts.caption(11)).foregroundColor(AppColors.textMuted).frame(width: 75, alignment: .leading); VStack(alignment: .leading) { Text(fixture.home).foregroundColor(AppColors.textPrimary); Text(fixture.away).foregroundColor(AppColors.textSecondary) }; Spacer(); Text(fixture.score ?? "20:00").foregroundColor(fixture.score == nil ? AppColors.textMuted : AppColors.accentGold) }.padding(.vertical, 5) } }
            section("SPELERS") { ForEach(snapshot.players) { player in HStack { Text(player.name).foregroundColor(AppColors.textPrimary); Spacer(); Text(player.record).font(AppFonts.caption(12)).foregroundColor(AppColors.textSecondary) }.padding(.vertical, 4) } }
            Text("Bijgewerkt: \(snapshot.updatedAt, style: .date)").font(AppFonts.caption(11)).foregroundColor(AppColors.textMuted)
        }.padding(24) } }.navigationTitle("Mijn team").navigationBarTitleDisplayMode(.inline) }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(AppFonts.caption(11)).tracking(1.4).foregroundColor(AppColors.warmOrange); VStack(alignment: .leading) { content() }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))) } }
}
