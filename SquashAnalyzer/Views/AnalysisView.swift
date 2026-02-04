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
                        .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        ZStack {
            // Center content
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

            // Close button (top right)
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
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
        ScoreboardView(game: displayedGame, match: match)
            .padding(.horizontal, 20)
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

            // Row 1: Ace and Stroke (centered)
            HStack(spacing: 10) {
                Spacer()
                shotStatCell(for: .ace)
                shotStatCell(for: .stroke)
                Spacer()
            }

            // Row 2: Drive, Cross, Volley
            HStack(spacing: 10) {
                shotStatCell(for: .drive)
                shotStatCell(for: .cross)
                shotStatCell(for: .volley)
            }

            // Row 3: Drop, Lob, Boast
            HStack(spacing: 10) {
                shotStatCell(for: .drop)
                shotStatCell(for: .lob)
                shotStatCell(for: .boast)
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

    private func shotStatCell(for shotType: ShotType) -> some View {
        let count = displayedGame.pointsWon(by: selectedPlayer, with: shotType)
        return VStack(spacing: 4) {
            ShotIconView(type: shotType, color: count > 0 ? AppColors.accentGold : AppColors.textMuted, size: 20)
                .frame(height: 20)

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

    // MARK: - Stats Card
    private var statsCard: some View {
        let avgWon = displayedGame.averageDurationWon(by: selectedPlayer)
        let avgLost = displayedGame.averageDurationLost(by: selectedPlayer)

        return VStack(spacing: 12) {
            Text("Statistieken")
                .font(AppFonts.label(14))
                .foregroundColor(AppColors.textPrimary)

            // Row 1: Points won/lost
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
            }

            // Row 2: Duration stats
            HStack(spacing: 16) {
                StatBox(
                    title: "Gem. duur gewonnen",
                    value: avgWon != nil ? formatDuration(avgWon!) : "-",
                    color: .green
                )

                StatBox(
                    title: "Gem. duur verloren",
                    value: avgLost != nil ? formatDuration(avgLost!) : "-",
                    color: .red
                )
            }

            // Row 3: Best zone and shot
            HStack(spacing: 16) {
                StatBox(
                    title: "Beste zone",
                    value: displayedGame.bestZone(for: selectedPlayer)?.rawValue ?? "-",
                    color: AppColors.accentGold
                )

                StatBox(
                    title: "Beste slag",
                    value: displayedGame.bestShotType(for: selectedPlayer)?.rawValue ?? "-",
                    color: AppColors.warmOrange
                )
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

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // MARK: - Recommendations Card
    private var recommendationsCard: some View {
        let opponent = selectedPlayer.opponent
        let recommended = displayedGame.recommendedZones(against: opponent)
        let opponentStrongZone = displayedGame.bestZone(for: opponent)

        // Ace statistics
        let myAces = displayedGame.pointsWon(by: selectedPlayer, with: .ace)
        let opponentAces = displayedGame.pointsWon(by: opponent, with: .ace)

        // Let statistics
        let letsAgainstMe = displayedGame.letsRequested(by: opponent).count
        let letsForMe = displayedGame.letsRequested(by: selectedPlayer).count

        // Tempo analysis
        let tempoAdvice = calculateTempoAdvice()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.accentGold)
                Text("Tactisch advies")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Tempo advice
                if let advice = tempoAdvice {
                    adviceRow(icon: advice.icon, text: advice.text, color: advice.color)
                }

                // Ace advice - opponent scoring aces
                if opponentAces >= 2 {
                    adviceRow(
                        icon: "exclamationmark.circle",
                        text: "\(displayedGame.name(for: opponent)) scoort \(opponentAces) aces - werk aan je return",
                        color: .orange
                    )
                }

                // Ace advice - you scoring aces
                if myAces >= 2 {
                    adviceRow(
                        icon: "bolt.fill",
                        text: "Je hebt \(myAces) aces - je service werkt, blijf zo serveren!",
                        color: .green
                    )
                }

                // Let advice - you're blocking
                if letsAgainstMe >= 2 {
                    adviceRow(
                        icon: "figure.walk",
                        text: "\(letsAgainstMe) lets tegen - beweeg sneller weg na je slag",
                        color: .orange
                    )
                }

                // Let advice - you're moving well
                if letsForMe >= 2 && letsAgainstMe < 2 {
                    adviceRow(
                        icon: "figure.run",
                        text: "\(letsForMe) lets mee - je beweegt goed naar de bal",
                        color: .green
                    )
                }

                // Opponent's strong zone warning
                if let zone = opponentStrongZone {
                    adviceRow(
                        icon: "exclamationmark.triangle",
                        text: "Vermijd \(zone.rawValue) - daar is \(displayedGame.name(for: opponent)) sterk",
                        color: .orange
                    )
                }

                // Recommended zones
                if !recommended.isEmpty {
                    adviceRow(
                        icon: "target",
                        text: "Speel naar: \(recommended.map { $0.rawValue }.joined(separator: ", "))",
                        color: .green
                    )
                }

                // Best shot advice
                if let bestShot = displayedGame.bestShotType(for: selectedPlayer) {
                    adviceRow(
                        icon: "star",
                        text: "Je \(bestShot.rawValue) is effectief, blijf dit gebruiken",
                        color: AppColors.steelBlue
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
        .padding(.horizontal, 24)
    }

    private func adviceRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)

            Text(text)
                .font(AppFonts.body(13))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func calculateTempoAdvice() -> (icon: String, text: String, color: Color)? {
        guard displayedGame.points.count >= 4 else { return nil }

        let shortRallyWin = displayedGame.shortRallyWinPercentage(for: selectedPlayer)
        let longRallyWin = displayedGame.longRallyWinPercentage(for: selectedPlayer)

        if let shortWin = shortRallyWin, let longWin = longRallyWin {
            let difference = abs(shortWin - longWin)

            if difference > 15 {
                if shortWin > longWin {
                    return (
                        icon: "hare.fill",
                        text: "Versnel het spel! Je wint \(Int(shortWin))% van korte rally's vs \(Int(longWin))% van lange",
                        color: .green
                    )
                } else {
                    return (
                        icon: "tortoise.fill",
                        text: "Vertraag het spel! Je wint \(Int(longWin))% van lange rally's vs \(Int(shortWin))% van korte",
                        color: .green
                    )
                }
            }
        }

        return nil
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
