import SwiftUI
import SquashAnalyzerCore

/// "Nieuw in 4.0" (`WhatsNew`): at the first start of the new version, for
/// everyone. Since 4.0 a carousel like the tour (Gerd-Jan, 10 November 2026):
/// four pages, swipe or Volgende, Overslaan always there. Page 2 opens Mijn
/// account over the carousel, page 3 shares the app with the team; the last
/// page offers the tour. `onDone` follows either way, and then the badge reset
/// sheet can come. iOS and Android alike.
public struct SharedWhatsNewView: View {
    let manual: URL
    /// "Zoek je club" on the tour's Competitie page
    let onTeamLink: (() -> Void)?
    /// Sign in with Apple on iOS; empty shows only e-mail
    let accountProviders: [AccountProviderSignIn]
    let onDone: () -> Void

    @State private var showingTour = false
    @State private var showingAccount = false
    @State private var page = 0

    public init(manual: URL, onTeamLink: (() -> Void)? = nil, accountProviders: [AccountProviderSignIn] = [],
                onDone: @escaping () -> Void) {
        self.manual = manual
        self.onTeamLink = onTeamLink
        self.accountProviders = accountProviders
        self.onDone = onDone
    }

    private var isLast: Bool { page == WhatsNew.items.count - 1 }

    public var body: some View {
        if showingTour {
            SharedOnboardingView(manual: manual, onTeamLink: onTeamLink, onDone: onDone)
        } else {
            carousel
        }
    }

    private var carousel: some View {
        let current = WhatsNew.items[page]
        return ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(WhatsNew.title.uppercased())
                        .font(SharedFonts.system(12, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(SharedColors.accent)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(loc("Overslaan")) { onDone() }
                        .font(SharedFonts.system(15, weight: .semibold))
                        .foregroundColor(SharedColors.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer(minLength: 16)

                VStack(spacing: 22) {
                    badge(current.symbol, size: 112)
                    Text(current.title)
                        .font(SharedFonts.system(26, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(current.text)
                        .font(SharedFonts.system(16))
                        .foregroundColor(SharedColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    pageAction
                    if isLast {
                        Button(loc("Bekijk de rondleiding")) { showingTour = true }
                            .font(SharedFonts.system(15, weight: .semibold))
                            .foregroundColor(SharedColors.accent)
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 16)

                dots
                    .padding(.bottom, 20)

                HStack(spacing: 12) {
                    if page > 0 {
                        ActionButton(loc("VORIGE"), style: .outlined, color: SharedColors.textSecondary) {
                            page -= 1
                        }
                    }
                    ActionButton(isLast ? loc("AAN DE SLAG") : loc("VOLGENDE"), style: .filled, color: SharedColors.accent) {
                        if isLast { onDone() } else { page += 1 }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40.0 && !isLast { page += 1 }
                    if value.translation.width > 40.0 && page > 0 { page -= 1 }
                }
        )
        .sheet(isPresented: $showingAccount) {
            WhatsNewAccountSheet(providers: accountProviders) { showingAccount = false }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    /// "Account maken" or "Deel met je team" under the page's text
    @ViewBuilder
    private var pageAction: some View {
        let action = WhatsNew.action(onPage: page)
        if action == WhatsNew.Action.account {
            if PlayerAccount.shared.profile != nil {
                Text("Je hebt al een account. Mooi!", bundle: textBundle)
                    .font(SharedFonts.system(15, weight: .semibold))
                    .foregroundColor(SharedColors.support)
            } else if Features.shared.playerAccount && PlayerAccount.shared.isConfigured {
                ActionButton(loc("ACCOUNT MAKEN"), icon: "person.crop.circle", style: .outlined, color: SharedColors.accent) {
                    showingAccount = true
                }
            }
        } else if action == WhatsNew.Action.shareWithTeam {
            ShareLink(item: AppLinks.teamShareText, subject: Text("Squash Analyzer")) {
                ShareButtonLabel(title: loc("DEEL MET JE TEAM"))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("Deel de app met je team"))
        }
    }

    /// A page's symbol in the round brand badge, as in the tour
    private func badge(_ symbol: String, size: CGFloat) -> some View {
        AppSymbol(symbol, size: size * 0.48, color: SharedColors.accent, weight: .medium)
            .frame(width: size, height: size)
            .background(SharedColors.brandCard)
            .clipShape(Circle())
            .overlay(Circle().stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<WhatsNew.items.count, id: \.self) { index in
                Circle()
                    .fill(index == page ? SharedColors.accent : SharedColors.line(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .readAsOne(loc("Stap \(page + 1) van \(WhatsNew.items.count)"))
    }
}

/// The look of an outlined `ActionButton`, for a ShareLink (which brings its own button)
struct ShareButtonLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            AppSymbol("square.and.arrow.up", size: 13, color: SharedColors.accent, weight: .semibold)
            Text(title)
                .font(ActionButton.font)
                .tracking(1)
                .foregroundColor(SharedColors.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(SharedColors.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
    }
}

/// Mijn account over the carousel or the home screen: sign in or make the
/// account, then Klaar brings you back
struct WhatsNewAccountSheet: View {
    let providers: [AccountProviderSignIn]
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Mijn account", bundle: textBundle)
                        .font(SharedFonts.system(18, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    Button(loc("Klaar")) { onClose() }
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                SharedAccountSection(providers: providers)
            }
            .padding(20)
        }
        .background(SharedColors.background.ignoresSafeArea())
        .appAppearance()
    }
}
