import SwiftUI

struct ScoreboardView: View {
    let game: Game
    var match: Match? = nil
    /// "Tik op de score" flow: tapping a player's column starts (or cancels) a point
    var onSelectPlayer: ((Player) -> Void)? = nil

    var body: some View {
        SportsPanel {
            HStack(alignment: .top, spacing: 8) {
                playerScore(.player1)
                gameColumn
                playerScore(.player2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Game / games column (mirrors the referee game header)
    private var gameColumn: some View {
        VStack(spacing: 3) {
            Text("GAME \(match?.currentGameNumber ?? 1)")
                .font(AppFonts.caption(10))
                .foregroundColor(AppColors.textMuted)
                .tracking(2)

            Text("\(match?.player1GamesWon ?? 0) – \(match?.player2GamesWon ?? 0)")
                .font(AppFonts.score(22))
                .foregroundColor(AppColors.textPrimary)
                .contentTransition(.numericText())

            Text("GAMES")
                .font(AppFonts.caption(8))
                .foregroundColor(AppColors.textMuted)
                .tracking(1.5)
        }
        .frame(width: 84)
        .padding(.top, 6)
    }

    // MARK: - Player column (compact version of the referee player column)
    private func playerScore(_ player: Player) -> some View {
        let column = playerColumn(player)
        return Group {
            if let onSelectPlayer {
                Button(action: { onSelectPlayer(player) }) { column }
                    .buttonStyle(.plain)
                    .disabled(game.isGameOver)
            } else {
                column
            }
        }
    }

    private func playerColumn(_ player: Player) -> some View {
        let color = player == .player1 ? AppColors.warmOrange : AppColors.steelBlue
        let score = player == .player1 ? game.player1Score : game.player2Score
        let isServing = game.currentServer == player
        let isScoring = game.selectedPlayer == player

        return VStack(spacing: 4) {
            PlayerAvatar(name: game.name(for: player), color: color, size: 34, active: isServing)

            Text(game.name(for: player))
                .font(AppFonts.label(13))
                .foregroundColor(isServing ? color : AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Links / Rechts service box, same rules as the referee screen. Always
            // laid out so both scores line up, only visible for the current server.
            ServiceSideSelector(
                side: game.serverSide,
                preferredSide: game.preferredSide(for: player),
                color: color,
                compact: true,
                disabled: game.isGameOver
            ) { side in
                withAnimation(.easeInOut(duration: 0.15)) { game.overrideSide(to: side) }
            }
            .opacity(isServing ? 1 : 0)
            .allowsHitTesting(isServing)

            Text("\(score)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundColor(isServing ? color : AppColors.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isScoring ? color.opacity(0.18) : (isServing ? color.opacity(0.06) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(isScoring ? 0.7 : 0), lineWidth: 1)
                )
        )
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
