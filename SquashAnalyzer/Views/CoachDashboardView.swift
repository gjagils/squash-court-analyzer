import SwiftUI

/// Compact coach dashboard with local + AI-powered tactical advice
struct CoachDashboardView: View {
    let game: Game
    var match: Match? = nil
    let onDismiss: () -> Void

    @State private var selectedPlayer: Player = .player1
    @State private var isLoadingAI = false
    @State private var aiAdvice: TacticalAdvice? = nil
    @State private var aiError: String? = nil
    @State private var showingDetailedAnalysis = false

    private var hasAIKey: Bool {
        APIKeyManager.shared.hasOpenAIKey
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    header

                    // Score Card
                    scoreCard

                    // Player Selector
                    playerSelector

                    // Quick Stats Row
                    quickStatsRow

                    // Mini Heatmap + Shot Distribution
                    HStack(spacing: 12) {
                        miniHeatmap
                        shotDistribution
                    }
                    .padding(.horizontal, 20)

                    // Local Tactical Advice
                    localAdviceCard

                    // AI Coach Section
                    aiCoachCard

                    // Detailed Analysis Button
                    Button(action: { showingDetailedAnalysis = true }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Gedetailleerde Analyse")
                        }
                        .font(AppFonts.label(14))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .padding(.horizontal, 20)

                    // Close Button
                    HardwareButton(
                        title: "Sluiten",
                        subtitle: nil,
                        color: AppColors.steelBlue,
                        colorDark: AppColors.steelBlueDark
                    ) {
                        onDismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }

            // Detailed Analysis Sheet
            if showingDetailedAnalysis {
                AnalysisView(game: game, match: match) {
                    showingDetailedAnalysis = false
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingDetailedAnalysis)
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(AppColors.accentGold)
                Text("COACH DASHBOARD")
                    .font(AppFonts.title(20))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(3)
            }

            if let winner = game.winner {
                Text("\(game.name(for: winner)) wint!")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.accentGold)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Score Card
    private var scoreCard: some View {
        HStack(spacing: 0) {
            // Player 1
            VStack(spacing: 4) {
                Text(game.player1Name)
                    .font(AppFonts.label(12))
                    .foregroundColor(game.winner == .player1 ? AppColors.warmOrange : AppColors.textSecondary)
                    .lineLimit(1)

                Text("\(game.player1Score)")
                    .font(AppFonts.score(36))
                    .foregroundColor(game.winner == .player1 ? AppColors.warmOrange : AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)

            Text("-")
                .font(AppFonts.score(36))
                .foregroundColor(AppColors.textMuted)

            // Player 2
            VStack(spacing: 4) {
                Text(game.player2Name)
                    .font(AppFonts.label(12))
                    .foregroundColor(game.winner == .player2 ? AppColors.steelBlue : AppColors.textSecondary)
                    .lineLimit(1)

                Text("\(game.player2Score)")
                    .font(AppFonts.score(36))
                    .foregroundColor(game.winner == .player2 ? AppColors.steelBlue : AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Player Selector
    private var playerSelector: some View {
        HStack(spacing: 12) {
            ForEach(Player.allCases) { player in
                Button(action: { selectedPlayer = player }) {
                    Text(game.name(for: player))
                        .font(AppFonts.label(13))
                        .foregroundColor(selectedPlayer == player ? AppColors.textPrimary : AppColors.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPlayer == player
                                      ? (player == .player1 ? AppColors.warmOrange.opacity(0.3) : AppColors.steelBlue.opacity(0.3))
                                      : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedPlayer == player
                                        ? (player == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
                                        : Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Quick Stats Row
    private var quickStatsRow: some View {
        let won = game.pointsWon(by: selectedPlayer).count
        let lost = game.pointsLost(by: selectedPlayer).count
        let bestZone = game.bestZone(for: selectedPlayer)
        let bestShot = game.bestShotType(for: selectedPlayer)

        return HStack(spacing: 8) {
            QuickStatBadge(icon: "checkmark.circle", value: "\(won)", label: "Gewonnen", color: .green)
            QuickStatBadge(icon: "xmark.circle", value: "\(lost)", label: "Verloren", color: .red)
            if let zone = bestZone {
                QuickStatBadge(icon: "mappin.circle", value: zone.rawValue, label: "Beste zone", color: AppColors.accentGold)
            }
            if let shot = bestShot {
                QuickStatBadge(icon: shot.icon, value: shot.rawValue, label: "Beste slag", color: AppColors.warmOrange)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Mini Heatmap
    private var miniHeatmap: some View {
        VStack(spacing: 8) {
            Text("Heatmap")
                .font(AppFonts.caption(10))
                .foregroundColor(AppColors.textMuted)

            // 3x3 Mini Grid
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { col in
                            let zone = zoneFor(row: row, col: col)
                            let count = game.pointsWon(by: selectedPlayer, in: zone)
                            let maxCount = maxPointsInZone()
                            let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0

                            Rectangle()
                                .fill(Color.green.opacity(0.2 + intensity * 0.6))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text("\(count)")
                                        .font(AppFonts.caption(10))
                                        .foregroundColor(AppColors.textPrimary)
                                )
                        }
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.courtSand.opacity(0.3))
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Shot Distribution
    private var shotDistribution: some View {
        VStack(spacing: 8) {
            Text("Slagen")
                .font(AppFonts.caption(10))
                .foregroundColor(AppColors.textMuted)

            VStack(spacing: 4) {
                ForEach(topShots(), id: \.0.id) { shot, count in
                    HStack(spacing: 6) {
                        Image(systemName: shot.icon)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accentGold)
                            .frame(width: 14)

                        Text(shot.rawValue)
                            .font(AppFonts.caption(10))
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        // Mini bar
                        GeometryReader { geo in
                            let maxCount = topShots().map { $0.1 }.max() ?? 1
                            let width = CGFloat(count) / CGFloat(maxCount) * geo.size.width

                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.accentGold.opacity(0.6))
                                .frame(width: max(width, 4), height: 8)
                        }
                        .frame(width: 40, height: 8)

                        Text("\(count)")
                            .font(AppFonts.caption(10))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 16, alignment: .trailing)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Local Advice Card
    private var localAdviceCard: some View {
        let opponent = selectedPlayer.opponent
        let recommended = game.recommendedZones(against: opponent)
        let weakZone = game.bestZone(for: opponent)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.accentGold)
                Text("Tactisch Advies")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let zone = weakZone {
                    AdviceRow(
                        icon: "target",
                        text: "Speel naar \(zone.rawValue) - daar scoort \(game.name(for: opponent)) vaak",
                        type: .warning
                    )
                }

                if !recommended.isEmpty {
                    AdviceRow(
                        icon: "checkmark.seal",
                        text: "Aanbevolen zones: \(recommended.map { $0.rawValue }.joined(separator: ", "))",
                        type: .success
                    )
                }

                if let bestShot = game.bestShotType(for: selectedPlayer) {
                    AdviceRow(
                        icon: "star",
                        text: "Je \(bestShot.rawValue) werkt goed, blijf variëren",
                        type: .info
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - AI Coach Card
    private var aiCoachCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(AppColors.steelBlue)
                Text("AI Coach")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if !hasAIKey {
                    Text("API key vereist")
                        .font(AppFonts.caption(10))
                        .foregroundColor(AppColors.textMuted)
                }
            }

            if let advice = aiAdvice {
                // Show AI advice
                VStack(alignment: .leading, spacing: 10) {
                    Text(advice.samenvatting)
                        .font(AppFonts.body(13))
                        .foregroundColor(AppColors.textSecondary)

                    if !advice.sterktePunten.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sterke punten:")
                                .font(AppFonts.caption(11))
                                .foregroundColor(Color.green)

                            ForEach(advice.sterktePunten, id: \.self) { punt in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                    Text(punt)
                                }
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    if !advice.werkPunten.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Werkpunten:")
                                .font(AppFonts.caption(11))
                                .foregroundColor(Color.orange)

                            ForEach(advice.werkPunten, id: \.self) { punt in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                    Text(punt)
                                }
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    // Focus box
                    HStack {
                        Image(systemName: "scope")
                            .foregroundColor(AppColors.accentGold)
                        Text(advice.focusVolgendeGame)
                            .font(AppFonts.body(12))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.accentGold.opacity(0.15))
                    )
                }
            } else if let error = aiError {
                // Show error
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(AppFonts.caption(12))
                        .foregroundColor(AppColors.textMuted)
                }
            } else if isLoadingAI {
                // Loading state
                HStack {
                    ProgressView()
                        .tint(AppColors.steelBlue)
                    Text("AI analyseert je game...")
                        .font(AppFonts.body(13))
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                // Show button to request AI advice
                Button(action: requestAIAdvice) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(hasAIKey ? "Vraag AI Coach om advies" : "Configureer API key in instellingen")
                    }
                    .font(AppFonts.label(13))
                    .foregroundColor(hasAIKey ? AppColors.steelBlue : AppColors.textMuted)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(hasAIKey ? AppColors.steelBlue.opacity(0.2) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hasAIKey ? AppColors.steelBlue.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .disabled(!hasAIKey)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.steelBlue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Helper Functions

    private func zoneFor(row: Int, col: Int) -> CourtZone {
        switch (row, col) {
        case (0, 0): return .frontLeft
        case (0, 1): return .frontMiddle
        case (0, 2): return .frontRight
        case (1, 0): return .middleLeft
        case (1, 1): return .middleMiddle
        case (1, 2): return .middleRight
        case (2, 0): return .backLeft
        case (2, 1): return .backMiddle
        case (2, 2): return .backRight
        default: return .middleMiddle
        }
    }

    private func maxPointsInZone() -> Int {
        CourtZone.allCases.map { game.pointsWon(by: selectedPlayer, in: $0) }.max() ?? 1
    }

    private func topShots() -> [(ShotType, Int)] {
        ShotType.allCases
            .map { ($0, game.pointsWon(by: selectedPlayer, with: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { ($0.0, $0.1) }
    }

    private func requestAIAdvice() {
        guard let apiKey = APIKeyManager.shared.openAIAPIKey else { return }

        isLoadingAI = true
        aiError = nil

        Task {
            do {
                let advice = try await OpenAIService.shared.generateTacticalAdvice(
                    for: game,
                    player: selectedPlayer,
                    apiKey: apiKey
                )
                await MainActor.run {
                    self.aiAdvice = advice
                    self.isLoadingAI = false
                }
            } catch {
                await MainActor.run {
                    self.aiError = error.localizedDescription
                    self.isLoadingAI = false
                }
            }
        }
    }
}

// MARK: - Quick Stat Badge
struct QuickStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(value)
                .font(AppFonts.score(16))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(AppFonts.caption(8))
                .foregroundColor(AppColors.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Advice Row
struct AdviceRow: View {
    enum AdviceType {
        case success, warning, info

        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .info: return AppColors.steelBlue
            }
        }
    }

    let icon: String
    let text: String
    let type: AdviceType

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(type.color)
                .frame(width: 16)

            Text(text)
                .font(AppFonts.body(12))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Preview
#Preview {
    let game = Game()
    game.player1Name = "Niels"
    game.player2Name = "Paul"
    game.player1Score = 11
    game.player2Score = 8
    game.points = [
        Point(scorer: .player1, zone: .frontLeft, shotType: .drop, server: .player1, player1Score: 1, player2Score: 0),
        Point(scorer: .player1, zone: .frontMiddle, shotType: .drive, server: .player1, player1Score: 2, player2Score: 0),
        Point(scorer: .player2, zone: .backRight, shotType: .cross, server: .player1, player1Score: 2, player2Score: 1),
        Point(scorer: .player1, zone: .middleMiddle, shotType: .volley, server: .player2, player1Score: 3, player2Score: 1),
    ]

    return CoachDashboardView(game: game) { }
}
