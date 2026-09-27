import SwiftUI
import SquashAnalyzerCore

/// Shared Android referee screen. It keeps the same core controls as iOS:
/// tap a score for a rally, choose Links/Rechts for the server, call LET or
/// STROKE, undo mistakes, and continue after a finished game.
public struct RefereeScoringView: View {
    @State private var match: RefereeMatch
    let onMatchChanged: (RefereeMatch) -> Void
    let onExit: @MainActor () -> Void
    @Environment(\.dismiss) private var dismiss

    public init(match: RefereeMatch, onMatchChanged: @escaping (RefereeMatch) -> Void, onExit: @escaping @MainActor () -> Void) {
        _match = State(initialValue: match)
        self.onMatchChanged = onMatchChanged
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [CoachPalette.backgroundMedium, CoachPalette.backgroundDark],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                gameHeader
                playerColumns
                actionGrid
                undoButton
            }
            .padding(.bottom, 20)

            if let call = match.lastCallText {
                callFlash(call)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        if match.lastCallText == call { match.clearCallText() }
                    }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: close) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Sluiten")
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundColor(CoachPalette.textSecondary)
            Spacer()
            Text("SCHEIDSRECHTER")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.textPrimary)
                .tracking(2)
            Spacer()
            Color.clear.frame(width: 74, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var gameHeader: some View {
        VStack(spacing: 4) {
            Text("GAME \(match.currentGameNumber)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(CoachPalette.textMuted)
                .tracking(2)
            HStack(spacing: 8) {
                Text(match.player1Name)
                    .foregroundColor(CoachPalette.warmOrange)
                Text("\(match.player1GamesWon) – \(match.player2GamesWon)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(CoachPalette.textPrimary)
                Text(match.player2Name)
                    .foregroundColor(CoachPalette.steelBlue)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            if !match.completedGames.isEmpty || match.firstGameNumber > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(1..<match.firstGameNumber, id: \.self) { number in
                            gameChip("G\(number): –", color: CoachPalette.textMuted)
                        }
                        ForEach(match.completedGames) { game in
                            let color = game.winner == .player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue
                            gameChip("G\(game.number): \(game.player1Score)-\(game.player2Score)", color: color)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func gameChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10)))
    }

    private var playerColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            playerColumn(.player1)
            timeline
            playerColumn(.player2)
        }
        .frame(maxHeight: .infinity)
    }

    private func playerColumn(_ player: Player) -> some View {
        let isServer = match.currentServer == player
        let color = player == .player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue
        let score = player == .player1 ? match.player1Score : match.player2Score

        return VStack(spacing: 8) {
            PlayerAvatarPlaceholder(color: color, size: 48, active: isServer)
            Text(match.name(for: player))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isServer ? CoachPalette.textPrimary : color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ServiceSideSelector(
                side: match.serverSide,
                preferredSide: match.preferredSide(for: player),
                color: color,
                compact: true,
                disabled: match.isGameOver
            ) { side in
                withAnimation(.easeInOut(duration: 0.15)) { match.overrideSide(to: side) }
                onMatchChanged(match)
            }
            .opacity(isServer ? 1.0 : 0.0)
            .allowsHitTesting(isServer)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { match.awardPoint(to: player) }
                onMatchChanged(match)
            }) {
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 76, weight: .bold, design: .rounded))
                        .foregroundColor(isServer ? color : CoachPalette.textPrimary)
                    Text("TIK = PUNT")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(isServer ? color.opacity(0.75) : CoachPalette.textMuted)
                        .tracking(1.4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color.opacity(isServer ? 0.10 : 0.05))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(isServer ? 0.35 : 0.12), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .disabled(match.isGameOver)
            .accessibilityLabel("Punt voor \(match.name(for: player))")
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 12)
        .background(isServer ? color.opacity(0.05) : Color.clear)
    }

    private var timeline: some View {
        VStack(spacing: 8) {
            Text("NU")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.textMuted)
                .tracking(1)
            Rectangle()
                .fill(CoachPalette.textMuted.opacity(0.35))
                .frame(width: 2)
                .overlay(alignment: .top) {
                    VStack(spacing: 6) {
                        ForEach(match.pointHistory.reversed()) { entry in
                            Text(entry.label)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(entry.scorer == .player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(CoachPalette.backgroundMedium))
                        }
                    }
                    .padding(.top, 12)
                }
        }
        .frame(width: 84)
    }

    private var actionGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("LET", color: CoachPalette.warmOrange) { match.callLet(); onMatchChanged(match) }
                actionButton("LET", color: CoachPalette.steelBlue) { match.callLet(); onMatchChanged(match) }
            }
            HStack(spacing: 8) {
                actionButton("STROKE", color: CoachPalette.warmOrange) { match.callStroke(to: .player1); onMatchChanged(match) }
                actionButton("STROKE", color: CoachPalette.steelBlue) { match.callStroke(to: .player2); onMatchChanged(match) }
            }
            if match.isGameOver && !match.isMatchOver {
                Button("VOLGENDE GAME") {
                    withAnimation(.easeInOut(duration: 0.15)) { match.confirmNextGame() }
                    onMatchChanged(match)
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.backgroundDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(CoachPalette.textPrimary))
            }
            if match.isMatchOver, let winner = match.matchWinner {
                Text("\(match.name(for: winner)) wint met \(match.player1TotalGames) – \(match.player2TotalGames)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(CoachPalette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(CoachPalette.textPrimary.opacity(0.10)))
            }
        }
        .padding(.horizontal, 16)
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(match.isGameOver ? CoachPalette.textMuted : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(match.isGameOver ? 0.04 : 0.12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(match.isGameOver ? 0.08 : 0.35), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(match.isGameOver)
    }

    private var undoButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { match.undo() }
            onMatchChanged(match)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                Text("Undo")
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(match.canUndo ? CoachPalette.textPrimary : CoachPalette.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(match.canUndo ? 0.07 : 0.03)))
        }
        .buttonStyle(.plain)
        .disabled(!match.canUndo)
        .padding(.horizontal, 16)
    }

    private func callFlash(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .tracking(3)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.85)))
            .transition(.scale.combined(with: .opacity))
    }

    @MainActor private func close() {
        onExit()
        dismiss()
    }
}
