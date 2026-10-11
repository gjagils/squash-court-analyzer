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

/// Rally's won on own serve and on the opponent's (C4), for the dashboard
struct ServiceReturnCard: View {
    let game: Game
    let player: Player

    var body: some View {
        let stats = ServiceReturnStats.of(game, for: player)
        let opponent = game.name(for: player.opponent)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                AppSymbol("figure.tennis", size: 13, color: SharedColors.accent)
                Text("Service en return")
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
            }
            row("Eigen service", stats.wonOnServe, stats.served)
            row("Service van \(opponent)", stats.wonOnReturn, stats.received)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ title: String, _ won: Int, _ total: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text(ServiceReturnStats.line(won, of: total))
                    .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    SharedColors.line(0.15)
                    SharedColors.accent
                        .frame(width: total > 0 ? geometry.size.width * Double(won) / Double(total) : 0.0)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
    }
}
