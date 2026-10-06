import SwiftUI
import SquashAnalyzerCore

/// Preview of the share picture in "Deel score" on Android, laid out like the
/// PNG that `ResultImage.kt` draws on a Canvas (and iOS' `ResultCardImage`):
/// title, both players with their photo, the big score, who won, a chip per game.
struct ResultCardPreview: View {
    let card: ResultCard

    private let background = SharedColors.pictureBackground
    private let muted = SharedColors.pictureMuted

    private func color(_ player: Player) -> Color {
        player == Player.player1 ? SharedColors.accent : SharedColors.steelBlueLight
    }

    private func scoreColor(_ player: Player) -> Color {
        guard let winner = card.winner else { return SharedColors.textPrimary }
        return winner == player ? color(player) : muted
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(card.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundColor(SharedColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(alignment: .top, spacing: 12) {
                side(Player.player1)
                side(Player.player2)
            }
            HStack(spacing: 0) {
                Text("\(card.player1Score)")
                    .foregroundColor(scoreColor(Player.player1))
                    .frame(maxWidth: .infinity)
                Text("–")
                    .foregroundColor(muted)
                Text("\(card.player2Score)")
                    .foregroundColor(scoreColor(Player.player2))
                    .frame(maxWidth: .infinity)
            }
            .font(.system(size: 64, weight: .heavy, design: .rounded))
            if let text = card.winnerText {
                Text(text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(card.winner == nil ? SharedColors.textSecondary : color(card.winner ?? Player.player1))
                    .multilineTextAlignment(.center)
            }
            if !card.rows.isEmpty {
                rowsView
            }
            HStack(spacing: 6) {
                ForEach(card.chips, id: \.label) { chip in
                    VStack(spacing: 2) {
                        Text(chip.label)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                        Text(chip.score)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(chip.winner == nil ? SharedColors.textSecondary : color(chip.winner ?? Player.player1))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .background(chip.winner == Player.player1 ? SharedColors.accent.opacity(0.16) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Text(card.footer)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundColor(muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    /// Team match: one quiet line per partij (who played whom, the stand, the games)
    private var rowsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PARTIJEN")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(2.5)
                .foregroundColor(muted)
                .padding(.bottom, 4)
            ForEach(card.rows, id: \.label) { row in
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                rowView(row).padding(.vertical, 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowView(_ row: ResultCard.Row) -> some View {
        // The winner of the partij in their colour, the other side muted; open: both calm
        func tone(_ player: Player) -> Color {
            guard let winner = row.winner else { return SharedColors.textSecondary }
            return winner == player ? color(player) : muted
        }
        return HStack(alignment: .top, spacing: 8) {
            Text(row.label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(muted)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(row.home)
                        .font(.system(size: 13, weight: row.winner == Player.player1 ? .semibold : .regular, design: .rounded))
                        .foregroundColor(tone(Player.player1))
                        .lineLimit(1)
                    Text("–")
                        .font(.system(size: 13))
                        .foregroundColor(muted)
                    Text(row.away)
                        .font(.system(size: 13, weight: row.winner == Player.player2 ? .semibold : .regular, design: .rounded))
                        .foregroundColor(tone(Player.player2))
                        .lineLimit(1)
                }
                Text(row.games)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(row.score)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(row.winner == nil ? SharedColors.textPrimary : color(row.winner ?? Player.player1))
        }
    }

    private func side(_ player: Player) -> some View {
        VStack(spacing: 8) {
            PlayerAvatarPlaceholder(color: color(player), size: 56, active: true, photo: card.photo(for: player))
            Text(card.name(for: player))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(player == Player.player1 ? SharedColors.textSecondary : color(player))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}
