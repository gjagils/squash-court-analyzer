import SwiftUI

struct AnalysisView: View {
    let game: Game
    var match: Match? = nil
    let onDismiss: () -> Void

    @State private var selectedPlayer: Player = .player1
    @State private var showingWins: Bool = true
    @State private var selectedGameIndex: Int = 0

    private var displayedGame: Game {
        if let match = match, selectedGameIndex < match.games.count {
            return match.games[selectedGameIndex]
        }
        return game
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    header

                    // Game selector (if match with multiple games)
                    if let match = match, match.games.count > 1 {
                        gameSelector(match: match)
                    }

                    // Final Score
                    finalScoreCard

                    // Player selector
                    playerSelector

                    // Heatmap toggle
                    heatmapToggle

                    // Heatmap
                    heatmapView

                    // Shot type stats
                    shotTypeStatsCard

                    // Stats
                    statsCard

                    // Recommendations
                    recommendationsCard

                    // Close button
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
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Text("ANALYSE")
                .font(AppFonts.title(24))
                .foregroundColor(AppColors.textPrimary)
                .tracking(4)

            if let winner = displayedGame.winner {
                Text("\(displayedGame.name(for: winner)) wint!")
                    .font(AppFonts.body(16))
                    .foregroundColor(AppColors.accentGold)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Game Selector
    private func gameSelector(match: Match) -> some View {
        VStack(spacing: 8) {
            Text("Selecteer game")
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(match.games.enumerated()), id: \.element.id) { index, g in
                        Button(action: { selectedGameIndex = index }) {
                            VStack(spacing: 4) {
                                Text("Game \(index + 1)")
                                    .font(AppFonts.caption(11))
                                    .foregroundColor(selectedGameIndex == index ? AppColors.textPrimary : AppColors.textMuted)

                                Text("\(g.player1Score)-\(g.player2Score)")
                                    .font(AppFonts.label(14))
                                    .foregroundColor(selectedGameIndex == index ? AppColors.accentGold : AppColors.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedGameIndex == index ? AppColors.warmOrange.opacity(0.2) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedGameIndex == index ? AppColors.warmOrange.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Final Score
    private var finalScoreCard: some View {
        HardwarePanel {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(displayedGame.player1Name.uppercased())
                        .font(AppFonts.caption(12))
                        .foregroundColor(AppColors.warmOrange)
                        .tracking(1)
                    Text("\(displayedGame.player1Score)")
                        .font(AppFonts.score(44))
                        .foregroundColor(AppColors.ledActive)
                }

                LEDColon(size: 44)

                VStack(spacing: 4) {
                    Text(displayedGame.player2Name.uppercased())
                        .font(AppFonts.caption(12))
                        .foregroundColor(AppColors.steelBlue)
                        .tracking(1)
                    Text("\(displayedGame.player2Score)")
                        .font(AppFonts.score(44))
                        .foregroundColor(AppColors.ledActive)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Player Selector
    private var playerSelector: some View {
        VStack(spacing: 8) {
            Text("Bekijk analyse voor:")
                .font(AppFonts.body(13))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 12) {
                ForEach(Player.allCases) { player in
                    Button(action: { selectedPlayer = player }) {
                        Text(displayedGame.name(for: player))
                            .font(AppFonts.label(14))
                            .foregroundColor(selectedPlayer == player ? AppColors.textPrimary : AppColors.textMuted)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
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
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Heatmap Toggle
    private var heatmapToggle: some View {
        HStack(spacing: 12) {
            Button(action: { showingWins = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Gewonnen")
                }
                .font(AppFonts.caption(11))
                .foregroundColor(showingWins ? AppColors.textPrimary : AppColors.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(showingWins ? Color.green.opacity(0.3) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(showingWins ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }

            Button(action: { showingWins = false }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Verloren")
                }
                .font(AppFonts.caption(11))
                .foregroundColor(!showingWins ? AppColors.textPrimary : AppColors.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(!showingWins ? Color.red.opacity(0.3) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(!showingWins ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Heatmap View
    private var heatmapView: some View {
        VStack(spacing: 8) {
            Text(showingWins ? "Waar \(displayedGame.name(for: selectedPlayer)) scoorde" : "Waar \(displayedGame.name(for: selectedPlayer)) punten verloor")
                .font(AppFonts.caption(12))
                .foregroundColor(AppColors.textSecondary)

            HeatmapCourt(
                game: displayedGame,
                player: selectedPlayer,
                showingWins: showingWins
            )
            .frame(height: 280)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Shot Type Stats
    private var shotTypeStatsCard: some View {
        VStack(spacing: 12) {
            Text("Slagen van \(displayedGame.name(for: selectedPlayer))")
                .font(AppFonts.label(14))
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(ShotType.allCases) { shotType in
                    let count = displayedGame.pointsWon(by: selectedPlayer, with: shotType)
                    VStack(spacing: 4) {
                        Image(systemName: shotType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(count > 0 ? AppColors.accentGold : AppColors.textMuted)

                        Text("\(count)")
                            .font(AppFonts.score(20))
                            .foregroundColor(count > 0 ? AppColors.textPrimary : AppColors.textMuted)

                        Text(shotType.rawValue)
                            .font(AppFonts.caption(9))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(count > 0 ? 0.08 : 0.03))
                    )
                }
            }
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
        .padding(.horizontal, 24)
    }

    // MARK: - Stats Card
    private var statsCard: some View {
        VStack(spacing: 12) {
            Text("Statistieken")
                .font(AppFonts.label(14))
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 16) {
                StatBox(
                    title: "Gewonnen",
                    value: "\(displayedGame.pointsWon(by: selectedPlayer).count)",
                    color: .green
                )

                StatBox(
                    title: "Verloren",
                    value: "\(displayedGame.pointsLost(by: selectedPlayer).count)",
                    color: .red
                )

                if let bestZone = displayedGame.bestZone(for: selectedPlayer) {
                    StatBox(
                        title: "Beste zone",
                        value: bestZone.shortName,
                        color: AppColors.accentGold
                    )
                }

                if let bestShot = displayedGame.bestShotType(for: selectedPlayer) {
                    StatBox(
                        title: "Beste slag",
                        value: bestShot.shortName,
                        color: AppColors.warmOrange
                    )
                }
            }
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
        .padding(.horizontal, 24)
    }

    // MARK: - Recommendations Card
    private var recommendationsCard: some View {
        let opponent = selectedPlayer.opponent
        let recommended = displayedGame.recommendedZones(against: opponent)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.accentGold)
                Text("Tactisch advies")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }

            if recommended.isEmpty {
                Text("Niet genoeg data voor aanbevelingen.")
                    .font(AppFonts.body(13))
                    .foregroundColor(AppColors.textMuted)
            } else {
                Text("Speel de bal naar deze zones om \(displayedGame.name(for: opponent)) onder druk te zetten:")
                    .font(AppFonts.body(13))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    ForEach(recommended) { zone in
                        Text(zone.rawValue)
                            .font(AppFonts.caption(11))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.25))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.green.opacity(0.4), lineWidth: 1)
                            )
                    }
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
        .padding(.horizontal, 24)
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.score(22))
                .foregroundColor(color)

            Text(title)
                .font(AppFonts.caption(9))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Heatmap Court

struct HeatmapCourt: View {
    let game: Game
    let player: Player
    let showingWins: Bool

    private let courtWidth: CGFloat = 6.4
    private let courtLength: CGFloat = 9.75

    private var aspectRatio: CGFloat {
        courtWidth / courtLength
    }

    var body: some View {
        GeometryReader { geometry in
            let size = calculateSize(geometry.size)

            HardwarePanel {
                ZStack {
                    // Court background with sand texture
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.courtSandLight, AppColors.courtSand, AppColors.courtSandDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size.width, height: size.height)

                    // Heatmap zones
                    heatmapZones(size: size)

                    // Court lines
                    courtLines(size: size)

                    // Zone labels with counts
                    zoneLabels(size: size)
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
            }
            .frame(width: size.width + 16, height: size.height + 16)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private func heatmapZones(size: CGSize) -> some View {
        let zoneWidth = size.width / 3
        let zoneHeight = size.height / 3

        return ZStack {
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<3, id: \.self) { col in
                    let zone = zoneFor(row: row, col: col)
                    let count = showingWins
                        ? game.pointsWon(by: player, in: zone)
                        : game.pointsWon(by: player.opponent, in: zone)
                    let intensity = intensityFor(count: count)
                    let color = showingWins ? Color.green : Color.red

                    Rectangle()
                        .fill(color.opacity(intensity))
                        .frame(width: zoneWidth - 2, height: zoneHeight - 2)
                        .position(
                            x: CGFloat(col) * zoneWidth + zoneWidth / 2,
                            y: CGFloat(row) * zoneHeight + zoneHeight / 2
                        )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func courtLines(size: CGSize) -> some View {
        let lineColor = AppColors.courtLine

        return ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 4)
                .stroke(lineColor, lineWidth: 2)

            // Vertical center line (bottom half only)
            Path { path in
                path.move(to: CGPoint(x: size.width / 2, y: size.height * 0.56))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            }
            .stroke(lineColor, lineWidth: 1.5)

            // Horizontal short line
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height * 0.56))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.56))
            }
            .stroke(lineColor, lineWidth: 1.5)
        }
        .frame(width: size.width, height: size.height)
    }

    private func zoneLabels(size: CGSize) -> some View {
        let zoneWidth = size.width / 3
        let zoneHeight = size.height / 3

        return ZStack {
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<3, id: \.self) { col in
                    let zone = zoneFor(row: row, col: col)
                    let count = showingWins
                        ? game.pointsWon(by: player, in: zone)
                        : game.pointsWon(by: player.opponent, in: zone)

                    VStack(spacing: 2) {
                        Text("\(count)")
                            .font(AppFonts.score(18))
                            .foregroundColor(AppColors.textPrimary)
                            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)

                        Text(zone.shortName)
                            .font(AppFonts.caption(9))
                            .foregroundColor(AppColors.textPrimary.opacity(0.7))
                            .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)
                    }
                    .position(
                        x: CGFloat(col) * zoneWidth + zoneWidth / 2,
                        y: CGFloat(row) * zoneHeight + zoneHeight / 2
                    )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

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

    private func intensityFor(count: Int) -> Double {
        let maxCount = max(1, CourtZone.allCases.map { zone in
            showingWins
                ? game.pointsWon(by: player, in: zone)
                : game.pointsWon(by: player.opponent, in: zone)
        }.max() ?? 1)

        return count > 0 ? (Double(count) / Double(maxCount)) * 0.6 + 0.15 : 0.05
    }

    private func calculateSize(_ available: CGSize) -> CGSize {
        let adjustedWidth = available.width - 16
        let adjustedHeight = available.height - 16

        let widthBasedHeight = adjustedWidth / aspectRatio
        let heightBasedWidth = adjustedHeight * aspectRatio

        if widthBasedHeight <= adjustedHeight {
            return CGSize(width: adjustedWidth, height: widthBasedHeight)
        } else {
            return CGSize(width: heightBasedWidth, height: adjustedHeight)
        }
    }
}

// MARK: - Preview

#Preview("Analysis View") {
    let game = Game()
    game.player1Name = "Niels"
    game.player2Name = "Paul"
    game.player1Score = 11
    game.player2Score = 8

    // Add some sample points with shot types
    game.points = [
        Point(scorer: .player1, zone: .frontLeft, shotType: .drop, server: .player1, player1Score: 1, player2Score: 0),
        Point(scorer: .player1, zone: .frontMiddle, shotType: .drive, server: .player1, player1Score: 2, player2Score: 0),
        Point(scorer: .player2, zone: .backRight, shotType: .cross, server: .player1, player1Score: 2, player2Score: 1),
        Point(scorer: .player1, zone: .middleMiddle, shotType: .volley, server: .player2, player1Score: 3, player2Score: 1),
        Point(scorer: .player1, zone: .frontRight, shotType: .drop, server: .player1, player1Score: 4, player2Score: 1),
        Point(scorer: .player2, zone: .middleLeft, shotType: .boast, server: .player1, player1Score: 4, player2Score: 2),
        Point(scorer: .player1, zone: .backMiddle, shotType: .lob, server: .player2, player1Score: 5, player2Score: 2),
        Point(scorer: .player1, zone: .frontLeft, shotType: .drive, server: .player1, player1Score: 6, player2Score: 2),
    ]

    return AnalysisView(game: game) { }
}
