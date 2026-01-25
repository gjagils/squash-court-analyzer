import SwiftUI

struct ContentView: View {
    @State private var game = Game()
    @State private var showingSetup = true
    @State private var showingAnalysis = false

    var body: some View {
        ZStack {
            // Main game view
            gameView

            // Setup overlay
            if showingSetup {
                GameSetupView(game: $game, isPresented: $showingSetup)
                    .transition(.opacity)
            }

            // Analysis overlay
            if showingAnalysis {
                AnalysisView(game: game) {
                    showingAnalysis = false
                }
                .transition(.opacity)
            }

            // Game over overlay (when not showing analysis yet)
            if game.isGameOver && !showingAnalysis {
                GameOverOverlay(game: game) {
                    // Show analysis
                    showingAnalysis = true
                } onNewGame: {
                    showingSetup = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSetup)
        .animation(.easeInOut(duration: 0.3), value: showingAnalysis)
        .animation(.easeInOut(duration: 0.3), value: game.isGameOver)
    }

    // MARK: - Game View
    private var gameView: some View {
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

            VStack(spacing: 12) {
                // Header with undo button
                headerView

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

                // Bottom buttons row
                bottomButtonsRow

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // New game button
            Button(action: { showingSetup = true }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Text("SQUASH ANALYZER")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .tracking(2)

            Spacer()

            // Undo button
            Button(action: {
                withAnimation {
                    game.undoLastPoint()
                }
            }) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 20))
                    .foregroundColor(game.canUndo ? .white.opacity(0.6) : .white.opacity(0.2))
            }
            .disabled(!game.canUndo)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
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

    // MARK: - Bottom Buttons Row
    private var bottomButtonsRow: some View {
        HStack(spacing: 16) {
            // Undo last point (with text)
            if game.canUndo {
                Button(action: {
                    withAnimation {
                        game.undoLastPoint()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Ongedaan")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                }
            }

            // Last point indicator
            if let lastPoint = game.lastPoint {
                HStack(spacing: 4) {
                    Circle()
                        .fill(lastPoint.scorer == .player1 ? Color.blue : Color.red)
                        .frame(width: 8, height: 8)
                    Text("\(game.name(for: lastPoint.scorer)): \(lastPoint.zone.shortName)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(height: 36)
    }

    // MARK: - Handlers
    private func handlePlayerSelect(_ player: Player) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if game.selectedPlayer == player {
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

// MARK: - Game Over Overlay

struct GameOverOverlay: View {
    let game: Game
    let onAnalysis: () -> Void
    let onNewGame: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
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
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    // Analysis button
                    Button(action: onAnalysis) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Bekijk Analyse")
                        }
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow)
                        .cornerRadius(12)
                    }

                    // New game button
                    Button(action: onNewGame) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Nieuwe Game")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - iPhone Preview

#Preview("iPhone 15 Pro") {
    ContentView()
}
