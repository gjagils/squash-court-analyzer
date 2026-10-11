import SwiftUI
import SquashAnalyzerCore

/// Writing the coach's note for one game (C3); the keyboard's microphone dictates
struct GameNoteEditor: View {
    let gameId: UUID
    let title: String
    let onDone: () -> Void
    @State private var text = ""

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                Text("Wat viel je op? Alleen voor jou: de notitie staat in de analyse en op de coachkaart, niet in wat je deelt.")
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Bijvoorbeeld: backhand-volley te laat", text: $text, axis: .vertical)
                    .accessibilityLabel("Notitie")
                    .textFieldStyle(.plain)
                    .font(SharedFonts.system(17))
                    .foregroundColor(SharedColors.textPrimary)
                    .lineLimit(8)
                    .padding()
                    .background(SharedColors.tint(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SharedColors.line(0.12), lineWidth: 1))
                if GameNotes.shared.saveFailed {
                    Text("Bewaren lukte niet. Probeer het opnieuw.")
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.error)
                }
                HStack(spacing: 12) {
                    ActionButton("ANNULEREN", style: .outlined, color: SharedColors.textSecondary) { onDone() }
                    ActionButton("BEWAAR", style: .filled, color: SharedColors.accent) {
                        GameNotes.shared.set(text, for: gameId)
                        if !GameNotes.shared.saveFailed { onDone() }
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(SharedColors.preferredScheme)
        .onAppear { text = GameNotes.shared.note(for: gameId) }
    }
}

/// The note of a game as a card: the text, or an invitation to write one, with an edit button
struct GameNoteCard: View {
    let gameId: UUID
    let onEdit: () -> Void

    var body: some View {
        let note = GameNotes.shared.note(for: gameId)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                AppSymbol("pencil", size: 13, color: SharedColors.accent)
                Text("Notitie")
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                Spacer()
                Button(action: onEdit) {
                    Text(note.isEmpty ? "Schrijf" : "Bewerk")
                        .font(SharedFonts.system(13, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(note.isEmpty ? "Notitie schrijven" : "Notitie bewerken")
            }
            Text(note.isEmpty ? "Nog geen notitie bij deze game." : note)
                .font(SharedFonts.system(note.isEmpty ? 13.0 : 15.0))
                .foregroundColor(note.isEmpty ? SharedColors.textMuted : SharedColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Rally's won on own serve and on the opponent's (C4), for the dashboard:
/// the percentage in this game, from game 2 on up or down against the game
/// before, and the percentage over the match so far
struct ServiceReturnCard: View {
    let match: Match
    let gameIndex: Int
    let player: Player

    var body: some View {
        let index = max(0, min(gameIndex, match.games.count - 1))
        let now = ServiceReturnStats.of(match.games[index], for: player)
        let before: ServiceReturnStats? = index > 0 ? ServiceReturnStats.of(match.games[index - 1], for: player) : nil
        let total = ServiceReturnStats.of(match, through: index, for: player)
        let opponent = match.name(for: player.opponent)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                AppSymbol("figure.tennis", size: 13, color: SharedColors.accent)
                Text("Service en return")
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                Spacer()
                Text("game · wedstrijd")
                    .font(SharedFonts.system(11))
                    .foregroundColor(SharedColors.textMuted)
            }
            row("Eigen service", now.servePercentage, before?.servePercentage, total.servePercentage)
            row("Service van \(opponent)", now.returnPercentage, before?.returnPercentage, total.returnPercentage)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private static func text(_ percentage: Int?) -> String {
        guard let percentage else { return "–" }
        return "\(percentage)%"
    }

    private func trendColor(_ trend: String) -> Color {
        if trend.hasPrefix("▲") { return SharedColors.positive }
        if trend.hasPrefix("▼") { return SharedColors.error }
        return SharedColors.textMuted
    }

    /// "Eigen service   64%  ▲ 12   wedstrijd 58%"
    private func row(_ title: String, _ game: Int?, _ previous: Int?, _ match: Int?) -> some View {
        let trend = ServiceReturnStats.trend(game, previous)
        return HStack(spacing: 8) {
            Text(title)
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(ServiceReturnCard.text(game))
                .font(SharedFonts.system(17, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
            if let trend {
                Text(trend)
                    .font(SharedFonts.system(12, weight: .semibold, design: .rounded))
                    .foregroundColor(trendColor(trend))
                    .frame(minWidth: 38, alignment: .leading)
            }
            Text(ServiceReturnCard.text(match))
                .font(SharedFonts.system(13, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textMuted)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}
