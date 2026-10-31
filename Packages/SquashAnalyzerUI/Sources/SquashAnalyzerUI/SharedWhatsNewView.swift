import SwiftUI
import SquashAnalyzerCore

/// "Nieuw in 3.0" (`WhatsNew`): one screen with the biggest changes, at the
/// first start of the new version, for everyone. "Rondleiding" shows the tour
/// in the same cover, "Aan de slag" skips it; `onDone` follows either way, and
/// then the badge reset sheet can come. iOS and Android alike.
public struct SharedWhatsNewView: View {
    let manual: URL
    /// "Zoek je club" on the tour's Competitie page
    let onTeamLink: (() -> Void)?
    let onDone: () -> Void

    @State private var showingTour = false

    public init(manual: URL, onTeamLink: (() -> Void)? = nil, onDone: @escaping () -> Void) {
        self.manual = manual
        self.onTeamLink = onTeamLink
        self.onDone = onDone
    }

    public var body: some View {
        if showingTour {
            SharedOnboardingView(manual: manual, onTeamLink: onTeamLink, onDone: onDone)
        } else {
            news
        }
    }

    private var news: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(WhatsNew.title)
                            .font(SharedFonts.system(28, weight: .bold, design: .rounded))
                            .foregroundColor(SharedColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(WhatsNew.intro)
                            .font(SharedFonts.system(15))
                            .foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(0..<WhatsNew.items.count, id: \.self) { index in
                            item(WhatsNew.items[index])
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                }
                VStack(spacing: 10) {
                    ActionButton(loc("AAN DE SLAG"), style: .filled, color: SharedColors.accent) { onDone() }
                    ActionButton(loc("RONDLEIDING"), icon: "chevron.right", style: .outlined, color: SharedColors.accent) {
                        showingTour = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private func item(_ page: Onboarding.Page) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AppSymbol(page.symbol, size: 22, color: SharedColors.accent, weight: .medium)
                .frame(width: 44, height: 44)
                .background(SharedColors.brandCard)
                .clipShape(Circle())
                .overlay(Circle().stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(SharedFonts.system(16, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                Text(page.text)
                    .font(SharedFonts.system(14))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
