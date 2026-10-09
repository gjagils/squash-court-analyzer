import SwiftUI
import SquashAnalyzerCore

/// Spelersprofiel: how a player does over their matches (Core's
/// `PlayerTrendSummary`), on iOS and Android. Reached from the player's badge
/// screen. Cards in rows, no LazyVGrid (on Android that becomes a scroll
/// area of its own); the lines are drawn with `Path`, as the court is.
public struct SharedPlayerTrendView: View {
    let playerId: String
    let playerName: String
    let photo: Data?
    let historyStore: any MatchHistoryStore

    @State private var matches: [PlayerTrendMatch] = []
    @State private var period = PlayerTrendPeriod.last10
    @State private var isLoading = true
    @State private var loadFailed = false

    public init(playerId: String, playerName: String, photo: Data? = nil, historyStore: any MatchHistoryStore) {
        self.playerId = playerId
        self.playerName = playerName
        self.photo = photo
        self.historyStore = historyStore
    }

    private var summary: PlayerTrendSummary { PlayerTrendSummary(from: matches, period: period) }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            if isLoading {
                ProgressView("Profiel laden…").foregroundColor(SharedColors.textPrimary)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("De wedstrijden konden niet worden geladen.")
                        .foregroundColor(SharedColors.textSecondary)
                    Button("Opnieuw laden") { Task { await load() } }
                        .tint(SharedColors.gold)
                }
            } else {
                content(summary)
            }
        }
        .pageTitle("Profiel")
        .task { await load() }
    }

    private func content(_ summary: PlayerTrendSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(summary)
                if matches.isEmpty {
                    Text("Nog geen wedstrijden van \(playerName). Kies \(playerName) via Kies speler bij een coach- of scheidsrechterwedstrijd, dan komt die hier.")
                        .font(SharedFonts.system(14))
                        .foregroundColor(SharedColors.textSecondary)
                } else {
                    Picker("Periode", selection: $period) {
                        Text(PlayerTrendPeriod.last10.title).tag(PlayerTrendPeriod.last10)
                        Text(PlayerTrendPeriod.last25.title).tag(PlayerTrendPeriod.last25)
                        Text(PlayerTrendPeriod.all.title).tag(PlayerTrendPeriod.all)
                    }
                    .pickerStyle(.segmented)
                    formCard(summary)
                    if summary.coachMatches.isEmpty {
                        card("COACHWEDSTRIJDEN", icon: "chart.bar.fill") {
                            Text("Winners, slagen, baan en tempo komen uit coachwedstrijden, waar elk punt wordt bijgehouden. In deze periode is er geen.")
                                .font(SharedFonts.system(13))
                                .foregroundColor(SharedColors.textSecondary)
                        }
                    } else {
                        linesCard(summary)
                        shotsCard(summary)
                        courtCard(summary)
                        tempoCard(summary)
                    }
                    opponentsCard(summary)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
    }

    // MARK: Kop

    private func header(_ summary: PlayerTrendSummary) -> some View {
        HStack(spacing: 14) {
            PlayerPhotoView(photo: photo, name: playerName, size: 56, color: SharedColors.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text(playerName)
                    .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(headerLine(summary))
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func headerLine(_ summary: PlayerTrendSummary) -> String {
        let count = summary.played == 1 ? "1 wedstrijd" : "\(summary.played) wedstrijden"
        guard let percentage = summary.winPercentage else { return count }
        return "\(count) · \(percentage)% gewonnen"
    }

    // MARK: Kaarten

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                AppSymbol(icon, size: 13, color: SharedColors.gold)
                Text(title)
                    .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(SharedColors.textMuted)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formCard(_ summary: PlayerTrendSummary) -> some View {
        card("VORM", icon: "flag.checkered") {
            if summary.form.isEmpty {
                Text("Nog geen beslissing in deze periode.")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
            } else {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(0..<summary.form.count, id: \.self) { index in
                        let match = summary.form[index]
                        VStack(spacing: 4) {
                            Text(match.won == true ? "W" : "V")
                                .font(SharedFonts.system(12, weight: .bold, design: .rounded))
                                .foregroundColor(match.won == true ? SharedColors.background : SharedColors.textSecondary)
                                .frame(width: 26, height: 26)
                                .background(match.won == true ? SharedColors.accent : SharedColors.surfaceRaised)
                                .clipShape(Circle())
                            Text("\(match.ownGames)-\(match.theirGames)")
                                .font(SharedFonts.system(10, design: .rounded))
                                .foregroundColor(SharedColors.textMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(match.won == true ? "Gewonnen" : "Verloren") \(match.ownGames)-\(match.theirGames) van \(match.opponentName)")
                    }
                }
                Text("Oudste links, nieuwste rechts. Coach- en scheidsrechterwedstrijden tellen mee.")
                    .font(SharedFonts.system(11))
                    .foregroundColor(SharedColors.textMuted)
            }
        }
    }

    private func linesCard(_ summary: PlayerTrendSummary) -> some View {
        let winners = summary.winnersPerGame
        let errors = summary.errorsPerGame
        return card("WINNERS EN FOUTEN PER GAME", icon: "chart.bar.xaxis") {
            TrendLines(first: winners, second: errors, firstColor: SharedColors.positive, secondColor: SharedColors.error)
                .frame(height: 110)
            HStack(spacing: 14) {
                legend("Winners", SharedColors.positive)
                legend("Unforced errors", SharedColors.error)
            }
            if let change = PlayerTrendSummary.change(errors) {
                trendLine("Fouten per game: \(change.text)", better: change.to < change.from)
            }
            if let change = PlayerTrendSummary.change(winners) {
                trendLine("Winners per game: \(change.text)", better: change.to > change.from)
            }
            if winners.count < PlayerTrendSummary.minimumForChange {
                Text("Vanaf \(PlayerTrendSummary.minimumForChange) coachwedstrijden zie je hier of het beter gaat.")
                    .font(SharedFonts.system(11))
                    .foregroundColor(SharedColors.textMuted)
            }
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(SharedFonts.system(11))
                .foregroundColor(SharedColors.textSecondary)
        }
    }

    private func trendLine(_ text: String, better: Bool) -> some View {
        Text(text)
            .font(SharedFonts.system(13, weight: .semibold))
            .foregroundColor(better ? SharedColors.positive : SharedColors.textPrimary)
    }

    private func shotsCard(_ summary: PlayerTrendSummary) -> some View {
        card("SLAGEN", icon: "target") {
            if summary.topShots.isEmpty {
                Text("Nog geen punten met een slag gewonnen.")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
            } else {
                ForEach(0..<summary.topShots.count, id: \.self) { index in
                    shotRow(summary.topShots[index], most: summary.topShots[0].count)
                }
            }
            if let error = summary.commonError {
                Text("Meeste eigen fouten: \(error.title.lowercased()) (\(summary.commonErrorCount)×)")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
            }
        }
    }

    private func shotRow(_ item: PlayerTrendShot, most: Int) -> some View {
        HStack(spacing: 10) {
            AppSymbol(item.shot.icon, size: 14, color: SharedColors.gold)
                .frame(width: 20)
            Text(item.shot.rawValue)
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geometry in
                SharedColors.gold.opacity(0.7)
                    .frame(width: max(4.0, geometry.size.width * Double(item.count) / Double(max(1, most))), height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 16)
            Text("\(item.percentage)%")
                .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                .foregroundColor(SharedColors.textSecondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func courtCard(_ summary: PlayerTrendSummary) -> some View {
        card("BAAN", icon: "scope") {
            ZoneProfileTable(profile: summary.zones)
            if let strong = summary.strongestArea {
                Text("Wint de meeste punten \(strong).")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.positive)
            }
            if let weak = summary.weakestArea {
                Text("Verliest de meeste punten \(weak).")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.accent)
            }
        }
    }

    private func tempoCard(_ summary: PlayerTrendSummary) -> some View {
        card("TEMPO", icon: "timer") {
            if summary.averageRallyWon == nil && summary.averageRallyLost == nil {
                Text("Geen getimede rally's: tik op Start bij de eerste service, dan loopt de rallyklok.")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
            } else {
                HStack(spacing: 10) {
                    tempoBox("Gewonnen", summary.averageRallyWon, SharedColors.positive)
                    tempoBox("Verloren", summary.averageRallyLost, SharedColors.accent)
                }
                Text("Gemiddelde rallyduur, inclusief de tijd voor de service.")
                    .font(SharedFonts.system(11))
                    .foregroundColor(SharedColors.textMuted)
            }
        }
    }

    private func tempoBox(_ title: String, _ seconds: Double?, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(TrendLines.secondsText(seconds))
                .font(SharedFonts.system(22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(SharedFonts.system(11))
                .foregroundColor(SharedColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func opponentsCard(_ summary: PlayerTrendSummary) -> some View {
        card("TEGENSTANDERS", icon: "person.2.circle") {
            if summary.opponents.isEmpty {
                Text("Nog geen beslissing in deze periode.")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
            } else {
                ForEach(0..<summary.opponents.count, id: \.self) { index in
                    let opponent = summary.opponents[index]
                    HStack {
                        Text(opponent.name)
                            .font(SharedFonts.system(14, weight: .semibold))
                            .foregroundColor(SharedColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(opponent.won)-\(opponent.lost)")
                            .font(SharedFonts.system(14, weight: .semibold, design: .rounded))
                            .foregroundColor(opponent.won >= opponent.lost ? SharedColors.positive : SharedColors.accent)
                    }
                    .accessibilityLabel("Tegen \(opponent.name) \(opponent.won) gewonnen, \(opponent.lost) verloren")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        do {
            matches = try await historyStore.trendMatches(forPlayer: playerId)
            loadFailed = false
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}

/// Two lines over the matches, on a shared scale from 0
struct TrendLines: View {
    /// "12 s", or "–" without a value
    static func secondsText(_ seconds: Double?) -> String {
        guard let seconds else { return "–" }
        let whole = Int(seconds + 0.5)
        return "\(whole) s"
    }

    let first: [Double]
    let second: [Double]
    let firstColor: Color
    let secondColor: Color

    private var top: Double {
        var most = 1.0
        for value in first { most = max(most, value) }
        for value in second { most = max(most, value) }
        return most
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Baseline
                Path { path in
                    path.move(to: CGPoint(x: 0.0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                }
                .stroke(SharedColors.textMuted.opacity(0.5), lineWidth: 1)
                line(first, in: geometry.size).stroke(firstColor, lineWidth: 2)
                line(second, in: geometry.size).stroke(secondColor, lineWidth: 2)
            }
        }
        .accessibilityHidden(true)
    }

    private func line(_ values: [Double], in size: CGSize) -> Path {
        Path { path in
            guard !values.isEmpty else { return }
            let step = values.count > 1 ? size.width / Double(values.count - 1) : 0.0
            for (index, value) in values.enumerated() {
                let x = values.count > 1 ? Double(index) * step : size.width / 2.0
                let y = size.height - (value / top) * (size.height - 4.0)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            if values.count == 1 {
                path.addLine(to: CGPoint(x: size.width / 2.0 + 1.0, y: size.height - (values[0] / top) * (size.height - 4.0)))
            }
        }
    }
}
