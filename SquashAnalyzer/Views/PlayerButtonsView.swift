import SwiftUI

// MARK: - Quick entry (setting "Snelle invoer")

enum QuickEntryAction {
    case winner, unforcedError, more
}

/// Per player a big WINNER button plus FOUT (unforced error, scores at once) and
/// "…" for the other point types, in the referee's outlined style.
struct QuickEntryButtonsView: View {
    let game: Game
    let onAction: (Player, QuickEntryAction) -> Void

    var body: some View {
        HStack(spacing: 8) {
            column(.player1, color: AppColors.warmOrange)
            column(.player2, color: AppColors.steelBlue)
        }
    }

    private func column(_ player: Player, color: Color) -> some View {
        VStack(spacing: 6) {
            button(title: "WINNER", subtitle: game.name(for: player), color: color, prominent: true) {
                onAction(player, .winner)
            }
            HStack(spacing: 6) {
                button(title: "FOUT", subtitle: "unforced", color: color) {
                    onAction(player, .unforcedError)
                }
                button(title: "···", subtitle: "meer", color: color) {
                    onAction(player, .more)
                }
            }
        }
    }

    private func button(title: String, subtitle: String, color: Color, prominent: Bool = false,
                        action: @escaping () -> Void) -> some View {
        let disabled = game.isGameOver
        return Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(AppFonts.label(prominent ? 14 : 12))
                    .tracking(1)
                Text(subtitle)
                    .font(AppFonts.caption(9))
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(disabled ? AppColors.textMuted : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, prominent ? 10 : 7)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(disabled ? 0.04 : (prominent ? 0.14 : 0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(disabled ? 0.08 : (prominent ? 0.4 : 0.28)), lineWidth: 1)
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

        QuickEntryButtonsView(
            game: {
                let game = Game()
                game.player1Name = "Niels"
                game.player2Name = "Paul"
                return game
            }(),
            onAction: { _, _ in }
        )
        .padding()
    }
}
