import SwiftUI

struct GameSetupView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool

    @State private var player1Name: String = ""
    @State private var player2Name: String = ""
    @State private var startingServer: Player = .player1

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

            VStack(spacing: 24) {
                // Header
                Text("NIEUWE GAME")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(3)
                    .padding(.top, 40)

                Spacer()

                // Player names input
                VStack(spacing: 20) {
                    PlayerNameInput(
                        title: "Speler 1",
                        name: $player1Name,
                        color: .blue,
                        placeholder: "Naam speler 1"
                    )

                    PlayerNameInput(
                        title: "Speler 2",
                        name: $player2Name,
                        color: .red,
                        placeholder: "Naam speler 2"
                    )
                }
                .padding(.horizontal, 24)

                // Starting server selection
                VStack(spacing: 12) {
                    Text("Wie serveert eerst?")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 16) {
                        ServerSelectionButton(
                            name: player1Name.isEmpty ? "Speler 1" : player1Name,
                            color: .blue,
                            isSelected: startingServer == .player1
                        ) {
                            startingServer = .player1
                        }

                        ServerSelectionButton(
                            name: player2Name.isEmpty ? "Speler 2" : player2Name,
                            color: .red,
                            isSelected: startingServer == .player2
                        ) {
                            startingServer = .player2
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // Start button
                Button(action: startGame) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("START GAME")
                    }
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
                    .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func startGame() {
        // Set player names (use defaults if empty)
        game.player1Name = player1Name.isEmpty ? "Speler 1" : player1Name
        game.player2Name = player2Name.isEmpty ? "Speler 2" : player2Name
        game.setStartingServer(startingServer)
        game.reset()

        isPresented = false
    }
}

// MARK: - Player Name Input

struct PlayerNameInput: View {
    let title: String
    @Binding var name: String
    let color: Color
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .tracking(1)

            TextField(placeholder, text: $name)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

// MARK: - Server Selection Button

struct ServerSelectionButton: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? color : .white.opacity(0.4))

                Text(name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    GameSetupView(
        game: .constant(Game()),
        isPresented: .constant(true)
    )
}
