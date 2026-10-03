import SwiftUI
import SquashAnalyzerCore

/// "Uitslag aanvullen": who won each game that was not tracked, until the
/// match is decided (Core's Match.isValidResultCompletion/completeResult), as
/// on iOS. Used when stopping a coach match and from Afgeronde wedstrijden.
struct SharedCompleteResultView: View {
    let match: Match
    let onSave: ([Player]) -> Void
    let onCancel: () -> Void

    @State private var winners: [Player] = []

    private var isDecided: Bool { match.isValidResultCompletion(winners) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("UITSLAG AANVULLEN")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(SharedColors.textPrimary)
                Text("Kies per gemiste game wie hem won.")
                    .font(.system(size: 13))
                    .foregroundColor(SharedColors.textSecondary)
                Text("Nu: \(match.player1Name) \(match.player1GamesWon) – \(match.player2GamesWon) \(match.player2Name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SharedColors.textSecondary)

                ForEach(0..<winners.count, id: \.self) { index in
                    HStack {
                        Text("Game \(match.firstUnrecordedGameNumber + index)")
                            .foregroundColor(SharedColors.textSecondary)
                        Spacer()
                        Text(match.name(for: winners[index]))
                            .fontWeight(.semibold)
                            .foregroundColor(winners[index] == Player.player1 ? SharedColors.accent : SharedColors.steelBlue)
                    }
                    .font(.system(size: 14))
                }

                if !isDecided && winners.count < 5 {
                    Text("Game \(match.firstUnrecordedGameNumber + winners.count): wie won?")
                        .font(.system(size: 13))
                        .foregroundColor(SharedColors.textPrimary)
                    HStack(spacing: 10) {
                        choice(Player.player1, SharedColors.accent)
                        choice(Player.player2, SharedColors.steelBlue)
                    }
                }

                if !winners.isEmpty {
                    Button("Laatste game wissen") { winners.removeLast() }
                        .foregroundColor(SharedColors.textSecondary)
                }

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Annuleren")
                            .foregroundColor(SharedColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Button { onSave(winners) } label: {
                        Text("Opslaan")
                            .fontWeight(.bold)
                            .foregroundColor(SharedColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isDecided ? SharedColors.accent : SharedColors.textMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isDecided)
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 20).fill(SharedColors.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(SharedColors.accent.opacity(0.4), lineWidth: 1))
            .padding(24)
        }
    }

    private func choice(_ player: Player, _ color: Color) -> some View {
        Button { winners.append(player) } label: {
            Text(match.name(for: player))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(match.name(for: player)) won deze game")
    }
}
