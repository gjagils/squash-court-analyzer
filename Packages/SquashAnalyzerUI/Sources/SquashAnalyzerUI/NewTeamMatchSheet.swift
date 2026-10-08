import SwiftUI
import SquashAnalyzerCore

// MARK: - Nieuwe teamwedstrijd

struct NewTeamMatchSheet: View {
    let team: LeagueTeamSnapshot?
    let existing: [TeamMatch]
    /// The new team match and whether it is shared with the team right away
    let onCreate: (TeamMatch, Bool) -> Void
    let onCancel: () -> Void

    @State private var ownTeam = ""
    @State private var opponent = ""
    @State private var atHome = true
    @State private var date = Date()
    /// "Deel met mijn team": on unless switched off
    @State private var shareWithTeam = true

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
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $shareWithTeam) {
                                Text("Deel met mijn team")
                                    .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                                    .foregroundColor(SharedColors.textPrimary)
                            }
                            .tint(SharedColors.accent)
                            Text(shareWithTeam
                                 ? "Teamgenoten zetten hun eigen partij erin en supporters kijken mee. Alleen teamnamen, voornamen en de stand gaan naar de server; 2 uur na de laatste update wordt alles gewist."
                                 : "De teamwedstrijd blijft alleen op deze telefoon. Je kunt hem later nog delen.")
                                .font(SharedFonts.system(11))
                                .foregroundColor(SharedColors.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        if let team, !openFixtures.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader("UIT HET PROGRAMMA VAN \(team.name.uppercased())")
                                ForEach(openFixtures) { fixture in
                                    Button { onCreate(TeamMatch.from(fixture: fixture, ownTeam: team.name), shareWithTeam) } label: {
                                        HStack(spacing: 10) {
                                            Text(TeamMatchReport.dayText(fixture.date))
                                                .font(SharedFonts.system(11))
                                                .foregroundColor(SharedColors.textMuted)
                                                .frame(width: 70, alignment: .leading)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(fixture.home).foregroundColor(SharedColors.textPrimary)
                                                Text(fixture.away).foregroundColor(SharedColors.textSecondary)
                                            }
                                            .font(SharedFonts.system(13))
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
                            SectionHeader("ZELF INVULLEN")
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Ons team", text: $ownTeam)
                                    .font(SharedFonts.system(14))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                TextField("Tegenstander", text: $opponent)
                                    .font(SharedFonts.system(14))
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                Picker("Waar", selection: $atHome) {
                                    Text("Thuis").tag(true)
                                    Text("Uit").tag(false)
                                }
                                .pickerStyle(.segmented)
                                DatePicker("Datum", selection: $date, displayedComponents: .date)
                                    .font(SharedFonts.system(14))
                                    .foregroundColor(SharedColors.textPrimary)
                                ActionButton("Maak teamwedstrijd", style: .filled, disabled: ownTeam.trimmingCharacters(in: .whitespaces).isEmpty || opponent.trimmingCharacters(in: .whitespaces).isEmpty) {
                                    let own = ownTeam.trimmingCharacters(in: .whitespaces)
                                    let other = opponent.trimmingCharacters(in: .whitespaces)
                                    onCreate(TeamMatch(date: date, home: atHome ? own : other, away: atHome ? other : own,
                                                       ownSide: atHome ? TeamSide.home : TeamSide.away), shareWithTeam)
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
                    CloseButton(title: "Annuleren", action: onCancel)
                }
            }
            .onAppear { if ownTeam.isEmpty, let team { ownTeam = team.name } }
        }
        .preferredColorScheme(.dark)
    }
}
