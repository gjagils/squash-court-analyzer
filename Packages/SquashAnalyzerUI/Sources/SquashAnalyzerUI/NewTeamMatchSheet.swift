import SwiftUI
import SquashAnalyzerCore

// MARK: - Nieuwe teamwedstrijd

struct NewTeamMatchSheet: View {
    let team: LeagueTeamSnapshot?
    let existing: [TeamMatch]
    let onCreate: (TeamMatch) -> Void
    let onCancel: () -> Void

    @State private var ownTeam = ""
    @State private var opponent = ""
    @State private var atHome = true
    @State private var date = Date()

    /// Matches of Mijn team without a team match yet, nearest to today first
    private var openFixtures: [LeagueFixture] {
        guard let team else { return [] }
        var taken: [String] = []
        for match in existing { if let id = match.fixtureId { taken.append(id) } }
        let now = Date()
        return team.fixtures
            .filter { fixture in !taken.contains(fixture.id) }
            .sorted(by: { a, b in abs(a.date.timeIntervalSince(now)) < abs(b.date.timeIntervalSince(now)) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let team, !openFixtures.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("UIT HET PROGRAMMA VAN \(team.name.uppercased())")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1.4)
                                    .foregroundColor(SharedColors.accent)
                                ForEach(openFixtures) { fixture in
                                    Button { onCreate(TeamMatch.from(fixture: fixture, ownTeam: team.name)) } label: {
                                        HStack(spacing: 10) {
                                            Text(TeamMatchReport.dayText(fixture.date))
                                                .font(.system(size: 11))
                                                .foregroundColor(SharedColors.textMuted)
                                                .frame(width: 70, alignment: .leading)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(fixture.home).foregroundColor(SharedColors.textPrimary)
                                                Text(fixture.away).foregroundColor(SharedColors.textSecondary)
                                            }
                                            .font(.system(size: 13))
                                            Spacer()
                                            AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ZELF INVULLEN")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.4)
                                .foregroundColor(SharedColors.accent)
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Ons team", text: $ownTeam)
                                    .font(.system(size: 14))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                TextField("Tegenstander", text: $opponent)
                                    .font(.system(size: 14))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                Picker("Waar", selection: $atHome) {
                                    Text("Thuis").tag(true)
                                    Text("Uit").tag(false)
                                }
                                .pickerStyle(.segmented)
                                DatePicker("Datum", selection: $date, displayedComponents: .date)
                                    .font(.system(size: 14))
                                    .foregroundColor(SharedColors.textPrimary)
                                ActionButton("Maak teamwedstrijd", style: .filled, disabled: ownTeam.trimmingCharacters(in: .whitespaces).isEmpty || opponent.trimmingCharacters(in: .whitespaces).isEmpty) {
                                    let own = ownTeam.trimmingCharacters(in: .whitespaces)
                                    let other = opponent.trimmingCharacters(in: .whitespaces)
                                    onCreate(TeamMatch(date: date, home: atHome ? own : other, away: atHome ? other : own,
                                                       ownSide: atHome ? TeamSide.home : TeamSide.away))
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                        }
                    }
                    .padding(24)
                }
            }
            .pageTitle("Nieuwe teamwedstrijd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onCancel).foregroundColor(SharedColors.textSecondary)
                }
            }
            .onAppear { if ownTeam.isEmpty, let team { ownTeam = team.name } }
        }
        .preferredColorScheme(.dark)
    }
}
