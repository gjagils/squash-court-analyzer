import SwiftUI
import SquashAnalyzerUI
import UIKit
import SquashAnalyzerCore

/// "Deel als plaatje": the result of a game or match as a picture, laid out
/// like the result card at the end of a game (Core's `ResultCard`). Android
/// draws the same card on a Canvas (`ResultImage.kt`).
struct ResultCardImage: View {
    let card: ResultCard
    /// 420 for the exported picture; nil fills the width (the preview in Deel score)
    var width: CGFloat? = 420

    private let background = SharedColors.pictureBackground
    private let chipBackground = SharedColors.pictureChip
    private let muted = SharedColors.pictureMuted

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
                .font(SharedFonts.system(26, weight: .bold, design: .rounded))
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
            .font(SharedFonts.system(84, weight: .heavy, design: .rounded))

            if let text = card.winnerText {
                Text(text)
                    .font(SharedFonts.system(20, weight: .medium, design: .rounded))
                    .foregroundColor(card.winner.map { color($0) } ?? AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if !card.rows.isEmpty {
                rowsView
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
                    .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(muted)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(background)
    }

    /// Team match: a quiet list under the score, one partij per line (who played
    /// whom, the stand and the games), only a hairline between the lines
    private var rowsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PARTIJEN")
                .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                .tracking(3)
                .foregroundColor(muted)
                .padding(.bottom, 6)
            ForEach(Array(card.rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }
                rowView(row).padding(.vertical, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func rowView(_ row: ResultCard.Row) -> some View {
        // The winner of the partij in their colour, the other side muted; open: both calm
        func tone(_ player: Player) -> Color {
            guard let winner = row.winner else { return AppColors.textSecondary }
            return winner == player ? color(player) : muted
        }
        let home = Text(row.home).fontWeight(row.winner == .player1 ? .semibold : .regular).foregroundColor(tone(.player1))
        let dash = Text("  –  ").foregroundColor(muted)
        let away = Text(row.away).fontWeight(row.winner == .player2 ? .semibold : .regular).foregroundColor(tone(.player2))
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(row.label)
                .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(muted)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                (home + dash + away)
                    .font(SharedFonts.system(16, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(row.games)
                    .font(SharedFonts.system(12, design: .rounded))
                    .foregroundColor(muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Text(row.score)
                .font(SharedFonts.system(18, weight: .semibold, design: .rounded))
                .foregroundColor(row.winner.map { color($0) } ?? AppColors.textPrimary)
        }
    }

    private func side(_ player: Player) -> some View {
        VStack(spacing: 10) {
            ZStack {
                // The player's photo (Spelers) when there is one, else a person
                if let data = card.photo(for: player), let photo = UIImage(data: data) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(SharedFonts.system(26))
                        .foregroundColor(color(player).opacity(0.7))
                }
                Circle()
                    .stroke(color(player).opacity(0.7), lineWidth: 3)
                    .frame(width: 64, height: 64)
            }
            Text(card.name(for: player))
                .font(SharedFonts.system(17, weight: .semibold, design: .rounded))
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
                .font(SharedFonts.system(10, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(tint.opacity(0.8))
            Text(chip.score)
                .font(SharedFonts.system(15, weight: .semibold, design: .rounded))
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
        guard let image = renderer.uiImage else { return nil }
        // ImageRenderer leaves a few transparent rows above and below the card,
        // which WhatsApp shows as a black or white edge: draw it on the card colour
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            UIColor(SharedColors.pictureBackground).setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
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

#Preview("Teamwedstrijd") {
    let card = ResultCard(title: "TEAMWEDSTRIJD KLAAR", player1Name: "All Inn Squash 8", player2Name: "Squash Delft 8",
                          player1Score: 9, player2Score: 8, winner: .player1, winnerText: "All Inn Squash 8 wint de teamwedstrijd",
                          chips: [])
    var rowsCard = card
    rowsCard.rows = [
        ResultCard.Row(label: "E1", home: "Paul Steenks", away: "Vish Delft", score: "2-3", games: "14-12 · 5-11 · 3-11 · 11-9 · 6-11", winner: .player2),
        ResultCard.Row(label: "E2", home: "Kristian Koster", away: "Sjors Delft", score: "1-3", games: "8-11 · 11-9 · 8-11 · 10-12", winner: .player2),
        ResultCard.Row(label: "E3", home: "Niels van Sevenhoven", away: "Luis delft", score: "3-2", games: "17-15 · 8-11 · 9-11 · 11-7 · 11-6", winner: .player1),
        ResultCard.Row(label: "E4", home: "Gerd-Jan van Gils", away: "Han", score: "3-0", games: "12-10 · 12-10 · 11-3", winner: .player1),
    ]
    return ResultCardImage(card: rowsCard)
}
