import SwiftUI
import SquashAnalyzerCore

/// De coachkaart (Core's `CoachCard`): one screen to show the player between
/// games, with where both players scored and the three points of the game,
/// from game 2 on related to the game before. Opened from the coach dashboard,
/// so it also works for matches coached earlier.
public struct SharedCoachCardView: View {
    let match: Match
    let gameIndex: Int
    let onClose: () -> Void
    @State private var player: Player

    public init(match: Match, gameIndex: Int, player: Player, onClose: @escaping () -> Void) {
        self.match = match
        self.gameIndex = gameIndex
        self.onClose = onClose
        _player = State(initialValue: player)
    }

    private var game: Game { match.games[max(0, min(gameIndex, match.games.count - 1))] }
    private var card: CoachCard { CoachCard.make(match: match, gameIndex: gameIndex, player: player) }

    private func color(_ side: Player) -> Color { side == Player.player1 ? SharedColors.accent : SharedColors.steelBlue }

    public var body: some View {
        let current = card
        return ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(current)
                    playerPicker
                    HStack(alignment: .top, spacing: 12) {
                        ZoneHeatmap(game: game, player: Player.player1, color: color(Player.player1))
                        ZoneHeatmap(game: game, player: Player.player2, color: color(Player.player2))
                    }
                    section("COACHPUNTEN · \(game.name(for: player).uppercased())")
                    if current.points.isEmpty {
                        Text("Te weinig punten in deze game voor coachpunten. Leg vak en slag vast bij elk punt, dan komen ze hier.")
                            .font(SharedFonts.system(15))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                    ForEach(0..<current.points.count, id: \.self) { index in
                        pointRow(current.points[index], number: index + 1)
                    }
                    if !GameNotes.shared.note(for: game.id).isEmpty {
                        section("JOUW NOTITIE")
                        Text(GameNotes.shared.note(for: game.id))
                            .font(SharedFonts.system(17))
                            .foregroundColor(SharedColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let previous = current.previousGameNumber, !current.changes.isEmpty {
                        section("SINDS GAME \(previous)")
                        ForEach(0..<current.changes.count, id: \.self) { index in
                            pointRow(current.changes[index], number: nil)
                        }
                    }
                    ActionButton("SLUITEN", color: SharedColors.textSecondary, action: onClose)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private func header(_ current: CoachCard) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Coachkaart · Game \(current.gameNumber)")
                    .font(SharedFonts.system(24, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                Text("\(match.player1Name) \(game.player1Score)-\(game.player2Score) \(match.player2Name)")
                    .font(SharedFonts.system(15, weight: .semibold))
                    .foregroundColor(SharedColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                AppSymbol("xmark", size: 16, color: SharedColors.textSecondary, weight: .medium)
                    .padding(10)
                    .background(Circle().fill(SharedColors.tint(0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sluiten")
        }
    }

    /// Whose points: the card speaks to one player at a time
    private var playerPicker: some View {
        HStack(spacing: 10) {
            ForEach(0..<2, id: \.self) { index in
                let side = index == 0 ? Player.player1 : Player.player2
                let selected = side == player
                Button { player = side } label: {
                    Text(match.name(for: side))
                        .font(SharedFonts.system(15, weight: .semibold))
                        .foregroundColor(selected ? color(side) : SharedColors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? color(side).opacity(0.15) : SharedColors.tint(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? color(side).opacity(0.5) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(SharedFonts.system(12, weight: .semibold, design: .rounded))
            .tracking(1.5)
            .foregroundColor(SharedColors.textMuted)
            .padding(.top, 4)
    }

    private func markColor(_ point: CoachCardPoint) -> Color {
        switch point.mark {
        case .new: return point.item.tone == AdviceTone.success ? SharedColors.positive : SharedColors.accent
        case .stillThere: return SharedColors.warmRed
        case .improved: return SharedColors.positive
        case .pickUpAgain: return SharedColors.gold
        }
    }

    /// "1", "2", "3" for the points of this game; a dot for the changes
    static func marker(_ number: Int?) -> String {
        guard let number else { return "•" }
        return "\(number)"
    }

    /// One point in large type, with its label ("Nog steeds", "Verbeterd!", …) above it
    private func pointRow(_ point: CoachCardPoint, number: Int?) -> some View {
        let tint = markColor(point)
        return HStack(alignment: .top, spacing: 12) {
            Text(SharedCoachCardView.marker(number))
                .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 6) {
                if let label = point.mark.label {
                    Text(label.uppercased())
                        .font(SharedFonts.system(11, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(tint)
                }
                Text(point.item.text)
                    .font(SharedFonts.system(18, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.3), lineWidth: 1))
    }
}

/// Where one player scored in a game, per zone (2×3 or 3×3 as played), in the player's colour
struct ZoneHeatmap: View {
    let game: Game
    let player: Player
    let color: Color

    var body: some View {
        let rows = game.heatmapLayout.rows
        var most = 1
        for zone in CourtZone.allCases {
            most = max(most, game.pointsWon(by: player, in: zone))
        }
        let highest = most
        return VStack(spacing: 6) {
            Text(game.name(for: player))
                .font(SharedFonts.system(13, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(spacing: 3) {
                ForEach(0..<rows.count, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<rows[row].count, id: \.self) { column in
                            let count = game.pointsWon(by: player, in: rows[row][column])
                            ZStack {
                                Rectangle().fill(color.opacity(count == 0 ? 0.06 : 0.2 + Double(count) / Double(highest) * 0.6))
                                Text("\(count)")
                                    .font(SharedFonts.system(15, weight: .semibold, design: .rounded))
                                    .foregroundColor(count == 0 ? SharedColors.textMuted : SharedColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                        }
                    }
                }
            }
            .padding(6)
            .background(SharedColors.courtSand.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("punten gewonnen")
                .font(SharedFonts.system(11))
                .foregroundColor(SharedColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .readAsOne("Heatmap van \(game.name(for: player))")
    }
}
