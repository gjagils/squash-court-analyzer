import SwiftUI
import UIKit
import SquashAnalyzerCore

/// "Deel als plaatje": the result of a game or match as a picture, laid out
/// like the result card at the end of a game (Core's `ResultCard`). Android
/// draws the same card on a Canvas (`ResultImage.kt`).
struct ResultCardImage: View {
    let card: ResultCard

    private let background = Color(red: 0.12, green: 0.105, blue: 0.09)
    private let chipBackground = Color(red: 0.17, green: 0.165, blue: 0.17)
    private let muted = Color(red: 0.56, green: 0.54, blue: 0.52)

    private func color(_ player: Player) -> Color {
        player == .player1 ? AppColors.warmOrange : AppColors.steelBlueLight
    }

    /// The winner in their colour, the other side muted (as on the result card)
    private func scoreColor(_ player: Player) -> Color {
        guard let winner = card.winner else { return AppColors.textPrimary }
        return winner == player ? color(player) : muted
    }

    var body: some View {
        VStack(spacing: 26) {
            Text(card.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .tracking(6)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(alignment: .top, spacing: 12) {
                side(.player1)
                side(.player2)
            }

            HStack(spacing: 0) {
                Text("\(card.player1Score)")
                    .foregroundColor(scoreColor(.player1))
                    .frame(maxWidth: .infinity)
                Text("–")
                    .foregroundColor(muted)
                Text("\(card.player2Score)")
                    .foregroundColor(scoreColor(.player2))
                    .frame(maxWidth: .infinity)
            }
            .font(.system(size: 84, weight: .heavy, design: .rounded))

            if let text = card.winnerText {
                Text(text)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(card.winner.map { color($0) } ?? AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if !card.chips.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(card.chips.enumerated()), id: \.offset) { _, chip in
                        chipView(chip)
                    }
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(AppColors.accentGold)
                    .frame(width: 8, height: 8)
                Text(card.footer)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(muted)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .frame(width: 420)
        .background(background)
    }

    private func side(_ player: Player) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(color(player).opacity(0.7), lineWidth: 3)
                    .frame(width: 64, height: 64)
                Image(systemName: "person.fill")
                    .font(.system(size: 26))
                    .foregroundColor(color(player).opacity(0.7))
            }
            Text(card.name(for: player))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(player == .player1 ? AppColors.textSecondary : color(player))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func chipView(_ chip: ResultCard.Chip) -> some View {
        let won1 = chip.winner == .player1
        let tint: Color = chip.winner.map { color($0) } ?? AppColors.textSecondary
        return VStack(spacing: 2) {
            Text(chip.label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(tint.opacity(0.8))
            Text(chip.score)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .padding(.vertical, 7)
        .frame(minWidth: 54)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(won1 ? AppColors.warmOrange.opacity(0.16) : chipBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(won1 ? AppColors.warmOrange.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1))
    }

    /// The picture to share (3× for a sharp image in WhatsApp)
    @MainActor
    static func render(_ card: ResultCard) -> UIImage? {
        let renderer = ImageRenderer(content: ResultCardImage(card: card))
        renderer.scale = 3
        return renderer.uiImage
    }
}

#Preview("Wedstrijd klaar") {
    let games = [
        MatchShareReport.Game(number: 1, player1Score: 15, player2Score: 17, winner: .player2, duration: nil, rallyWinners: [], strokes: 0),
        MatchShareReport.Game(number: 2, player1Score: 11, player2Score: 8, winner: .player1, duration: nil, rallyWinners: [], strokes: 0),
        MatchShareReport.Game(number: 3, player1Score: 11, player2Score: 9, winner: .player1, duration: nil, rallyWinners: [], strokes: 0),
        MatchShareReport.Game(number: 4, player1Score: 7, player2Score: 11, winner: .player2, duration: nil, rallyWinners: [], strokes: 0),
        MatchShareReport.Game(number: 5, player1Score: 6, player2Score: 11, winner: .player2, duration: nil, rallyWinners: [], strokes: 0),
    ]
    let report = MatchShareReport(player1Name: "Luis delft", player2Name: "Niels van Sevenhoven", bestOf: 5, firstGameNumber: 1,
                                  player1Games: 2, player2Games: 3, matchWinner: .player2, games: games,
                                  startedAt: Date(), duration: 0)
    return ResultCardImage(card: ResultCard.from(report))
}
