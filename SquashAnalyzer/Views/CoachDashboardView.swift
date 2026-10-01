import SwiftUI
import SquashAnalyzerCore

/// Compact coach dashboard with local + AI-powered tactical advice
struct CoachDashboardView: View {
    let initialGame: Game
    var match: Match? = nil
    let onDismiss: () -> Void

    @State private var selectedPlayer: Player = .player1
    @State private var selectedGameIndex: Int = 0
    @State private var isLoadingAI = false
    @State private var aiAdvice: TacticalAdvice? = nil
    @State private var aiError: String? = nil
    @State private var shareItemsToShow: ShareItemsWrapper? = nil

    private var availableGames: [Game] {
        guard let match = match else { return [initialGame] }
        return match.games.filter { $0.isGameOver || $0 === initialGame }
    }

    private var game: Game {
        let games = availableGames
        guard selectedGameIndex < games.count else { return initialGame }
        return games[selectedGameIndex]
    }

    init(game: Game, match: Match? = nil, onDismiss: @escaping () -> Void) {
        self.initialGame = game
        self.match = match
        self.onDismiss = onDismiss
        // Default to the initial game's index
        if let match = match {
            let games = match.games.filter { $0.isGameOver || $0 === game }
            let idx = games.firstIndex(where: { $0 === game }) ?? games.count - 1
            _selectedGameIndex = State(initialValue: idx)
        }
    }

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

                    // Score Card (tap player to select)
                    scoreCard

                    // Game Selector (when multiple games)
                    if availableGames.count > 1 {
                        gameSelector
                    }

                    // Quick Stats Row
                    quickStatsRow

                    // Mini Heatmap + Shot Distribution (equal heights)
                    HStack(alignment: .top, spacing: 12) {
                        miniHeatmap
                            .frame(maxHeight: .infinity)
                        shotDistribution
                            .frame(maxHeight: .infinity)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)

                    // Point Type Breakdown
                    pointTypeCard

                    // Volleys ("Uit de lucht")
                    volleyCard

                    // Local Tactical Advice
                    localAdviceCard

                    // AI Coach Section
                    aiCoachCard

