import SwiftUI

struct PlayerButtonsView: View {
    let game: Game
    let onSelectPlayer: (Player) -> Void

    var body: some View {
        HStack(spacing: 16) {
            PlayerButton(
                playerName: game.player1Name,
                color: .blue,
                isSelected: game.selectedPlayer == .player1,
                isDisabled: game.isGameOver
            ) {
                onSelectPlayer(.player1)
            }

            PlayerButton(
                playerName: game.player2Name,
                color: .red,
                isSelected: game.selectedPlayer == .player2,
                isDisabled: game.isGameOver
            ) {
                onSelectPlayer(.player2)
            }
        }
    }
}

struct PlayerButton: View {
    let playerName: String
    let color: Color
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(isSelected ? "SCOORT" : "PUNT")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                Text(playerName.uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: isDisabled
                                ? [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
                                : isSelected
                                    ? [color.opacity(1), color.opacity(0.9)]
                                    : [color.opacity(0.8), color.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.white : Color.white.opacity(0.2),
                        lineWidth: isSelected ? 3 : 1
                    )
            )
            .scaleEffect(isPressed ? 0.96 : isSelected ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? color.opacity(0.6) : color.opacity(isDisabled ? 0 : 0.3),
                radius: isSelected ? 12 : 8,
                x: 0,
                y: isSelected ? 6 : 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            // No selection
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Jan"
                    game.player2Name = "Piet"
                    return game
                }(),
                onSelectPlayer: { _ in }
            )

            // Player 1 selected
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Jan"
                    game.player2Name = "Piet"
                    game.selectedPlayer = .player1
                    return game
                }(),
                onSelectPlayer: { _ in }
            )

            // Player 2 selected
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Jan"
                    game.player2Name = "Piet"
                    game.selectedPlayer = .player2
                    return game
                }(),
                onSelectPlayer: { _ in }
            )
        }
        .padding()
    }
}
