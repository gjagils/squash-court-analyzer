import SwiftUI

/// A view that wraps content in an iPhone-style mockup frame
struct iPhoneMockupView<Content: View>: View {
    let content: Content

    // iPhone 15 Pro dimensions (scaled)
    private let screenWidth: CGFloat = 280
    private let screenHeight: CGFloat = 606
    private let cornerRadius: CGFloat = 44
    private let bezelWidth: CGFloat = 8
    private let dynamicIslandWidth: CGFloat = 90
    private let dynamicIslandHeight: CGFloat = 28

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Phone outer frame
            RoundedRectangle(cornerRadius: cornerRadius + bezelWidth)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.17),
                            Color(red: 0.08, green: 0.08, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: screenWidth + bezelWidth * 2,
                    height: screenHeight + bezelWidth * 2
                )

            // Screen bezel (subtle inner shadow effect)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black)
                .frame(width: screenWidth, height: screenHeight)

            // Screen content
            content
                .frame(width: screenWidth, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 2))

            // Dynamic Island
            VStack {
                Capsule()
                    .fill(Color.black)
                    .frame(width: dynamicIslandWidth, height: dynamicIslandHeight)
                    .padding(.top, 12)
                Spacer()
            }
            .frame(width: screenWidth, height: screenHeight)

            // Side buttons (volume + power)
            HStack {
                // Volume buttons (left side)
                VStack(spacing: 12) {
                    Spacer().frame(height: 80)
                    // Silent switch
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.22))
                        .frame(width: 3, height: 20)
                    Spacer().frame(height: 20)
                    // Volume up
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.22))
                        .frame(width: 3, height: 40)
                    // Volume down
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.22))
                        .frame(width: 3, height: 40)
                    Spacer()
                }
                .offset(x: -screenWidth / 2 - bezelWidth - 1)

                Spacer()

                // Power button (right side)
                VStack {
                    Spacer().frame(height: 120)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.22))
                        .frame(width: 3, height: 65)
                    Spacer()
                }
                .offset(x: screenWidth / 2 + bezelWidth + 1)
            }
            .frame(width: screenWidth + 40, height: screenHeight)

            // Screen reflection overlay (subtle)
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear,
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: screenWidth, height: screenHeight)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview with iPhone Mockup

#Preview("iPhone Mockup - Start") {
    ZStack {
        Color(red: 0.9, green: 0.9, blue: 0.92)
            .ignoresSafeArea()

        iPhoneMockupView {
            ContentView()
        }
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

#Preview("iPhone Mockup - Player Selected") {
    ZStack {
        Color(red: 0.9, green: 0.9, blue: 0.92)
            .ignoresSafeArea()

        iPhoneMockupView {
            GamePreviewContent(p1Score: 3, p2Score: 2, selectedPlayer: .player1)
        }
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

#Preview("iPhone Mockup - Game Over") {
    ZStack {
        Color(red: 0.9, green: 0.9, blue: 0.92)
            .ignoresSafeArea()

        iPhoneMockupView {
            GamePreviewContent(p1Score: 11, p2Score: 8, selectedPlayer: nil)
        }
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

/// Helper view for previewing different game states
struct GamePreviewContent: View {
    let p1Score: Int
    let p2Score: Int
    let selectedPlayer: Player?

    @State private var game: Game

    init(p1Score: Int, p2Score: Int, selectedPlayer: Player? = nil) {
        self.p1Score = p1Score
        self.p2Score = p2Score
        self.selectedPlayer = selectedPlayer
        let g = Game()
        g.player1Name = "Jan"
        g.player2Name = "Piet"
        g.player1Score = p1Score
        g.player2Score = p2Score
        g.selectedPlayer = selectedPlayer
        _game = State(initialValue: g)
    }

    var body: some View {
        ZStack {
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
                Text("SQUASH ANALYZER")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(3)
                    .padding(.top, 8)

                ScoreboardView(game: game)
                    .padding(.horizontal, 24)

                // Instruction text
                Group {
                    if game.selectedPlayer == nil && !game.isGameOver {
                        Text("Kies wie scoort")
                            .foregroundColor(.white.opacity(0.5))
                    } else if let player = game.selectedPlayer {
                        Text("Tik op de baan waar het punt gescoord werd")
                            .foregroundColor(player == .player1 ? .blue : .red)
                    }
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(.horizontal, 24)

                CourtView(game: game) { zone in
                    if let player = game.selectedPlayer {
                        game.addPoint(to: player, at: zone)
                    }
                }
                .padding(.horizontal, 16)

                PlayerButtonsView(game: game) { player in
                    if game.selectedPlayer == player {
                        game.clearSelection()
                    } else {
                        game.selectPlayer(player)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)

            if game.isGameOver {
                GameOverOverlay(game: game) {
                    game.reset()
                }
            }
        }
    }
}
