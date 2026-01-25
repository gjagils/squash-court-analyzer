import SwiftUI

struct AnalysisView: View {
    let game: Game
    let onDismiss: () -> Void

    @State private var selectedPlayer: Player = .player1
    @State private var showingWins: Bool = true // true = wins, false = losses

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    header

                    // Final Score
                    finalScoreCard

                    // Player selector
                    playerSelector

                    // Heatmap toggle
                    heatmapToggle

                    // Heatmap
                    heatmapView

                    // Stats
                    statsCard

                    // Recommendations
                    recommendationsCard

                    // Close button
                    Button(action: onDismiss) {
                        Text("Sluiten")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
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
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .tracking(3)

            if let winner = game.winner {
                Text("\(game.name(for: winner)) wint!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Final Score
    private var finalScoreCard: some View {
        HStack(spacing: 30) {
            VStack {
                Text(game.player1Name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                Text("\(game.player1Score)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Text("-")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white.opacity(0.5))

            VStack {
                Text(game.player2Name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.red)
                Text("\(game.player2Score)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    // MARK: - Player Selector
    private var playerSelector: some View {
        VStack(spacing: 8) {
            Text("Bekijk analyse voor:")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 12) {
                ForEach(Player.allCases) { player in
                    Button(action: { selectedPlayer = player }) {
                        Text(game.name(for: player))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(selectedPlayer == player ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedPlayer == player
                                          ? (player == .player1 ? Color.blue : Color.red)
                                          : Color.white.opacity(0.1))
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
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Punten gewonnen")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(showingWins ? .white : .white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(showingWins ? Color.green.opacity(0.6) : Color.white.opacity(0.1))
                )
            }

            Button(action: { showingWins = false }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Punten verloren")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(!showingWins ? .white : .white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(!showingWins ? Color.red.opacity(0.6) : Color.white.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Heatmap View
    private var heatmapView: some View {
        VStack(spacing: 8) {
            Text(showingWins ? "Waar \(game.name(for: selectedPlayer)) scoorde" : "Waar \(game.name(for: selectedPlayer)) punten verloor")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            HeatmapCourt(
                game: game,
                player: selectedPlayer,
                showingWins: showingWins
            )
            .frame(height: 280)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Stats Card
    private var statsCard: some View {
        VStack(spacing: 12) {
            Text("Statistieken \(game.name(for: selectedPlayer))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 20) {
                StatBox(
                    title: "Gewonnen",
                    value: "\(game.pointsWon(by: selectedPlayer).count)",
                    color: .green
                )

                StatBox(
                    title: "Verloren",
                    value: "\(game.pointsLost(by: selectedPlayer).count)",
                    color: .red
                )

                if let bestZone = game.bestZone(for: selectedPlayer) {
                    StatBox(
                        title: "Beste zone",
                        value: bestZone.shortName,
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    // MARK: - Recommendations Card
    private var recommendationsCard: some View {
        let opponent = selectedPlayer.opponent
        let recommended = game.recommendedZones(against: opponent)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Tactisch advies")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            if recommended.isEmpty {
                Text("Niet genoeg data voor aanbevelingen.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("Speel de bal naar deze zones om \(game.name(for: opponent)) onder druk te zetten:")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 8) {
                    ForEach(recommended) { zone in
                        Text(zone.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.4))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
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

            ZStack {
                // Court background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.3, green: 0.25, blue: 0.2))
                    .frame(width: size.width, height: size.height)

                // Heatmap zones
                heatmapZones(size: size)

                // Court lines
                courtLines(size: size)

                // Zone labels with counts
                zoneLabels(size: size)
            }
            .frame(width: size.width, height: size.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private func heatmapZones(size: CGSize) -> some View {
        let zoneWidth = size.width / 2
        let zoneHeight = size.height / 3

        return ZStack {
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<2, id: \.self) { col in
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
        let lineColor = Color.white.opacity(0.5)

        return ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 4)
                .stroke(lineColor, lineWidth: 2)

            // Vertical center line (bottom half only)
            Path { path in
                path.move(to: CGPoint(x: size.width / 2, y: size.height * 0.56))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            }
            .stroke(lineColor, lineWidth: 1)

            // Horizontal short line
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height * 0.56))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.56))
            }
            .stroke(lineColor, lineWidth: 1)
        }
        .frame(width: size.width, height: size.height)
    }

    private func zoneLabels(size: CGSize) -> some View {
        let zoneWidth = size.width / 2
        let zoneHeight = size.height / 3

        return ZStack {
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<2, id: \.self) { col in
                    let zone = zoneFor(row: row, col: col)
                    let count = showingWins
                        ? game.pointsWon(by: player, in: zone)
                        : game.pointsWon(by: player.opponent, in: zone)

                    VStack(spacing: 2) {
                        Text("\(count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(zone.shortName)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
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
        case (0, 1): return .frontRight
        case (1, 0): return .middleLeft
        case (1, 1): return .middleRight
        case (2, 0): return .backLeft
        case (2, 1): return .backRight
        default: return .middleLeft
        }
    }

    private func intensityFor(count: Int) -> Double {
        // Scale intensity based on count (0 to max in game)
        let maxCount = max(1, CourtZone.allCases.map { zone in
            showingWins
                ? game.pointsWon(by: player, in: zone)
                : game.pointsWon(by: player.opponent, in: zone)
        }.max() ?? 1)

        return count > 0 ? (Double(count) / Double(maxCount)) * 0.7 + 0.1 : 0.05
    }

    private func calculateSize(_ available: CGSize) -> CGSize {
        let widthBasedHeight = available.width / aspectRatio
        let heightBasedWidth = available.height * aspectRatio

        if widthBasedHeight <= available.height {
            return CGSize(width: available.width, height: widthBasedHeight)
        } else {
            return CGSize(width: heightBasedWidth, height: available.height)
        }
    }
}

// MARK: - Preview

#Preview("Analysis View") {
    let game = Game()
    game.player1Name = "Jan"
    game.player2Name = "Piet"
    game.player1Score = 11
    game.player2Score = 8

    // Add some sample points
    game.points = [
        Point(scorer: .player1, zone: .frontLeft, server: .player1, player1Score: 1, player2Score: 0),
        Point(scorer: .player1, zone: .frontLeft, server: .player1, player1Score: 2, player2Score: 0),
        Point(scorer: .player2, zone: .backRight, server: .player1, player1Score: 2, player2Score: 1),
        Point(scorer: .player1, zone: .middleRight, server: .player2, player1Score: 3, player2Score: 1),
        Point(scorer: .player1, zone: .frontRight, server: .player1, player1Score: 4, player2Score: 1),
        Point(scorer: .player2, zone: .middleLeft, server: .player1, player1Score: 4, player2Score: 2),
        Point(scorer: .player1, zone: .backLeft, server: .player2, player1Score: 5, player2Score: 2),
        Point(scorer: .player1, zone: .frontLeft, server: .player1, player1Score: 6, player2Score: 2),
    ]

    return AnalysisView(game: game) { }
}
