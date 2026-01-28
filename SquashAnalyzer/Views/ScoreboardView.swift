import SwiftUI

struct ScoreboardView: View {
    let game: Game
    var match: Match? = nil

    var body: some View {
        HardwarePanel {
            VStack(spacing: 0) {
                // Header with game count if in match
                headerSection

                // Main scoreboard content
                HStack(alignment: .center, spacing: 12) {
                    // Player names with server indicator
                    playerNamesSection

                    Spacer()

                    // LED Score display
                    scoreDisplay
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("SQUASH")
                .font(AppFonts.caption(10))
                .foregroundColor(AppColors.textMuted)
                .tracking(2)

            if let match = match {
                Spacer()
                // Games score (e.g., "2 - 1")
                Text("GAMES: \(match.player1GamesWon) - \(match.player2GamesWon)")
                    .font(AppFonts.caption(9))
                    .foregroundColor(AppColors.textMuted)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Player Names
    private var playerNamesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Player 1
            HStack(spacing: 8) {
                ServerIndicator(isServing: game.currentServer == .player1)
                Text(game.player1Name.uppercased())
                    .font(AppFonts.playerName(15))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
            }

            // Player 2
            HStack(spacing: 8) {
                ServerIndicator(isServing: game.currentServer == .player2)
                Text(game.player2Name.uppercased())
                    .font(AppFonts.playerName(15))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Score Display
    private var scoreDisplay: some View {
        HStack(spacing: 6) {
            // Player 1 score
            LEDScoreDisplay(score: game.player1Score, size: 44)

            // Colon separator
            LEDColon(size: 44)

            // Player 2 score
            LEDScoreDisplay(score: game.player2Score, size: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LEDDisplayBackground())
    }
}

// MARK: - Compact Scoreboard (for when shot selector is shown)
struct CompactScoreboardView: View {
    let game: Game

    var body: some View {
        HStack(spacing: 16) {
            // Player 1
            HStack(spacing: 8) {
                ServerIndicator(isServing: game.currentServer == .player1)
                Text(game.player1Name)
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }

            // Score
            HStack(spacing: 4) {
                Text("\(game.player1Score)")
                    .font(AppFonts.score(28))
                    .foregroundColor(AppColors.ledActive)
                Text("-")
                    .font(AppFonts.score(24))
                    .foregroundColor(AppColors.textMuted)
                Text("\(game.player2Score)")
                    .font(AppFonts.score(28))
                    .foregroundColor(AppColors.ledActive)
            }
            .shadow(color: AppColors.ledGlow.opacity(0.3), radius: 4, x: 0, y: 0)

            // Player 2
            HStack(spacing: 8) {
                Text(game.player2Name)
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
                ServerIndicator(isServing: game.currentServer == .player2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.backgroundMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview("Scoreboard") {
    ZStack {
        AppBackground()

        VStack(spacing: 30) {
            let game = Game()
            let _ = {
                game.player1Name = "Niels"
                game.player2Name = "Paul"
                game.player1Score = 7
                game.player2Score = 5
            }()

            ScoreboardView(game: game)
                .padding(.horizontal, 20)

            ScoreboardView(game: game, match: {
                let m = Match()
                m.player1Name = "Niels"
                m.player2Name = "Paul"
                return m
            }())
            .padding(.horizontal, 20)

            CompactScoreboardView(game: game)
        }
    }
}

#Preview("Scoreboard - High Score") {
    ZStack {
        AppBackground()

        let game = Game()
        let _ = {
            game.player1Name = "Niels"
            game.player2Name = "Paul"
            game.player1Score = 11
            game.player2Score = 9
        }()

        ScoreboardView(game: game)
            .padding(.horizontal, 20)
    }
}
