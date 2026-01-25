import SwiftUI

struct ScoreboardView: View {
    let game: Game

    private let scoreboardGreen = Color(red: 0.0, green: 0.35, blue: 0.15)
    private let scoreboardDarkGreen = Color(red: 0.0, green: 0.25, blue: 0.10)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("SQUASH")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(4)
                Spacer()
            }
            .padding(.vertical, 6)
            .background(scoreboardDarkGreen)

            // Score rows
            VStack(spacing: 1) {
                PlayerScoreRow(
                    name: game.player1Name,
                    score: game.player1Score,
                    isServing: game.currentServer == .player1,
                    isWinner: game.winner == .player1
                )

                PlayerScoreRow(
                    name: game.player2Name,
                    score: game.player2Score,
                    isServing: game.currentServer == .player2,
                    isWinner: game.winner == .player2
                )
            }
        }
        .background(scoreboardGreen)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

struct PlayerScoreRow: View {
    let name: String
    let score: Int
    let isServing: Bool
    let isWinner: Bool

    private let scoreboardGreen = Color(red: 0.0, green: 0.35, blue: 0.15)
    private let scoreYellow = Color(red: 1.0, green: 0.85, blue: 0.0)

    var body: some View {
        HStack(spacing: 0) {
            // Service indicator
            ZStack {
                Circle()
                    .fill(isServing ? scoreYellow : Color.clear)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 24)

            // Player name
            Text(name.uppercased())
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(isWinner ? scoreYellow : .white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Score
            Text("\(score)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(isWinner ? scoreYellow : .white)
                .frame(width: 50)
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                )
        }
        .padding(.vertical, 8)
        .padding(.trailing, 0)
        .background(scoreboardGreen)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            // Normal game
            ScoreboardView(game: {
                let game = Game()
                game.player1Name = "Jan"
                game.player2Name = "Piet"
                game.player1Score = 7
                game.player2Score = 5
                game.currentServer = .player1
                return game
            }())

            // Game point
            ScoreboardView(game: {
                let game = Game()
                game.player1Name = "Jan"
                game.player2Name = "Piet"
                game.player1Score = 10
                game.player2Score = 8
                game.currentServer = .player2
                return game
            }())

            // Game over
            ScoreboardView(game: {
                let game = Game()
                game.player1Name = "Jan"
                game.player2Name = "Piet"
                game.player1Score = 11
                game.player2Score = 7
                game.currentServer = .player1
                return game
            }())
        }
        .padding()
    }
}