                    // Close Button
                    HardwareButton(
                        title: "Sluiten",
                        subtitle: nil,
                        color: AppColors.textSecondary,
                        style: .outlined
                    ) {
                        onDismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }

        }
        .sheet(item: $shareItemsToShow) { wrapper in
            ShareSheet(items: wrapper.items)
        }
    }

    // MARK: - Header
    private var header: some View {
        ZStack {
            // Center content
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

            // Share button (top left) + Close button (top right)
            HStack {
                Button(action: shareCurrentGame) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.accentGold)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }

    // MARK: - Score Card (with integrated player selector)
    private var scoreCard: some View {
        HStack(spacing: 0) {
            // Player 1 - tappable
            Button(action: { selectedPlayer = .player1 }) {
                VStack(spacing: 4) {
                    Text(game.player1Name)
                        .font(AppFonts.label(12))
                        .foregroundColor(selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.textSecondary)
                        .lineLimit(1)

                    Text("\(game.player1Score)")
                        .font(AppFonts.score(36))
                        .foregroundColor(selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedPlayer == .player1 ? AppColors.warmOrange.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selectedPlayer == .player1 ? AppColors.warmOrange.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Text("-")
                .font(AppFonts.score(36))
                .foregroundColor(AppColors.textMuted)
                .padding(.horizontal, 8)

            // Player 2 - tappable
            Button(action: { selectedPlayer = .player2 }) {
                VStack(spacing: 4) {
                    Text(game.player2Name)
                        .font(AppFonts.label(12))
                        .foregroundColor(selectedPlayer == .player2 ? AppColors.steelBlue : AppColors.textSecondary)
                        .lineLimit(1)

                    Text("\(game.player2Score)")
                        .font(AppFonts.score(36))
                        .foregroundColor(selectedPlayer == .player2 ? AppColors.steelBlue : AppColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedPlayer == .player2 ? AppColors.steelBlue.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selectedPlayer == .player2 ? AppColors.steelBlue.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
    }

    /// Match game number (accounts for games played before tracking started)
    private func gameNumber(of g: Game) -> Int {
        guard let match, let index = match.games.firstIndex(where: { $0 === g }) else { return 1 }
        return match.gameNumber(at: index)
    }

    // MARK: - Game Selector
    private var gameSelector: some View {
        HStack(spacing: 8) {
            ForEach(availableGames.indices, id: \.self) { index in
                let g = availableGames[index]
                Button(action: {
                    withAnimation { selectedGameIndex = index }
                }) {
                    Text("Game \(gameNumber(of: g)) (\(g.player1Score)-\(g.player2Score))")
                        .font(AppFonts.caption(11))
                        .foregroundColor(selectedGameIndex == index ? AppColors.textPrimary : AppColors.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedGameIndex == index ? AppColors.accentGold.opacity(0.3) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedGameIndex == index ? AppColors.accentGold : Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Quick Stats Row
    private var quickStatsRow: some View {
        let avgWon = game.averageDurationWon(by: selectedPlayer)
        let avgLost = game.averageDurationLost(by: selectedPlayer)
        let bestZone = game.bestZone(for: selectedPlayer)
        let bestShot = game.bestShotType(for: selectedPlayer)

        return HStack(spacing: 8) {
            // Duration of won points
            QuickStatBadge(
                icon: "timer",
                value: avgWon != nil ? formatDuration(avgWon!) : "-",
                label: "Gewonnen",
                color: .green
            )
            // Duration of lost points
            QuickStatBadge(
                icon: "timer",
                value: avgLost != nil ? formatDuration(avgLost!) : "-",
                label: "Verloren",
                color: .red
            )
            // Always show best zone (with placeholder if none)
            QuickStatBadge(
                icon: "mappin.circle",
                value: bestZone?.rawValue ?? "-",
                label: "Beste zone",
                color: AppColors.accentGold
            )
            // Always show best shot (with placeholder if none)
            QuickStatBadge(
                icon: bestShot?.icon ?? "star",
                value: bestShot?.rawValue ?? "-",
                label: "Beste slag",
                color: AppColors.warmOrange,
                shotType: bestShot
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 20)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        CoachAdvice.formatDuration(seconds)
    }

    // MARK: - Mini Heatmap
    private var miniHeatmap: some View {
        VStack(spacing: 8) {
            Text("Heatmap")
                .font(AppFonts.caption(10))
                .foregroundColor(AppColors.textMuted)

            // 2×3 or 3×3, as the game was played (`Game.heatmapLayout`)
            let rows = game.heatmapLayout.rows
            VStack(spacing: 2) {
                ForEach(0..<rows.count, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<rows[row].count, id: \.self) { col in
                            let zone = rows[row][col]
                            let count = game.pointsWon(by: selectedPlayer, in: zone)
                            let maxCount = maxPointsInZone()
                            let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0

                            Rectangle()
                                .fill(Color.green.opacity(0.2 + intensity * 0.6))
                                .frame(width: rows[row].count == 2 ? 43 : 28, height: 28)
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

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                ForEach(topShots(), id: \.name) { item in
                    let count = item.count
                    HStack(spacing: 6) {
                        ShotIconView(type: item.shot, color: AppColors.accentGold, size: 14)
                            .frame(width: 14, height: 14)

                        Text(item.name)
                            .font(AppFonts.caption(10))
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        // Mini bar
                        GeometryReader { geo in
                            let maxCount = topShots().map { $0.count }.max() ?? 1
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

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Local Advice Card
    private var localAdviceCard: some View {
        // The rules and wording live in SquashAnalyzerCore (`CoachAdvice`), shared with Android
        let advice = CoachAdvice.local(in: game, for: selectedPlayer)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.accentGold)
                Text("Tactisch Advies")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(advice.indices, id: \.self) { index in
                    let item = advice[index]
                    AdviceRow(icon: Self.icon(for: item.topic), text: item.text, type: Self.type(for: item.tone))
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

    private static func icon(for topic: AdviceTopic) -> String {
        switch topic {
        case .speedUp: return "hare.fill"
        case .slowDown: return "tortoise.fill"
        case .ownErrors, .hurry: return "brain.head.profile"
        case .forcedErrors: return "hand.raised.fill"
        case .letsAgainst: return "figure.walk"
        case .opponentErrors: return "arrow.up.circle"
        case .opponentServicePoints: return "exclamationmark.circle"
        case .ownServicePoints: return "bolt.fill"
        case .letsFor: return "figure.run"
        case .avoidZone: return "exclamationmark.triangle"
        case .playTo: return "target"
        case .bestShot: return "star"
        }
    }

    private static func type(for tone: AdviceTone) -> AdviceRow.AdviceType {
        switch tone {
        case .success: return .success
        case .warning: return .warning
        case .info: return .info
        }
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

    // MARK: - Point Type Breakdown Card
    private var pointTypeCard: some View {
        let winners = game.winners(by: selectedPlayer).count
        let forced = game.forcedErrors(by: selectedPlayer).count
        let freePoints = game.unforcedErrors(by: selectedPlayer).count   // opponent's mistakes → player's free points
        let ownErrors = game.unforcedErrors(by: selectedPlayer.opponent).count  // player's mistakes → opponent's points
        let strokes = game.strokes(by: selectedPlayer).count
        let servicePoints = game.servicePoints(by: selectedPlayer).count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(AppColors.accentGold)
                Text("Puntverdeling")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                PointTypeBadge(label: "Winners", count: winners, color: .green)
                PointTypeBadge(label: "Druk", count: forced, color: AppColors.accentGold)
                PointTypeBadge(label: "Service", count: servicePoints, color: AppColors.warmOrange)
                PointTypeBadge(label: "Cadeautjes", count: freePoints, color: AppColors.steelBlue)
                PointTypeBadge(label: "Eigen fouten", count: ownErrors, color: .red)
                PointTypeBadge(label: "Strokes", count: strokes, color: AppColors.warmRed)
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

    // MARK: - Volley Card
    private var volleyCard: some View {
        let count = game.volleysWon(by: selectedPlayer).count
        return HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.accentGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Uit de lucht")
                    .font(AppFonts.label(13))
                    .foregroundColor(AppColors.textPrimary)
                Text(CoachAdvice.volleyBreakdown(in: game, for: selectedPlayer) ?? "Nog geen volleys")
                    .font(AppFonts.caption(11))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Text("\(count)")
                .font(AppFonts.score(22))
                .foregroundColor(count > 0 ? AppColors.accentGold : AppColors.textMuted)
        }
        .padding()
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

    // MARK: - Helper Functions

    private func maxPointsInZone() -> Int {
        CourtZone.allCases.map { game.pointsWon(by: selectedPlayer, in: $0) }.max() ?? 1
    }

    private func topShots() -> [ShotCount] {
        CoachAdvice.topShots(in: game, for: selectedPlayer)
    }

    private func shareCurrentGame() {
        let text = ExportService.textSummary(from: game)
        shareItemsToShow = ShareItemsWrapper(items: [text])
    }

    private func requestAIAdvice() {
        guard let apiKey = APIKeyManager.shared.openAIAPIKey else { return }

        isLoadingAI = true
        aiError = nil

        Task {
            do {
                let advice = try await OpenAIService.client.advice(
                    for: game,
                    player: selectedPlayer,
                    apiKey: apiKey,
                    coachingFocus: match?.coachingFocus(for: selectedPlayer) ?? []
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
    var shotType: ShotType? = nil

    var body: some View {
        VStack(spacing: 2) {
            if let shot = shotType {
                ShotIconView(type: shot, color: color, size: 14)
                    .frame(height: 14)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }

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

// MARK: - Point Type Badge
struct PointTypeBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(AppFonts.score(20))
                .foregroundColor(color)
            Text(label)
                .font(AppFonts.caption(8))
                .foregroundColor(AppColors.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
