import SwiftUI

struct PlayerButtonsView: View {
    let game: Game
    let onSelectPlayer: (Player) -> Void

    var body: some View {
        HStack(spacing: 8) {
            scoreButton(.player1, color: AppColors.warmOrange)
            scoreButton(.player2, color: AppColors.steelBlue)
        }
    }

    private func scoreButton(_ player: Player, color: Color) -> some View {
        let disabled = game.isGameOver
        return Button(action: { onSelectPlayer(player) }) {
            VStack(spacing: 4) {
                Text("WON RALLY")
                    .font(AppFonts.caption(9))
                    .tracking(1.4)
                    .opacity(0.7)
                Text(game.name(for: player))
                    .font(AppFonts.label(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(disabled ? AppColors.textMuted : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(disabled ? 0.04 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(disabled ? 0.08 : 0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    ZStack {
        AppBackground()

        VStack(spacing: 40) {
            // No selection
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Niels"
                    game.player2Name = "Paul"
                    return game
                }(),
                onSelectPlayer: { _ in }
            )

            // Player 1 selected
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Niels"
                    game.player2Name = "Paul"
                    game.selectedPlayer = .player1
                    return game
                }(),
                onSelectPlayer: { _ in }
            )

            // Player 2 selected
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Niels"
                    game.player2Name = "Paul"
                    game.selectedPlayer = .player2
                    return game
                }(),
                onSelectPlayer: { _ in }
            )
        }
        .padding()
    }
}
