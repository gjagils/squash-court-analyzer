import SwiftUI

struct ContentView: View {
    @State private var game = Game()

    var body: some View {
        ZStack {
            // Dark background with subtle gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                Text("SQUASH ANALYZER")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(3)
                    .padding(.top, 8)

                // Scoreboard (tennis style - above court)
                ScoreboardView(game: game)
                    .padding(.horizontal, 24)

                // Instruction text
                instructionText
                    .padding(.horizontal, 24)

                // Court view (interactive when player selected)
                CourtView(game: game) { zone in
                    handleZoneTap(zone)
                }
                .padding(.horizontal, 16)

                // Player buttons (below court)
                PlayerButtonsView(game: game) { player in
                    handlePlayerSelect(player)
                }
                .padding(.horizontal, 24)

                // Reset button (small, at bottom)
                if game.player1Score > 0 || game.player2Score > 0 {
                    Button(action: {
                        withAnimation {
                            game.reset()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Nieuwe Game")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)

            // Game over overlay
            if game.isGameOver {
                GameOverOverlay(game: game) {
                    withAnimation {
                        game.reset()
                    }
                }
            }
        }
    }

    // MARK: - Instruction Text
    private var instructionText: some View {
        Group {
            if game.selectedPlayer == nil {
                Text("Kies wie scoort")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                Text("Tik op de baan waar het punt gescoord werd")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(game.selectedPlayer == .player1 ? .blue : .red)
            }
        }
    }

    // MARK: - Handlers
    private func handlePlayerSelect(_ player: Player) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if game.selectedPlayer == player {
                // Deselect if already selected
                game.clearSelection()
            } else {
                game.selectPlayer(player)
            }
        }
    }

    private func handleZoneTap(_ zone: CourtZone) {
        guard let player = game.selectedPlayer else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            game.addPoint(to: player, at: zone)
        }
    }
}

struct GameOverOverlay: View {
    let game: Game
    let onNewGame: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(4)

                if let winner = game.winner {
                    Text("\(game.name(for: winner)) wint!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }

                Text("\(game.player1Score) - \(game.player2Score)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // Quick stats
                VStack(spacing: 8) {
                    Text("Punten per zone")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 20) {
                        statsColumn(for: .player1)
                        statsColumn(for: .player2)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

                Button(action: onNewGame) {
                    Text("Nieuwe Game")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .cornerRadius(25)
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
            )
        }
    }

    private func statsColumn(for player: Player) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.name(for: player))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(player == .player1 ? .blue : .red)

            ForEach(CourtZone.allCases) { zone in
                let count = game.pointsWon(by: player, in: zone)
                if count > 0 {
                    HStack {
                        Text(zone.shortName)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - iPhone Preview

#Preview("iPhone 15 Pro") {
    ContentView()
}

#Preview("Game in Progress") {
    ContentView()
}
