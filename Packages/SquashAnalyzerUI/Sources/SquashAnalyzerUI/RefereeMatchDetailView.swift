import SwiftUI
import SquashAnalyzerCore

/// A referee match from Afgeronde wedstrijden: the result, every game with its
/// score, time and the run of rallies, and Delen. Until the competitie-avond
/// (30 October) a referee row could not be opened at all; the referee keeps no
/// shots or zones, so this is everything there is to show.
public struct RefereeMatchDetailView: View {
    let report: MatchShareReport
    let date: String
    let onShare: (() -> Void)?
    let onClose: () -> Void

    public init(report: MatchShareReport, date: String, onShare: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        self.report = report
        self.date = date
        self.onShare = onShare
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        resultBlock
                        ForEach(0..<report.games.count, id: \.self) { index in
                            gameCard(report.games[index])
                        }
                        totals
                    }
                    .padding(.bottom, 16)
                }
                if let onShare {
                    ActionButton(loc("DELEN"), style: .filled) { onShare() }
                }
                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
    }

    /// "✕ Sluiten" left, the title centred, as on the share sheet
    private var header: some View {
        ZStack {
            Text("WEDSTRIJD", bundle: textBundle)
                .font(SharedFonts.system(14, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(SharedColors.textPrimary)
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        AppSymbol("xmark", size: 14, color: SharedColors.textSecondary)
                        Text("Sluiten", bundle: textBundle)
                            .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loc("Sluiten"))
                Spacer()
            }
        }
    }

    private static func color(for player: Player) -> Color {
        player == Player.player1 ? SharedColors.accent : SharedColors.steelBlue
    }

    private var resultBlock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                side(Player.player1, games: report.player1Games)
                Text("–")
                    .font(SharedFonts.system(28, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                side(Player.player2, games: report.player2Games)
            }
            if let winner = report.matchWinner {
                Text("\(report.name(for: winner)) wint", bundle: textBundle)
                    .font(SharedFonts.system(15, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.gold)
            } else {
                Text("INCOMPLEET", bundle: textBundle)
                    .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(SharedColors.warmRed)
            }
            Text("\(date) · \(report.minutesText(report.duration)) · best of \(report.bestOf)")
                .font(SharedFonts.system(12, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(SharedColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SharedColors.line(0.1), lineWidth: 1))
    }

    private func side(_ player: Player, games: Int) -> some View {
        let won = report.matchWinner == player
        return VStack(spacing: 4) {
            Text(report.name(for: player))
                .font(SharedFonts.system(15, weight: .semibold, design: .rounded))
                .foregroundColor(Self.color(for: player))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text("\(games)")
                .font(SharedFonts.system(40, weight: .bold, design: .rounded))
                .foregroundColor(won ? Self.color(for: player) : SharedColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func gameCard(_ game: MatchShareReport.Game) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GAME \(game.number)")
                    .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(SharedColors.textMuted)
                Spacer()
                if let duration = game.duration {
                    Text(report.minutesText(duration))
                        .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textMuted)
                }
            }
            HStack(spacing: 8) {
                Text("\(game.player1Score)")
                    .font(SharedFonts.system(24, weight: .bold, design: .rounded))
                    .foregroundColor(game.winner == Player.player1 ? SharedColors.accent : SharedColors.textSecondary)
                Text("–")
                    .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                Text("\(game.player2Score)")
                    .font(SharedFonts.system(24, weight: .bold, design: .rounded))
                    .foregroundColor(game.winner == Player.player2 ? SharedColors.steelBlue : SharedColors.textSecondary)
                Spacer()
                if let winner = game.winner {
                    Text(report.name(for: winner))
                        .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                        .foregroundColor(Self.color(for: winner))
                        .lineLimit(1)
                }
            }
            if !game.rallyWinners.isEmpty {
                rallyStrip(game.rallyWinners)
            }
            HStack(spacing: 12) {
                if let run = game.longestRun, run.length > 1 {
                    Text("Langste reeks: \(report.name(for: run.player)) \(run.length)", bundle: textBundle)
                }
                if game.strokes > 0 {
                    Text("Strokes: \(game.strokes)", bundle: textBundle)
                }
            }
            .font(SharedFonts.system(11, weight: .medium, design: .rounded))
            .foregroundColor(SharedColors.textSecondary)
        }
        .padding(14)
        .background(SharedColors.tint(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Every rally of the game in order, coloured for who won it: runs and
    /// turns in the game at a glance
    private func rallyStrip(_ winners: [Player]) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<winners.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.color(for: winners[index]))
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private var totals: some View {
        HStack(spacing: 12) {
            stat(loc("Rally's"), "\(report.totalRallies)")
            if let run = report.longestRun {
                stat(loc("Langste reeks"), "\(run.length)")
            }
            stat("Strokes", "\(report.totalStrokes)")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
            Text(title.uppercased())
                .font(SharedFonts.system(9, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(SharedColors.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(SharedColors.tint(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
