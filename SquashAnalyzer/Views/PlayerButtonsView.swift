import SwiftUI

struct PlayerButtonsView: View {
    let game: Game
    let onSelectPlayer: (Player) -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Player 1 - Warm Orange
            HardwareButton(
                title: game.player1Name,
                subtitle: "Punt",
                color: AppColors.warmOrange,
                colorDark: AppColors.warmOrangeDark,
                isSelected: game.selectedPlayer == .player1
            ) {
                onSelectPlayer(.player1)
            }
            .opacity(game.isGameOver ? 0.5 : 1.0)
            .disabled(game.isGameOver)

            // Player 2 - Steel Blue
            HardwareButton(
                title: game.player2Name,
                subtitle: "Punt",
                color: AppColors.steelBlue,
                colorDark: AppColors.steelBlueDark,
                isSelected: game.selectedPlayer == .player2
            ) {
                onSelectPlayer(.player2)
            }
            .opacity(game.isGameOver ? 0.5 : 1.0)
            .disabled(game.isGameOver)
        }
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
