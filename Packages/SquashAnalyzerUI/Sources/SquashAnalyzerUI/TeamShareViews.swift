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
        Text(isLive ? "GEDEELD" : "EIGEN")
            .font(SharedFonts.system(9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundColor(isLive ? SharedColors.background : SharedColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isLive ? SharedColors.accent : SharedColors.tint(0.08))
            .clipShape(Capsule())
    }
}

/// The top of the team match screen: shared or own, and what that means
struct TeamShareBanner: View {
    let match: TeamMatch

    private var title: String {
        if !match.isLive { return "Alleen op deze telefoon" }
        return match.isLiveOwner ? "Gedeeld met je team · jij bent de eigenaar" : "Gedeeld met je team"
    }

    private var detail: String {
        if !match.isLive {
            return "Teamgenoten zien deze teamwedstrijd niet. Tik op Deel met mijn team om samen te werken."
        }
        if match.needsOwnPartij {
            return "Tik op jouw partij en zet er een wedstrijd op. Wat jij invult, zien je teamgenoten ook."
        }
        let others = match.teammatePartijen
        if others == 0 {
            return "Partijen die teamgenoten invullen komen er vanzelf bij."
        }
        return "\(others) van 4 partijen komen van teamgenoten. Wat jij invult, zien zij ook."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TeamShareBadge(isLive: match.isLive)
                Text(title)
                    .font(SharedFonts.system(12, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            Text(detail)
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(match.isLive ? SharedColors.accent.opacity(0.12) : SharedColors.tint(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// "Deel met team en supporters": two separate groups, because the invitation
/// holds the key that writes a partij and must not go to supporters
struct TeamShareSheet: View {
    let match: TeamMatch
    let baseURL: String
    let shareText: ((String) -> Void)?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Kies voor wie het bericht is. Supporters kunnen alleen kijken; teamleden kunnen ook hun eigen partij invullen.")
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        group("VOOR SUPPORTERS") {
                            Text("Een link naar de livepagina met de stand van de hele avond. Kijken kan in de browser, zonder app. Er is niets in te vullen.")
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let shareText {
                                ActionButton("Deel kijkerslink", icon: "square.and.arrow.up", style: .filled) {
                                    shareText(TeamLiveTexts.viewers(match, baseURL: baseURL))
                                }
                                .padding(.top, 6)
                            }
                        }
                        group("VOOR TEAMLEDEN") {
                            Text("Een uitnodiging om mee te doen in dezelfde teamwedstrijd en je eigen partij erop te zetten. Alleen voor mensen uit je team: wie de uitnodiging heeft, kan partijen invullen.")
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let shareText {
                                ActionButton("Nodig teamleden uit", icon: "square.and.arrow.up", style: .filled) {
                                    shareText(TeamLiveTexts.invite(match))
                                }
                                .padding(.top, 6)
                            }
                            if let id = match.liveId, let key = match.liveKey {
                                // Also readable when nothing can be shared: the code teammates paste at Deelnemen
                                Text("Code om mee te doen: \(TeamInvite(id: id, key: key).code)")
                                    .font(SharedFonts.system(11))
                                    .foregroundColor(SharedColors.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 4)
                            }
                        }
                        Text("2 uur na de laatste update wordt alles van de livepagina gewist. Alleen teamnamen, voornamen en de stand gaan mee.")
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                }
            }
            .pageTitle("Deel met team")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(title: "Sluiten", action: onClose)
                }
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(SharedColors.tint(0.04)))
        }
    }
}
