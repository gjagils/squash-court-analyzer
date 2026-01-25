import SwiftUI

struct PlayerButtonsView: View {
    let game: Game
    let onScore: (Player) -> Void

    var body: some View {
        HStack(spacing: 16) {
            PlayerButton(
                playerName: game.player1Name,
                color: .blue,
                isDisabled: game.isGameOver
            ) {
                onScore(.player1)
            }

            PlayerButton(
                playerName: game.player2Name,
                color: .red,
                isDisabled: game.isGameOver
            ) {
                onScore(.player2)
            }
        }
    }
}

struct PlayerButton: View {
    let playerName: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("PUNT")
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
                                : [color, color.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .shadow(color: color.opacity(isDisabled ? 0 : 0.4), radius: 8, x: 0, y: 4)
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
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Jan"
                    game.player2Name = "Piet"
                    return game
                }(),
                onScore: { player in
                    print("Score for \(player)")
                }
            )

            // Disabled state
            PlayerButtonsView(
                game: {
                    let game = Game()
                    game.player1Name = "Jan"
                    game.player2Name = "Piet"
                    game.player1Score = 11
                    game.player2Score = 5
                    return game
                }(),
                onScore: { _ in }
            )
        }
        .padding()
    }
}
