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

                // Court view
                CourtView()
                    .padding(.horizontal, 16)

                // Player buttons (below court)
                PlayerButtonsView(game: game) { player in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        game.addPoint(to: player)
                    }
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
            .padding(40)
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
}

// MARK: - iPhone Preview

#Preview("iPhone 15 Pro") {
    ContentView()
}

#Preview("Game in Progress") {
    ContentView()
        .onAppear {
            // This preview shows a game in progress
        }
}
