import SwiftUI
import SquashAnalyzerCore

// MARK: - Eigen of gedeeld (docs/plan-teamwedstrijd-eenvoudiger-bouw.md)
//
// A team match is "gedeeld" when it has a live page (`isLive`) and "eigen"
// when it only lives on this phone. The same label, banner and share screen
// are used everywhere, so the wording and colours are the same on every screen
// and on iPhone and Android.

/// "GEDEELD" (orange) or "EIGEN" (grey): the small label next to a team match
struct TeamShareBadge: View {
    let isLive: Bool

    var body: some View {
        Text(isLive ? loc("GEDEELD") : loc("EIGEN"))
            .font(SharedFonts.system(9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundColor(isLive ? SharedColors.background : SharedColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isLive ? SharedColors.accent : SharedColors.tint(0.08))
            .clipShape(Capsule())
    }
}

/// The top of the team match screen: who sees it now, in one row, with
/// "Delen" (Gerd-Jan, 21 November 2026; it replaces the banner and the DELEN
/// block). Sea green while someone can follow along, grey when it only lives
/// on this phone.
struct TeamShareStatusRow: View {
    let match: TeamMatch
    /// What is wrong with sending (a refused key, no connection), or nil
    var problem: String? = nil
    let onShare: () -> Void

    private var title: String {
        if !match.isLive { return loc("Alleen op deze telefoon") }
        if match.isOpponentCopy { return loc("Meekijken als tegenstander") }
        return match.isTeamOnly ? loc("Team") : loc("Live")
    }

    private var detail: String {
        if !match.isLive { return loc("Je team ziet dit nog niet") }
        if match.isOpponentCopy {
            let keeping = match.ownSide == TeamSide.home ? match.away : match.home
            let slots = match.refereeSlots ?? []
            if slots.isEmpty {
                return loc("Je kijkt mee met \(keeping). Jullie fluiten geen partijen.")
            }
            return loc("Je kijkt mee met \(keeping). Jullie fluiten \(TeamLiveCard.labels(slots)): die partijen zet je op de teampagina.")
        }
        return match.isTeamOnly ? loc("Je team ziet dit in de app") : loc("Je team en kijkers met de link")
    }

    var body: some View {
        let color = match.isLive ? SharedColors.support : SharedColors.textSecondary
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle().fill(color).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(match.isLive ? SharedColors.support : SharedColors.textPrimary)
                    Text(detail)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onShare) {
                    HStack(spacing: 6) {
                        AppSymbol("square.and.arrow.up", size: 14, color: color)
                        Text("Delen", bundle: textBundle)
                            .font(SharedFonts.system(13, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.8), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            if let problem {
                Text(problem)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(match.isLive ? SharedColors.support.opacity(0.10) : SharedColors.tint(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(match.isLive ? SharedColors.support.opacity(0.45) : SharedColors.line(0.10), lineWidth: 1))
    }
}
