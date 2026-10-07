import SwiftUI
import SquashAnalyzerCore

/// "Waar vallen de punten": won, lost and own errors per row and side
/// (Core's ZoneProfile), the numbers the local advice is based on. Shared by
/// iOS' CoachDashboardView and Android's SharedCoachDashboardView.
public struct ZoneProfileTable: View {
    let profile: ZoneProfile

    public init(profile: ZoneProfile) {
        self.profile = profile
    }

    private static let text = SharedColors.textPrimary
    private static let muted = SharedColors.textMuted
    private static let green = SharedColors.positive
    private static let orange = SharedColors.accent
    private static let red = SharedColors.error

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Waar vallen de punten")
                .font(SharedFonts.system(11, weight: .semibold))
                .foregroundColor(ZoneProfileTable.muted)
            // Explicit rows, not a nested ForEach (see docs/android-port.md)
            header
            line("Gewonnen", profile.won, ZoneProfileTable.green)
            line("Verloren", profile.lost, ZoneProfileTable.orange)
            line("Fouten", profile.errors, ZoneProfileTable.red)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("").frame(width: 66, alignment: .leading)
            cell("Voor", ZoneProfileTable.muted)
            cell("Midden", ZoneProfileTable.muted)
            cell("Achter", ZoneProfileTable.muted)
            Spacer().frame(width: 8)
            cell("Links", ZoneProfileTable.muted)
            cell("Rechts", ZoneProfileTable.muted)
        }
        .font(SharedFonts.system(10))
    }

    private func line(_ title: String, _ tally: AreaTally, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(SharedFonts.system(11))
                .foregroundColor(ZoneProfileTable.text)
                .frame(width: 66, alignment: .leading)
            number(tally.front, color)
            number(tally.middle, color)
            number(tally.back, color)
            Spacer().frame(width: 8)
            number(tally.left, color)
            number(tally.right, color)
        }
    }

    private func cell(_ text: String, _ color: Color) -> some View {
        Text(text)
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
    }

    private func number(_ value: Int, _ color: Color) -> some View {
        Text("\(value)")
            .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
            .foregroundColor(value > 0 ? color : ZoneProfileTable.muted)
            .frame(maxWidth: .infinity)
    }
}
